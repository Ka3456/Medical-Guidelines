import os, uuid
from typing import List, Dict, Any
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction
import fitz  # PyMuPDF
import tiktoken
from openai import OpenAI

# ---- 設定 ----
load_dotenv()
PERSIST_DIR = "data/chroma_db"
COLLECTION  = "guidelines"
EMBED_MODEL = os.getenv("EMBED_MODEL", "text-embedding-3-large")
CHAT_MODEL = os.getenv("CHAT_MODEL", "gpt-4o")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# OpenAI API料金設定（2024年12月時点の価格）
PRICING = {
    "gpt-4o": {
        "input": 0.0025,   # $0.0025 per 1K tokens
        "output": 0.01     # $0.01 per 1K tokens
    },
    "gpt-4o-mini": {
        "input": 0.00015,  # $0.00015 per 1K tokens
        "output": 0.0006   # $0.0006 per 1K tokens
    },
    "text-embedding-3-large": 0.00013,  # $0.00013 per 1K tokens
    "text-embedding-3-small": 0.00002,  # $0.00002 per 1K tokens
}

# エンコーディング（tiktoken）
try:
    ENCODING = tiktoken.get_encoding("o200k_base")
except Exception:
    ENCODING = tiktoken.get_encoding("cl100k_base")

MAX_TOKENS_PER_CHUNK = 700
MAX_TOKENS_PER_REQUEST = 240_000  # OpenAIの埋め込みAPIは合計30万上限

# ---- 初期化（Chroma + Embedding関数 + OpenAI Client）----
client = chromadb.PersistentClient(path=PERSIST_DIR)
emb_fn = OpenAIEmbeddingFunction(model_name=EMBED_MODEL, api_key=OPENAI_API_KEY)
collection = client.get_or_create_collection(name=COLLECTION, embedding_function=emb_fn)
openai_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

# ---- FastAPI ----
app = FastAPI(title="RAG Minimal API", version="0.1.0")

# 開発用CORS（必要に応じてドメイン絞ってOK）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

# ---- 共通ユーティリティ ----
def calculate_cost(model: str, input_tokens: int, output_tokens: int = 0) -> Dict[str, Any]:
    """OpenAI APIの料金を計算"""
    if model in PRICING and isinstance(PRICING[model], dict):
        # チャットモデルの場合
        input_cost = (input_tokens / 1000) * PRICING[model]["input"]
        output_cost = (output_tokens / 1000) * PRICING[model]["output"]
        total_cost = input_cost + output_cost
        return {
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "input_cost_usd": round(input_cost, 6),
            "output_cost_usd": round(output_cost, 6),
            "total_cost_usd": round(total_cost, 6),
            "total_cost_jpy": round(total_cost * 150, 2)  # 1USD = 150JPY想定
        }
    elif model in PRICING:
        # 埋め込みモデルの場合
        total_cost = (input_tokens / 1000) * PRICING[model]
        return {
            "input_tokens": input_tokens,
            "output_tokens": 0,
            "input_cost_usd": round(total_cost, 6),
            "output_cost_usd": 0,
            "total_cost_usd": round(total_cost, 6),
            "total_cost_jpy": round(total_cost * 150, 2)
        }
    else:
        return {
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "input_cost_usd": 0,
            "output_cost_usd": 0,
            "total_cost_usd": 0,
            "total_cost_jpy": 0
        }

def load_pdf_text_bytes(pdf_bytes: bytes) -> List[Dict[str, Any]]:
    """PyMuPDFでページごとのテキスト抽出"""
    out: List[Dict[str, Any]] = []
    with fitz.open(stream=pdf_bytes, filetype="pdf") as doc:
        for i, page in enumerate(doc, start=1):
            txt = (page.get_text("text") or "").strip()
            if txt:
                out.append({"page": i, "text": txt})
    return out

def split_by_tokens(text: str, max_tokens: int = MAX_TOKENS_PER_CHUNK) -> List[str]:
    ids = ENCODING.encode(text)
    chunks: List[str] = []
    for start in range(0, len(ids), max_tokens):
        piece = ids[start:start + max_tokens]
        chunks.append(ENCODING.decode(piece))
    return chunks

def add_in_batches(ids: List[str], docs: List[str], metas: List[Dict[str, Any]]) -> None:
    assert len(ids) == len(docs) == len(metas)
    tok_counts = [len(ENCODING.encode(d)) for d in docs]

    batch_ids, batch_docs, batch_metas = [], [], []
    running = 0

    for id_, doc, meta, tok in zip(ids, docs, metas, tok_counts):
        # 保険：1チャンクが異常に大きい場合はさらに分割
        if tok > MAX_TOKENS_PER_REQUEST:
            for j, sub in enumerate(split_by_tokens(doc, max_tokens=MAX_TOKENS_PER_CHUNK)):
                sub_id = f"{id_}-sub{j}"
                sub_meta = dict(meta); sub_meta["sub"] = j
                sub_tok = len(ENCODING.encode(sub))
                if running + sub_tok > MAX_TOKENS_PER_REQUEST and batch_ids:
                    collection.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)
                    batch_ids, batch_docs, batch_metas, running = [], [], [], 0
                batch_ids.append(sub_id); batch_docs.append(sub); batch_metas.append(sub_meta)
                running += sub_tok
            continue

        if running + tok > MAX_TOKENS_PER_REQUEST and batch_ids:
            collection.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)
            batch_ids, batch_docs, batch_metas, running = [], [], [], 0

        batch_ids.append(id_); batch_docs.append(doc); batch_metas.append(meta)
        running += tok

    if batch_ids:
        collection.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)

# ---- リクエスト/レスポンスモデル ----
class AskRequest(BaseModel):
    question: str
    k: int = 5

class AskResponseItem(BaseModel):
    text: str
    page: int
    chunk: int
    source: str
    doc_id: str
    distance: float | None = None

class AskResponse(BaseModel):
    hits: List[AskResponseItem]

class ChatRequest(BaseModel):
    message: str
    k: int = 5
    include_context: bool = True

class CostInfo(BaseModel):
    input_tokens: int
    output_tokens: int
    input_cost_usd: float
    output_cost_usd: float
    total_cost_usd: float
    total_cost_jpy: float

class ChatResponse(BaseModel):
    response: str
    context_used: List[AskResponseItem] = []
    model_used: str = ""
    cost_info: CostInfo | None = None
    
    class Config:
        # Noneの場合は除外するのではなく、空のオブジェクトとして返す
        exclude_none = False
        
    def dict(self, **kwargs):
        """カスタムdictメソッドでcost_infoがNoneの場合に空のオブジェクトを返す"""
        data = super().dict(**kwargs)
        if data.get('cost_info') is None:
            data['cost_info'] = {}
        return data

# ---- エンドポイント ----
@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/ingest")
async def ingest(file: UploadFile = File(...)):
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=400, detail="OPENAI_API_KEY が未設定です（.env を確認）")

    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="PDFファイルをアップロードしてください")

    data = await file.read()
    pages = load_pdf_text_bytes(data)
    if not pages:
        raise HTTPException(status_code=400, detail="PDFからテキスト抽出できませんでした")

    doc_id = str(uuid.uuid4())
    ids: List[str] = []; docs: List[str] = []; metas: List[Dict[str, Any]] = []
    for p in pages:
        parts = split_by_tokens(p["text"], max_tokens=MAX_TOKENS_PER_CHUNK)
        for ci, part in enumerate(parts):
            ids.append(f"{doc_id}-{p['page']}-{ci}")
            docs.append(part)
            metas.append({
                "doc_id": doc_id,
                "page": p["page"],
                "chunk": ci,
                "source": file.filename
            })

    add_in_batches(ids, docs, metas)
    return {"doc_id": doc_id, "chunks": len(docs), "pages": len(pages)}

@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest):
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="question を入力してください")
    res = collection.query(query_texts=[req.question], n_results=req.k, include=["documents","metadatas","distances"])
    docs  = (res.get("documents") or [[]])[0]
    metas = (res.get("metadatas") or [[]])[0]
    dists = (res.get("distances") or [[]])[0]
    hits: List[AskResponseItem] = []
    for d, m, dist in zip(docs, metas, dists):
        hits.append(AskResponseItem(
            text=d,
            page=int(m.get("page", 0)),
            chunk=int(m.get("chunk", 0)),
            source=str(m.get("source", "")),
            doc_id=str(m.get("doc_id", "")),
            distance=float(dist) if dist is not None else None
        ))
    return AskResponse(hits=hits)

@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    if not req.message.strip():
        raise HTTPException(status_code=400, detail="message を入力してください")
    
    if not openai_client:
        raise HTTPException(status_code=400, detail="OpenAI API が設定されていません")
    
    # RAGで関連文書を検索
    context_hits = []
    if req.include_context:
        res = collection.query(
            query_texts=[req.message], 
            n_results=req.k, 
            include=["documents","metadatas","distances"]
        )
        docs = (res.get("documents") or [[]])[0]
        metas = (res.get("metadatas") or [[]])[0]
        dists = (res.get("distances") or [[]])[0]
        
        for d, m, dist in zip(docs, metas, dists):
            context_hits.append(AskResponseItem(
                text=d,
                page=int(m.get("page", 0)),
                chunk=int(m.get("chunk", 0)),
                source=str(m.get("source", "")),
                doc_id=str(m.get("doc_id", "")),
                distance=float(dist) if dist is not None else None
            ))
    
    # システムプロンプト（医療専門）
    system_prompt = """あなたは医療ガイドライン専門のAIアシスタントです。

重要な注意事項:
- このアプリは医師専用のため医師向けに答えてください
- このアプリは情報提供のみを目的としており、医師の診断や治療の代替ではありません
- 緊急時は直ちに医療機関にご連絡ください
- 重要な医療決定については必ず医師にご相談ください
- 症状が悪化した場合は速やかに受診してください

回答のガイドライン:
1. 提供された医療ガイドラインの情報をそのままコピーして自然な日本語にしてください。
2. 回答は医師向けに答えてください
3. 緊急を要する症状については、必ず医療機関への受診を推奨してください
4. 参照するガイドラインのページ文言を教えてくださいs
5. 回答は簡潔で理解しやすいものにしてください"""

    # コンテキストを構築
    context_text = ""
    if context_hits:
        context_text = "\n\n=== 関連する医療ガイドライン情報 ===\n"
        for i, hit in enumerate(context_hits, 1):
            context_text += f"\n[{i}] 出典: {hit.source} (ページ {hit.page})\n{hit.text}\n"
        context_text += "\n=== 上記の情報を参考に回答してください ===\n"
    
    # GPT-4oに送信
    try:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"{req.message}{context_text}"}
        ]
        
        # 入力トークン数を計算
        input_text = system_prompt + f"{req.message}{context_text}"
        input_tokens = len(ENCODING.encode(input_text))
        
        response = openai_client.chat.completions.create(
            model=CHAT_MODEL,
            messages=messages,
            max_tokens=1000,
            temperature=0.3
        )
        
        ai_response = response.choices[0].message.content
        
        # トークン使用量を取得（デバッグ情報付き）
        if response.usage:
            output_tokens = response.usage.completion_tokens
            print(f"DEBUG: Input tokens: {input_tokens}, Output tokens: {output_tokens}")
        else:
            output_tokens = 0
            print(f"DEBUG: No usage info available, using 0 for output tokens")
        
        # 料金計算
        cost_data = calculate_cost(CHAT_MODEL, input_tokens, output_tokens)
        print(f"DEBUG: Cost data: {cost_data}")
        cost_info = CostInfo(**cost_data)
        print(f"DEBUG: CostInfo object: {cost_info}")
        
        response_data = ChatResponse(
            response=ai_response,
            context_used=context_hits,
            model_used=CHAT_MODEL,
            cost_info=cost_info
        )
        print(f"DEBUG: Final response cost_info: {response_data.cost_info}")
        print(f"DEBUG: Final response dict: {response_data.dict()}")
        
        # デバッグ: レスポンスを直接返す
        return {
            "response": ai_response,
            "context_used": [hit.dict() for hit in context_hits],
            "model_used": CHAT_MODEL,
            "cost_info": cost_data
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OpenAI API エラー: {str(e)}")

# ---- サーバー起動 ----
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

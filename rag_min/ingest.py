# ingest.py
import os, uuid, math
from typing import List, Tuple, Dict, Any
from dotenv import load_dotenv
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

# CJKに強い抽出
import fitz  # PyMuPDF

# トークン分割
import tiktoken

load_dotenv()

PERSIST_DIR = "data/chroma_db"
COLLECTION = "guidelines"

# ==== 抽出: PyMuPDF ====
def load_pdf_text(path: str) -> List[Tuple[int, str]]:
    out: List[Tuple[int, str]] = []
    with fitz.open(path) as doc:
        for i, page in enumerate(doc, start=1):
            txt = page.get_text("text") or ""
            txt = txt.strip()
            if txt:
                out.append((i, txt))
    return out

# ==== トークン分割 ====
# text-embedding-3-* は "o200k_base" が適切（無ければ cl100k_base でも可）
try:
    ENCODING = tiktoken.get_encoding("o200k_base")
except Exception:
    ENCODING = tiktoken.get_encoding("cl100k_base")

def split_by_tokens(text: str, max_tokens: int = 700) -> List[str]:
    ids = ENCODING.encode(text)
    chunks: List[str] = []
    for start in range(0, len(ids), max_tokens):
        piece = ids[start:start + max_tokens]
        chunks.append(ENCODING.decode(piece))
    return chunks

# ==== バッチ投入（合計トークン≦上限に収める） ====
# OpenAIの埋め込みAPIは 300k / request 上限。余裕をみて 240k でカット。
MAX_TOKENS_PER_REQUEST = 240_000

def add_in_batches(col, ids: List[str], docs: List[str], metas: List[Dict[str, Any]]) -> None:
    assert len(ids) == len(docs) == len(metas)
    # 各ドキュメントのトークン数を概算
    tok_counts = [len(ENCODING.encode(d)) for d in docs]

    batch_ids, batch_docs, batch_metas = [], [], []
    running = 0

    for i, (id_, doc, meta, tok) in enumerate(zip(ids, docs, metas, tok_counts)):
        # 単体で大きすぎる場合はさらに分割（保険）
        if tok > MAX_TOKENS_PER_REQUEST:
            subparts = split_by_tokens(doc, max_tokens=700)
            for j, sub in enumerate(subparts):
                sub_id = f"{id_}-sub{j}"
                sub_meta = dict(meta)
                sub_meta["sub"] = j
                sub_tok = len(ENCODING.encode(sub))

                if running + sub_tok > MAX_TOKENS_PER_REQUEST and batch_ids:
                    col.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)
                    batch_ids, batch_docs, batch_metas, running = [], [], [], 0

                batch_ids.append(sub_id)
                batch_docs.append(sub)
                batch_metas.append(sub_meta)
                running += sub_tok
            continue

        # 通常ケース
        if running + tok > MAX_TOKENS_PER_REQUEST and batch_ids:
            col.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)
            batch_ids, batch_docs, batch_metas, running = [], [], [], 0

        batch_ids.append(id_)
        batch_docs.append(doc)
        batch_metas.append(meta)
        running += tok

    if batch_ids:
        col.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)

def main(pdf_path: str) -> None:
    client = chromadb.PersistentClient(path=PERSIST_DIR)
    emb_fn = OpenAIEmbeddingFunction(
        model_name="text-embedding-3-large",
        api_key=os.getenv("OPENAI_API_KEY")  # CHROMA_OPENAI_API_KEY でもOK
    )
    col = client.get_or_create_collection(name=COLLECTION, embedding_function=emb_fn)

    doc_id = str(uuid.uuid4())
    pages = load_pdf_text(pdf_path)

    ids: List[str] = []
    docs: List[str] = []
    metas: List[Dict[str, Any]] = []

    for pno, text in pages:
        parts = split_by_tokens(text, max_tokens=700)  # ← 700トークンで堅牢に分割
        for ci, part in enumerate(parts):
            ids.append(f"{doc_id}-{pno}-{ci}")
            docs.append(part)
            metas.append({
                "doc_id": doc_id,
                "page": pno,
                "chunk": ci,
                "source": os.path.basename(pdf_path)
            })

    if not docs:
        print("テキスト抽出できませんでした。")
        return

    add_in_batches(col, ids, docs, metas)

    print(f"OK: {pdf_path} を取り込みました。")
    print(f"- doc_id: {doc_id}")
    print(f"- 保存先（ベクトル）: {PERSIST_DIR}")

if __name__ == "__main__":
    import sys
    assert len(sys.argv) == 2, "使い方: python ingest.py pdf/HF.pdf"
    main(sys.argv[1])

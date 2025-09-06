# ingest.py
import os, uuid
from typing import List, Tuple, Dict, Any
from dotenv import load_dotenv
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

import fitz  # PyMuPDF
import tiktoken

# ==============================
# 環境設定
# ==============================
load_dotenv("../../.env")  # 親ディレクトリの.envを読み込み

PERSIST_DIR = "data/chroma_db"
COLLECTION = "guidelines"

# ==============================
# PDFテキスト抽出
# ==============================
def load_pdf_text(path: str) -> List[Tuple[int, str]]:
    """PDFを読み込み、(ページ番号, テキスト) のリストを返す"""
    out: List[Tuple[int, str]] = []
    with fitz.open(path) as doc:
        for i, page in enumerate(doc, start=1):
            txt = page.get_text("text") or ""
            txt = txt.strip()
            if txt:
                out.append((i, txt))
    return out

# ==============================
# トークンエンコーディング
# ==============================
try:
    ENCODING = tiktoken.get_encoding("o200k_base")
except Exception:
    ENCODING = tiktoken.get_encoding("cl100k_base")

# ==============================
# 段落ごとに分割
# ==============================
def split_into_paragraphs(text: str) -> List[str]:
    """
    空行(\n\n)で段落を判定。
    段落の改行はスペースに変換して1行化。
    """
    paras = []
    for para in text.split("\n\n"):
        para = para.strip()
        if para:
            para = " ".join(para.split())  # 改行・余分な空白を潰す
            paras.append(para)
    return paras

# ==============================
# 段落をまとめてトークン上限以内にチャンク化
# ==============================
def chunk_by_paragraphs(text: str, max_tokens: int = 500) -> List[str]:
    paragraphs = split_into_paragraphs(text)
    chunks, current, tokens = [], [], 0
    for para in paragraphs:
        tid = ENCODING.encode(para)
        if tokens + len(tid) > max_tokens and current:
            chunks.append(" ".join(current))
            current, tokens = [], 0
        current.append(para)
        tokens += len(tid)
    if current:
        chunks.append(" ".join(current))
    return chunks

# ==============================
# ChromaDB バッチ投入
# ==============================
MAX_TOKENS_PER_REQUEST = 240_000

def add_in_batches(col, ids: List[str], docs: List[str], metas: List[Dict[str, Any]]) -> None:
    assert len(ids) == len(docs) == len(metas)

    batch_ids, batch_docs, batch_metas = [], [], []
    running = 0

    for id_, doc, meta in zip(ids, docs, metas):
        tok = len(ENCODING.encode(doc))

        if running + tok > MAX_TOKENS_PER_REQUEST and batch_ids:
            col.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)
            batch_ids, batch_docs, batch_metas, running = [], [], [], 0

        batch_ids.append(id_)
        batch_docs.append(doc)
        batch_metas.append(meta)
        running += tok

    if batch_ids:
        col.add(ids=batch_ids, documents=batch_docs, metadatas=batch_metas)

# ==============================
# メイン処理
# ==============================
def main(pdf_path: str) -> None:
    client = chromadb.PersistentClient(path=PERSIST_DIR)
    emb_fn = OpenAIEmbeddingFunction(
        model_name="text-embedding-3-large",
        api_key=os.getenv("OPENAI_API_KEY")
    )
    col = client.get_or_create_collection(name=COLLECTION, embedding_function=emb_fn)

    doc_id = str(uuid.uuid4())
    pages = load_pdf_text(pdf_path)

    ids: List[str] = []
    docs: List[str] = []
    metas: List[Dict[str, Any]] = []

    for pno, text in pages:
        parts = chunk_by_paragraphs(text, max_tokens=500)  # ← 段落ベースでチャンク化
        for ci, part in enumerate(parts):
            ids.append(f"{doc_id}-{pno}-{ci}")
            docs.append(part)
            metas.append({
                "doc_id": doc_id,
                "page": pno,
                "chunk": ci,
                "source": os.path.basename(pdf_path)
                # TODO: section_path を chapter.json とマッピングするなら後で追加
            })

    if not docs:
        print("テキスト抽出できませんでした。")
        return

    add_in_batches(col, ids, docs, metas)

    print(f"OK: {pdf_path} を取り込みました。")
    print(f"- doc_id: {doc_id}")
    print(f"- 保存先: {PERSIST_DIR}")
    print(f"- チャンク数: {len(docs)}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) == 2:
        pdf_path = sys.argv[1]
    else:
        pdf_path = "../../pdf/HF.pdf"
    
    print(f"PDFファイル: {pdf_path}")
    main(pdf_path)

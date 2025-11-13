
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PDF → 章TOC → 章内チャンク → Postgres(pgvector)向けSQL生成
- 既定: 埋め込みOFF（ゼロベクトル）。 --embed-local で sentence-transformers を使用可（任意）。
- TOCは (1) 自動抽出（「第X章」「X.Y 見出し」等を正規表現） or (2) 事前JSON（ラッパー付き/無しどちらもOK）
- 出力: DDL＋INSERT を含む .sql 単一ファイル

使い方例:
  python build_guideline_sql.py \
    --pdf ./docs/JCS2013.pdf \
    --toc-json ./toc/JCS2013_chapter.json \
    --doc-id JCS2013 --version 2013 \
    --out-sql ./out/JCS2013.sql

複数PDF（doc_id はファイル名から自動推定 / --doc-id-prefix 付加可）:
  python build_guideline_sql.py \
    --pdf "./docs/*.pdf" \
    --doc-id-prefix JCS \
    --version 2013 \
    --out-sql ./out/all.sql

TOC JSON 形式：
  A) ラッパー付き
  {
    "pdf_filename": "JCS2013.pdf",
    "created_at": "2025-11-03T10:00:00Z",
    "toc": [
      {"section_path":"第1章 総論","start_page":5,"end_page":18},
      {"section_path":"第2章 定義","start_page":19,"end_page":26}
    ]
  }
  B) 配列のみ（トップが[]）
  [
    {"section_path":"第1章 総論","start_page":5,"end_page":18},
    {"section_path":"第2章 定義","start_page":19,"end_page":26}
  ]

SQLスキーマ（作成済みチェック付き）:
  - toc(doc_id, section_path, start_page, end_page, version)
  - chunks(doc_id, section_path, page, text, tokens, embedding vector(1536), version, created_at)
  - インデックス: ivfflat(embedding), GIN(trigram), (doc_id, section_path, page)
"""

import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime
from typing import Any, Dict, List, Tuple

# -------- PDF 読み込み: PyMuPDF (fitz) --------
try:
    import fitz  # PyMuPDF
except Exception:
    fitz = None

# -------- 埋め込み設定 --------
EMBED_DIM = 1536  # pgvector想定

def get_embedder(use_local: bool):
    """返り値: callable(List[str]) -> List[List[float]]"""
    if not use_local:
        def _zero(texts: List[str]) -> List[List[float]]:
            return [[0.0] * EMBED_DIM for _ in texts]
        return _zero
    try:
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
        dim = model.get_sentence_embedding_dimension()
        def _embed(texts: List[str]) -> List[List[float]]:
            vecs = model.encode(texts, normalize_embeddings=True).tolist()
            out = []
            for v in vecs:
                if len(v) >= EMBED_DIM:
                    out.append(v[:EMBED_DIM])
                else:
                    out.append(v + [0.0] * (EMBED_DIM - len(v)))
            return out
        return _embed
    except Exception:
        def _zero(texts: List[str]) -> List[List[float]]:
            return [[0.0] * EMBED_DIM for _ in texts]
        return _zero

# -------- ユーティリティ --------

def sql_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "''")

def approx_token_count(text: str) -> int:
    # 超概算: 4 chars ≒ 1 token
    return max(1, len(text) // 4)

def make_doc_id_from_filename(path: str, prefix: str = None) -> str:
    base = os.path.basename(path)
    stem = os.path.splitext(base)[0]
    stem = re.sub(r"\s+", "_", stem)
    return f"{prefix}_{stem}" if prefix else stem

# -------- PDFテキスト抽出 --------

def extract_pages_text(pdf_path: str) -> List[str]:
    if fitz is None:
        raise RuntimeError("PyMuPDF(fitz) が見つかりません。`pip install pymupdf` を実行してください。")
    doc = fitz.open(pdf_path)
    pages = []
    for i in range(len(doc)):
        text = doc.load_page(i).get_text("text")
        pages.append(text or "")
    doc.close()
    return pages

# -------- TOC抽出 --------
SECTION_PATTERNS = [
    r"(第\s*\d+\s*章[ \t　]+[^\n]+)",       # 第1章 ○○
    r"(^\d{1,2}\.\s*[^\n]{3,})",            # 1. 見出し
    r"(^\d{1,2}\.\d{1,2}\.\s*[^\n]{3,})", # 1.2. 見出し
]
SECTION_RE = re.compile("|".join(SECTION_PATTERNS), re.MULTILINE)

def auto_toc(pages: List[str]) -> List[Dict[str, Any]]:
    hits: List[Tuple[int, str]] = []
    for pno, text in enumerate(pages, start=1):
        for m in SECTION_RE.finditer(text):
            label = m.group(0).strip()
            if 3 <= len(label) <= 120 and not re.fullmatch(r"[\W_]+", label):
                hits.append((pno, label))
    hits.sort(key=lambda x: (x[0], x[1]))
    toc = []
    for idx, (start_p, label) in enumerate(hits):
        end_p = (hits[idx + 1][0] - 1) if idx + 1 < len(hits) else len(pages)
        section_path = re.sub(r"\s+", " ", label)
        if end_p >= start_p:
            toc.append({"section_path": section_path, "start_page": start_p, "end_page": end_p})
    if not toc:
        toc = [{"section_path": "本文", "start_page": 1, "end_page": len(pages)}]
    return toc

# ラッパー/配列 どちらも受けるローダ

def load_toc_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        loaded = json.load(f)
    if isinstance(loaded, dict):
        toc = loaded.get("toc", [])
        pdf_filename = loaded.get("pdf_filename")
    elif isinstance(loaded, list):
        toc = loaded
        pdf_filename = None
    else:
        raise ValueError("Unsupported JSON structure for TOC")

    norm = []
    for i, row in enumerate(toc):
        if not isinstance(row, dict):
            continue
        sp = int(row.get("start_page"))
        ep = int(row.get("end_page"))
        if sp > ep:
            sp, ep = ep, sp
        norm.append({
            "section_path": str(row.get("section_path", f"Section {i+1}")),
            "start_page": sp,
            "end_page": ep,
            **({"level": int(row["level"]) } if "level" in row and row["level"] is not None else {})
        })
    return {"toc": norm, "pdf_filename": pdf_filename}

# -------- チャンク化 --------

def split_into_chunks(text: str, target_chars: int = 2400, max_chars: int = 3600) -> List[str]:
    t = re.sub(r"\r\n|\r", "\n", text).strip()
    sentences = re.split(r"(?<=[。．．!！\?？])\s+|\n{2,}", t)
    chunks, buf = [], ""
    for s in sentences:
        s = s.strip()
        if not s:
            continue
        if len(buf) + len(s) + 1 <= target_chars:
            buf = (buf + "\n" + s) if buf else s
        elif len(buf) == 0 and len(s) > max_chars:
            for i in range(0, len(s), max_chars):
                chunks.append(s[i:i + max_chars])
        else:
            if buf:
                chunks.append(buf)
            buf = s
    if buf:
        chunks.append(buf)
    return chunks

def build_section_text(pages: List[str], start_page: int, end_page: int) -> Tuple[str, List[Tuple[int, str]]]:
    selected = pages[start_page - 1:end_page]
    joined = "\n".join(selected).strip()
    return joined, list(zip(range(start_page, end_page + 1), selected))

# -------- SQL DDL --------
DDL = f"""-- Generated at {datetime.utcnow().isoformat()}Z
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS toc (
  id SERIAL PRIMARY KEY,
  doc_id TEXT,
  section_path TEXT,
  start_page INT,
  end_page   INT,
  version TEXT
);

CREATE TABLE IF NOT EXISTS chunks (
  id SERIAL PRIMARY KEY,
  doc_id TEXT,
  section_path TEXT,
  page INT,
  text TEXT,
  tokens INT DEFAULT 0,
  embedding VECTOR({EMBED_DIM}),
  version TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'idx_chunks_embedding'
  ) THEN
    EXECUTE 'CREATE INDEX idx_chunks_embedding ON chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'idx_chunks_doc_section_page'
  ) THEN
    EXECUTE 'CREATE INDEX idx_chunks_doc_section_page ON chunks (doc_id, section_path, page)';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'chunks_text_trgm_idx'
  ) THEN
    EXECUTE 'CREATE INDEX chunks_text_trgm_idx ON chunks USING gin (text gin_trgm_ops)';
  END IF;
END $$;
"""

# -------- メイン処理 --------

def process_single_pdf(pdf_path: str, args, out_lines: List[str]):
    # 初期 doc_id/version 決定
    doc_id = args.doc_id or make_doc_id_from_filename(pdf_path, args.doc_id_prefix)
    version = args.version or "v0"

    pages = extract_pages_text(pdf_path)

    # TOC 決定
    toc = None
    inferred_from_json = None

    # --toc-json がファイルならそれを使う。ディレクトリなら stem一致を探索
    if args.toc_json:
        if os.path.isdir(args.toc_json):
            stem = os.path.splitext(os.path.basename(pdf_path))[0]
            candidates = [
                os.path.join(args.toc_json, stem + suffix)
                for suffix in (".json", "_toc.json", "_chapter.json")
            ]
            for cand in candidates:
                if os.path.exists(cand):
                    payload = load_toc_json(cand)
                    toc = payload["toc"]
                    inferred_from_json = payload.get("pdf_filename")
                    break
        elif os.path.isfile(args.toc_json):
            payload = load_toc_json(args.toc_json)
            toc = payload["toc"]
            inferred_from_json = payload.get("pdf_filename")

    if toc is None:
        toc = auto_toc(pages)

    # doc_id が未指定で、JSONに pdf_filename があればそれを優先で推定
    if args.doc_id is None and inferred_from_json:
        doc_id = make_doc_id_from_filename(inferred_from_json, args.doc_id_prefix)

    # --- TOC INSERT ---
    out_lines.append(f"-- TOC for {doc_id}")
    for row in toc:
        sp = int(row["start_page"]); ep = int(row["end_page"])
        section = sql_escape(str(row["section_path"]))
        out_lines.append(
            "INSERT INTO toc (doc_id, section_path, start_page, end_page, version) "
            f"VALUES ('{sql_escape(doc_id)}','{section}',{sp},{ep},'{sql_escape(version)}');"
        )

    # 埋め込み器
    embed = get_embedder(use_local=args.embed_local)

    # --- 章ごとにページ→チャンク化 ---
    for row in toc:
        sp = int(row["start_page"]); ep = int(row["end_page"])
        section_path = str(row["section_path"])
        section_text, page_pairs = build_section_text(pages, sp, ep)

        # 章テキストからチャンクを切る（ページ境界は補助用途。pageは所属ページ代表値として sp を採用）
        chunks = split_into_chunks(section_text, target_chars=args.target_chars, max_chars=args.max_chars)
        if not chunks:
            continue
        # 埋め込み
        embeddings = embed(chunks)

        for idx, ch in enumerate(chunks, start=1):
            page_rep = sp  # 代表ページを章の先頭に寄せておく（必要なら改良）
            tokens = approx_token_count(ch)
            emb = embeddings[idx - 1]
            emb_sql = "(" + ",".join(f"{x:.6f}" for x in emb) + ")"
            out_lines.append(
                "INSERT INTO chunks (doc_id, section_path, page, text, tokens, embedding, version) VALUES (" \
                f"'{sql_escape(doc_id)}'," \
                f"'{sql_escape(section_path)}'," \
                f"{page_rep}," \
                f"'{sql_escape(ch)}'," \
                f"{tokens}," \
                f"'{emb_sql}'::vector," \
                f"'{sql_escape(version)}'" \
                ");"
            )


def main():
    parser = argparse.ArgumentParser(description="PDF→TOC→章内チャンク→SQL生成")
    parser.add_argument("--pdf", required=True, help="PDFパス（glob可: './docs/*.pdf'）")
    parser.add_argument("--toc-json", help="TOC JSON（ファイル or ディレクトリ可。ラッパー/配列どちらもOK）")
    parser.add_argument("--doc-id", help="doc_id を明示指定（未指定時はPDF名/JSONのpdf_filenameから推定）")
    parser.add_argument("--doc-id-prefix", help="doc_id の頭に付ける任意プレフィックス")
    parser.add_argument("--version", default="v0", help="guideline版")
    parser.add_argument("--out-sql", required=True, help="出力SQLファイルパス")
    parser.add_argument("--embed-local", action="store_true", help="ローカル埋め込み（sentence-transformers）を使う")
    parser.add_argument("--target-chars", type=int, default=2400, help="チャンク目標文字数（≈600 tokens）")
    parser.add_argument("--max-chars", type=int, default=3600, help="チャンク最大文字数（超過時は強制分割）")

    args = parser.parse_args()

    pdf_list = sorted(glob.glob(args.pdf))
    if not pdf_list:
        print(f"PDFが見つかりません: {args.pdf}", file=sys.stderr)
        sys.exit(1)

    out_lines: List[str] = []
    out_lines.append(DDL)

    for i, pdf_path in enumerate(pdf_list, start=1):
        out_lines.append("\n-- ===============================================")
        out_lines.append(f"-- {i:03d}) {os.path.basename(pdf_path)}")
        out_lines.append("-- ===============================================\n")
        process_single_pdf(pdf_path, args, out_lines)

    os.makedirs(os.path.dirname(os.path.abspath(args.out_sql)), exist_ok=True)
    with open(args.out_sql, "w", encoding="utf-8") as f:
        f.write("\n".join(out_lines))

    print(f"生成完了: {args.out_sql}")


if __name__ == "__main__":
    main()

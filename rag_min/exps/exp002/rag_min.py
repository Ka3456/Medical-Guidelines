#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag_min.py  (all-in-one, safe edition)
--------------------------------------
目的:
- 安全なチャンク化（ゼロ上書き事故を防止）
- 埋め込みを別サブコマンドで投入（ゼロベクトル禁止）
- 最小の生SQLリトリーバ（章内限定＋trgm融合の下準備）
- スキーマ初期化（NOT NULL/CHECK/一意制約）

依存:
  pip install psycopg[binary] pymupdf regex
  (埋め込みを実用するなら openai 等を別途)

環境変数:
  DATABASE_URL  (例: postgresql://postgres@localhost:5432/med_guides)
"""
from __future__ import annotations

import os
import re
import sys
import math
import time
import json
import hashlib
import random
import argparse
from dataclasses import dataclass
from typing import List, Tuple, Iterable, Optional

import psycopg
import fitz  # pymupdf

DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/med_guides")


# =========================
# Utilities
# =========================

def sha1(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def clean_text(s: str) -> str:
    s = re.sub(r"[ \t\u3000]+", " ", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()


def approx_tokens(text: str) -> int:
    # ざっくり: 文字数/2 をトークン数近似
    return max(1, math.ceil(len(text) / 2))


def sentence_chunks(text: str, *, min_chars=800, max_chars=1400, overlap_ratio=0.1) -> List[str]:
    # 日本語の句点ベースで分割
    sentences = re.split(r"(?<=。)\s*", text)
    chunks, cur = [], ""
    for sent in sentences:
        if not sent:
            continue
        if len(cur) + len(sent) <= max_chars:
            cur += sent
        else:
            if len(cur) >= min_chars:
                chunks.append(cur)
                # overlap
                overlap = int(len(cur) * overlap_ratio)
                cur = cur[-overlap:] + sent
            else:
                chunks.append(cur + sent)
                cur = ""
    if cur and len(cur) >= max(1, min_chars // 2):
        chunks.append(cur)
    return [c.strip() for c in chunks if c.strip()]


# =========================
# Schema (DDL)
# =========================

SCHEMA_SQL = r"""
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS toc (
  id SERIAL PRIMARY KEY,
  doc_id TEXT,
  section_path TEXT,    -- "6 薬物療法 > 6.2 DPP-4阻害薬"
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
  embedding VECTOR(1536),
  version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  text_hash TEXT
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_chunks_vec ON chunks
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_chunks_scope ON chunks (doc_id, section_path, page);
CREATE INDEX IF NOT EXISTS chunks_text_trgm_idx ON chunks USING gin (text gin_trgm_ops);

-- 安全ガード: NOT NULL
ALTER TABLE chunks
  ALTER COLUMN doc_id SET NOT NULL,
  ALTER COLUMN section_path SET NOT NULL,
  ALTER COLUMN page SET NOT NULL,
  ALTER COLUMN text SET NOT NULL;

-- pageは正の値
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chunks_page_positive'
  ) THEN
    ALTER TABLE chunks ADD CONSTRAINT chunks_page_positive CHECK (page > 0);
  END IF;
END $$;

-- ベクトルノルム > 0 をチェックする関数
CREATE OR REPLACE FUNCTION vector_l2_norm(v vector)
RETURNS double precision
LANGUAGE SQL IMMUTABLE AS $$
  SELECT sqrt(SUM(x*x)) FROM (SELECT unnest(v) AS x) t;
$$;

-- ゼロベクトル禁止 (NULL は許容)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chunks_embedding_nonzero'
  ) THEN
    ALTER TABLE chunks
      ADD CONSTRAINT chunks_embedding_nonzero
      CHECK (embedding IS NULL OR vector_l2_norm(embedding) > 0);
  END IF;
END $$;

-- 自然重複回避: 同一doc/章/ページ/テキストハッシュで一意
CREATE UNIQUE INDEX IF NOT EXISTS uniq_chunk
  ON chunks(doc_id, section_path, page, text_hash);
"""


# =========================
# TOC helper
# =========================

@dataclass
class Section:
    section_path: str
    start_page: int
    end_page: int


def load_sections(conn, doc_id: str) -> List[Section]:
    sql = """SELECT section_path, start_page, end_page
             FROM toc WHERE doc_id = %s ORDER BY start_page"""
    with conn.cursor() as cur:
        cur.execute(sql, (doc_id,))
        rows = cur.fetchall()
    return [Section(r[0], int(r[1]), int(r[2])) for r in rows]


# =========================
# Chunking
# =========================

UPSERT_SQL = r"""
INSERT INTO chunks (doc_id, section_path, page, text, tokens, embedding, version, text_hash)
VALUES (%(doc_id)s, %(section_path)s, %(page)s, %(text)s, %(tokens)s, %(embedding)s, %(version)s, %(text_hash)s)
ON CONFLICT (doc_id, section_path, page, text_hash)
DO UPDATE SET
  text = CASE
            WHEN EXCLUDED.text IS DISTINCT FROM chunks.text
                 AND EXCLUDED.text IS NOT NULL AND EXCLUDED.text <> ''
            THEN EXCLUDED.text
            ELSE chunks.text
         END,
  tokens = CASE
              WHEN chunks.tokens IS NULL OR chunks.tokens = 0
              THEN COALESCE(NULLIF(EXCLUDED.tokens, 0), chunks.tokens)
              ELSE chunks.tokens
           END,
  embedding = chunks.embedding,           -- ここは別サブコマンドでのみ更新
  version = COALESCE(EXCLUDED.version, chunks.version);
"""


def extract_text_in_pages(pdf: fitz.Document, start_page: int, end_page: int) -> List[Tuple[int, str]]:
    # start/end は1始まり想定, fitzは0始まり
    out = []
    for p in range(start_page - 1, end_page):
        page = pdf.load_page(p)
        txt = page.get_text("text")
        out.append((p + 1, clean_text(txt)))
    return out


def cmd_init_db(args):
    with psycopg.connect(DB_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(SCHEMA_SQL)
    print("✅ schema applied")


def cmd_chunk(args):
    doc_id = args.doc
    pdf_path = args.pdf
    version = args.version

    if not os.path.exists(pdf_path):
        print(f"[ERR] pdf not found: {pdf_path}", file=sys.stderr)
        sys.exit(2)

    with psycopg.connect(DB_URL) as conn:
        sections = load_sections(conn, doc_id)
        if not sections:
            print(f"[ERR] toc empty for doc_id={doc_id}", file=sys.stderr)
            sys.exit(3)

        pdf = fitz.open(pdf_path)

        with conn.transaction():
            total = 0
            for sec in sections:
                if sec.start_page <= 0 or sec.end_page <= 0 or sec.end_page < sec.start_page:
                    raise RuntimeError(f"Invalid page range: {sec.section_path} {sec.start_page}-{sec.end_page}")

                pages = extract_text_in_pages(pdf, sec.start_page, sec.end_page)

                batch = []
                for page_num, page_text in pages:
                    if not page_text:
                        continue
                    for ch in sentence_chunks(page_text):
                        h = sha1(f"{doc_id}|{sec.section_path}|{page_num}|{ch[:64]}")
                        row = dict(
                            doc_id=doc_id,
                            section_path=sec.section_path,
                            page=page_num,
                            text=ch,
                            tokens=approx_tokens(ch),
                            embedding=None,     # ← ここでは絶対に入れない
                            version=version,
                            text_hash=h
                        )
                        # 強制ガード
                        assert row["page"] > 0, "page==0"
                        assert row["tokens"] > 0, "tokens==0"
                        batch.append(row)

                if batch:
                    with conn.cursor() as cur:
                        cur.executemany(UPSERT_SQL, batch)
                        total += len(batch)

            # 0値の簡易検査
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM chunks WHERE doc_id=%s AND tokens=0", (doc_id,))
                zero_tokens = cur.fetchone()[0]
                if zero_tokens > 0:
                    raise RuntimeError(f"ゼロトークン検出 {zero_tokens} 件 → ROLLBACK")

                cur.execute("SELECT COUNT(*) FROM chunks WHERE doc_id=%s AND page=0", (doc_id,))
                zero_page = cur.fetchone()[0]
                if zero_page > 0:
                    raise RuntimeError(f"page=0 検出 {zero_page} 件 → ROLLBACK")

        print(f"✅ chunk inserted/updated: {total} rows (embedding not set)")


# =========================
# Embedding (dummy / or wire your own)
# =========================

def dummy_embed(texts: List[str], dim: int = 1536) -> List[List[float]]:
    # 実運用は OpenAI/Azure/ローカルST に置換すること
    # 重要: ゼロベクトルは絶対返さない
    out = []
    for t in texts:
        rng = random.Random(sha1(t))  # 再現性
        v = [rng.random() for _ in range(dim)]
        # 最低限ノルムが小さすぎないよう簡単正規化
        norm = math.sqrt(sum(x * x for x in v)) or 1.0
        v = [x / norm for x in v]
        out.append(v)
    return out


def cmd_embed(args):
    doc_id = args.doc
    batch_size = args.batch

    with psycopg.connect(DB_URL) as conn:
        while True:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, text FROM chunks
                    WHERE doc_id=%s AND embedding IS NULL
                    ORDER BY id ASC
                    LIMIT %s
                """, (doc_id, batch_size))
                rows = cur.fetchall()

            if not rows:
                print("✅ embed: nothing to do")
                break

            ids = [r[0] for r in rows]
            texts = [r[1] for r in rows]
            vecs = dummy_embed(texts)

            # 安全: ゼロノルム弾く
            safe = []
            for i, v in zip(ids, vecs):
                norm = math.sqrt(sum(x*x for x in v))
                if norm == 0.0:
                    continue
                safe.append((v, i))

            with conn.transaction():
                with conn.cursor() as cur:
                    cur.executemany("UPDATE chunks SET embedding=%s WHERE id=%s", safe)

            print(f"embedded {len(safe)} rows")
            time.sleep(0.05)


# =========================
# Retrieve (section-limited, early version)
# =========================

def fuzzy_pick_sections(conn, doc_id: str, query: str, topk: int = 3) -> List[str]:
    """
    ざっくり: section_path を単純包含/類似で拾う簡易版。
    実運用では rapidfuzz 等を推奨。
    """
    with conn.cursor() as cur:
        cur.execute("SELECT section_path FROM toc WHERE doc_id=%s", (doc_id,))
        secs = [r[0] for r in cur.fetchall()]
    q = query.lower()
    scored = []
    for s in secs:
        s_low = s.lower()
        score = 0
        if q in s_low:
            score += 2
        # トークン単位で素朴スコア
        for tok in re.split(r"\W+", q):
            if tok and tok in s_low:
                score += 1
        scored.append((score, s))
    scored.sort(reverse=True)
    return [s for _, s in scored[:topk] if _ > 0] or secs[:topk]


def cmd_retrieve(args):
    doc_id = args.doc
    query = args.query
    k = args.k
    oversample = max(k, args.oversample)

    with psycopg.connect(DB_URL) as conn:
        # 章ルーティング（簡易）
        sections = fuzzy_pick_sections(conn, doc_id, query, topk=3)

        # ベクトルは未使用（最小版）。trgm類似でoversample拾う
        sql = r"""
        SET LOCAL ivfflat.probes = 10;
        SELECT id, section_path, page, text,
               similarity(text, %(q)s) AS lex
        FROM chunks
        WHERE doc_id = %(doc)s AND section_path = ANY(%(secs)s)
        ORDER BY lex DESC
        LIMIT %(limit)s;
        """
        with conn.cursor() as cur:
            cur.execute(sql, {"q": query, "doc": doc_id, "secs": sections, "limit": oversample})
            rows = cur.fetchall()

        # MMR簡易 (Jaccard on words)
        def jaccard(a: str, b: str) -> float:
            sa, sb = set(a.split()), set(b.split())
            den = len(sa | sb) or 1
            return len(sa & sb) / den

        lam = 0.65
        chosen = []
        for r in rows:
            rel = float(r[3]) if isinstance(r[3], (float, int)) else 0.0  # lex
            div = max((jaccard(r[3], c[3]) for c in chosen), default=0.0) if chosen else 0.0
            score = lam * rel - (1 - lam) * div
            chosen.append((score, r))
            if len(chosen) >= k:
                break

        # 整形
        out = []
        for _, r in chosen[:k]:
            out.append({
                "id": r[0],
                "section_path": r[1],
                "page": r[2],
                "text": r[3] if isinstance(r[3], str) else "",
            })
        print(json.dumps({"sections": sections, "hits": out}, ensure_ascii=False, indent=2))


# =========================
# CLI
# =========================

def main():
    ap = argparse.ArgumentParser(description="RAG minimal pipeline (safe edition)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("init-db", help="Create/upgrade schema with safety guards")
    sp.set_defaults(func=cmd_init_db)

    sp = sub.add_parser("chunk", help="Chunk PDF safely (embedding remains NULL)")
    sp.add_argument("--doc", required=True, help="doc_id")
    sp.add_argument("--pdf", required=True, help="path to PDF")
    sp.add_argument("--version", default="v1")
    sp.set_defaults(func=cmd_chunk)

    sp = sub.add_parser("embed", help="Fill embeddings for NULL rows (dummy embed)")
    sp.add_argument("--doc", required=True, help="doc_id")
    sp.add_argument("--batch", type=int, default=256)
    sp.set_defaults(func=cmd_embed)

    sp = sub.add_parser("retrieve", help="Retrieve top-k (section-limited, trgm only minimal)")
    sp.add_argument("--doc", required=True)
    sp.add_argument("--query", required=True)
    sp.add_argument("--k", type=int, default=8)
    sp.add_argument("--oversample", type=int, default=40)
    sp.set_defaults(func=cmd_retrieve)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

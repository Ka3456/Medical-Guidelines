#!/usr/bin/env python
import argparse
import json
import os
import sys

import psycopg2
from psycopg2.extras import execute_batch

from pypdf import PdfReader


def get_conn():
    """
    Docker の設定に合わせたデフォルト値。
    必要なら環境変数で上書き可能。
    """
    host = os.getenv("PGHOST", "localhost")
    port = int(os.getenv("PGPORT", "5433"))
    dbname = os.getenv("PGDATABASE", "ragdb")
    user = os.getenv("PGUSER", "pguser")
    password = os.getenv("PGPASSWORD", "pgpass")

    conn = psycopg2.connect(
        host=host, port=port, dbname=dbname, user=user, password=password
    )
    conn.autocommit = False
    return conn


def create_tables(conn):
    """
    RAG 用の基本テーブル。
    - toc    : 章・節情報
    - chunks : チャンク（embedding は後で入れる）
    """
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        cur.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS toc (
              id SERIAL PRIMARY KEY,
              doc_id TEXT NOT NULL,
              section_path TEXT NOT NULL,
              start_page INT NOT NULL,
              end_page   INT NOT NULL,
              version TEXT NOT NULL,
              created_at TIMESTAMPTZ DEFAULT now()
            );
            """
        )

        cur.execute(
            """
            DO $$
            BEGIN
              IF NOT EXISTS (
                SELECT 1
                FROM   pg_constraint
                WHERE  conname = 'toc_doc_section_version_key'
              ) THEN
                ALTER TABLE toc
                  ADD CONSTRAINT toc_doc_section_version_key
                  UNIQUE (doc_id, section_path, version);
              END IF;
            END$$;
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS chunks (
              id SERIAL PRIMARY KEY,
              doc_id TEXT NOT NULL,
              section_path TEXT,
              page INT,
              text TEXT,
              tokens INT DEFAULT 0,
              embedding VECTOR(1536),
              version TEXT NOT NULL,
              created_at TIMESTAMPTZ DEFAULT now()
            );
            """
        )

        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_chunks_doc_section_page "
            "ON chunks (doc_id, section_path, page);"
        )

        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_chunks_text_trgm "
            "ON chunks USING gin (text gin_trgm_ops);"
        )

    conn.commit()


def load_toc_from_json(conn, json_path, doc_id, version):
    """
    chapter.json → toc テーブル登録
    戻り値として toc のリストも返す。
    """
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    toc_entries = data.get("toc", [])
    if not toc_entries:
        print("toc が空です。JSON を確認してください。", file=sys.stderr)
        return []

    rows = []
    for item in toc_entries:
        section_path = item["section_path"]
        start_page = int(item["start_page"])
        end_page = int(item["end_page"])
        rows.append((doc_id, section_path, start_page, end_page, version))

    with conn.cursor() as cur:
        # 同じ doc_id + version は一旦削除して入れ直す
        cur.execute(
            "DELETE FROM toc WHERE doc_id = %s AND version = %s;",
            (doc_id, version),
        )

        execute_batch(
            cur,
            """
            INSERT INTO toc (doc_id, section_path, start_page, end_page, version)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (doc_id, section_path, version)
            DO UPDATE SET
              start_page = EXCLUDED.start_page,
              end_page   = EXCLUDED.end_page;
            """,
            rows,
        )

    conn.commit()
    print(f"[toc] inserted {len(rows)} rows for doc_id={doc_id}, version={version}")
    return toc_entries


def chunk_text(text: str, max_chars: int = 1200, overlap_chars: int = 200):
    """
    シンプルな文字数ベースのチャンク化。
    - 章境界は別関数側で管理
    - ここでは 1つのページのテキストを分割するイメージ
    """
    text = (text or "").strip()
    if not text:
        return []

    if len(text) <= max_chars:
        return [text]

    chunks = []
    start = 0
    length = len(text)

    while start < length:
        end = min(start + max_chars, length)
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end == length:
            break
        # 少しだけオーバーラップ
        start = max(0, end - overlap_chars)

    return chunks


def chunk_pdf_by_toc(conn, pdf_path, toc_entries, doc_id, version):
    """
    PDF を章ごとのページ範囲で読み、
    章をまたがないようにチャンク化 → chunks テーブルに INSERT。
    """
    reader = PdfReader(pdf_path)
    rows = []

    for item in toc_entries:
        section_path = item["section_path"]
        start_page = int(item["start_page"])  # ここは 1 始まり想定
        end_page = int(item["end_page"])

        # 安全チェック
        if start_page < 1 or end_page > len(reader.pages):
            print(
                f"[WARN] section {section_path} のページ範囲がPDF実ページ外です: "
                f"{start_page}-{end_page} / total={len(reader.pages)}",
                file=sys.stderr,
            )
            continue

        for page_no in range(start_page, end_page + 1):
            page = reader.pages[page_no - 1]  # pypdf は 0 index
            page_text = page.extract_text() or ""

            # ページ単位でチャンク化（章はまたがない）
            chunks = chunk_text(page_text, max_chars=1200, overlap_chars=200)
            for chunk in chunks:
                rows.append(
                    (
                        doc_id,
                        section_path,
                        page_no,
                        chunk,
                        version,
                    )
                )

    if not rows:
        print("[chunks] 追加する行がありません。", file=sys.stderr)
        return

    with conn.cursor() as cur:
        # 今回の doc_id + version の古いチャンクは消して入れ直す
        cur.execute(
            "DELETE FROM chunks WHERE doc_id = %s AND version = %s;",
            (doc_id, version),
        )

        execute_batch(
            cur,
            """
            INSERT INTO chunks (doc_id, section_path, page, text, version)
            VALUES (%s, %s, %s, %s, %s);
            """,
            rows,
            page_size=100,
        )

    conn.commit()
    print(f"[chunks] inserted {len(rows)} rows for doc_id={doc_id}, version={version}")


def main():
    parser = argparse.ArgumentParser(
        description="PDF + chapter.json から toc / chunks を作成して PostgreSQL に投入するスクリプト"
    )
    parser.add_argument(
        "--pdf",
        required=True,
        help="ガイドライン PDF のパス (例: JCS2015_aonuma_h.pdf)",
    )
    parser.add_argument(
        "--chapter-json",
        required=True,
        help="chapter JSON のパス (例: JCS2015_aonuma_h_chapter.json)",
    )
    parser.add_argument(
        "--doc-id",
        default=None,
        help="doc_id。デフォルトは PDF ファイル名の拡張子なし (例: JCS2015_aonuma_h)",
    )
    parser.add_argument(
        "--version",
        default="v1",
        help="ガイドラインのバージョン文字列 (例: v1, 2015 など)",
    )

    args = parser.parse_args()

    # doc_id を決める
    if args.doc_id is not None:
        doc_id = args.doc_id
    else:
        doc_id = os.path.splitext(os.path.basename(args.pdf))[0]

    conn = get_conn()
    try:
        create_tables(conn)
        toc_entries = load_toc_from_json(conn, args.chapter_json, doc_id, args.version)
        if not toc_entries:
            print("toc_entries が空なのでチャンク化をスキップします。", file=sys.stderr)
            return
        chunk_pdf_by_toc(conn, args.pdf, toc_entries, doc_id, args.version)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

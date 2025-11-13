#!/usr/bin/env python
import os
import sys
import time
import argparse
from typing import List, Tuple

import psycopg2
from psycopg2.extras import execute_batch

from openai import OpenAI  # pip install openai


# ⚠ テーブル側が VECTOR(1536) なので small を使う
EMBED_MODEL = "text-embedding-3-small"


def get_conn():
    """
    DockerのPostgresに接続。
    環境変数があればそちらを優先。
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


def get_client():
    """
    OpenAI クライアント。
    OPENAI_API_KEY が環境変数にある前提。
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY が環境変数に設定されていません。", file=sys.stderr)
        sys.exit(1)

    client = OpenAI(api_key=api_key)
    return client


def fetch_unembedded_chunks(
    conn,
    doc_id: str,
    version: str,
    limit: int = 128,
) -> List[Tuple[int, str]]:
    """
    まだ embedding が入っていないチャンクを取得。
    - 1行 = (id, text)
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, text
            FROM chunks
            WHERE doc_id = %s
              AND version = %s
              AND embedding IS NULL
            ORDER BY id
            LIMIT %s;
            """,
            (doc_id, version, limit),
        )
        rows = cur.fetchall()
    return rows


def embed_texts(client: OpenAI, texts: List[str]) -> List[Tuple[List[float], int]]:
    """
    OpenAI Embeddings APIを使って、複数テキストを一括埋め込み。
    戻り値: [(embeddingベクトル(list[float]), token数), ...]
    token数は今は 0 のダミーで入れている（必要なら usage から足す）
    """
    if not texts:
        return []

    # 空文字はAPIに投げても意味ないので、最低1文字にしておく
    inputs = [t if t.strip() else " " for t in texts]

    resp = client.embeddings.create(
        model=EMBED_MODEL,
        input=inputs,
    )

    result: List[Tuple[List[float], int]] = []
    for d in resp.data:
        vec = d.embedding
        # usageは全体に対してなので、細かく扱うなら分配ロジックを後で追加
        result.append((vec, 0))

    return result


def update_embeddings(
    conn,
    id_vec_pairs: List[Tuple[int, List[float], int]],
):
    """
    chunks テーブルの embedding / tokens をまとめて更新。
    """
    if not id_vec_pairs:
        return

    with conn.cursor() as cur:
        rows_for_sql = []
        for cid, vec, tokens in id_vec_pairs:
            # ✅ pgvector は "[0.1,0.2,...]" 形式を期待する
            vec_str = "[" + ",".join(f"{x:.8f}" for x in vec) + "]"
            rows_for_sql.append((vec_str, tokens, cid))

        execute_batch(
            cur,
            """
            UPDATE chunks
            SET embedding = %s::vector,
                tokens    = %s
            WHERE id = %s;
            """,
            rows_for_sql,
            page_size=100,
        )
    conn.commit()


def main():
    parser = argparse.ArgumentParser(
        description="OpenAI Embeddings を使って chunks テーブルの embedding を埋めるスクリプト"
    )
    parser.add_argument(
        "--doc-id",
        required=True,
        help="対象とする doc_id (例: JCS2015_aonuma_h)",
    )
    parser.add_argument(
        "--version",
        default="v1",
        help="対象バージョン (デフォルト: v1)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=64,
        help="一度にAPIに投げるチャンク数 (デフォルト: 64)",
    )
    parser.add_argument(
        "--max-batches",
        type=int,
        default=0,
        help="最大バッチ数。0 の場合は embedding が埋まるまで繰り返す。",
    )

    args = parser.parse_args()

    conn = get_conn()
    client = get_client()

    processed = 0
    batch_idx = 0

    try:
        while True:
            if args.max_batches and batch_idx >= args.max_batches:
                print(f"max_batches={args.max_batches} に達したので終了。")
                break

            rows = fetch_unembedded_chunks(
                conn, doc_id=args.doc_id, version=args.version, limit=args.batch_size
            )
            if not rows:
                print("embedding 未設定のチャンクはもうありません。完了。")
                break

            ids = [r[0] for r in rows]
            texts = [r[1] for r in rows]

            print(f"[batch {batch_idx}] {len(rows)} chunks を埋め込み中...")

            try:
                vecs_and_tokens = embed_texts(client, texts)
            except Exception as e:
                print(f"ERROR: embeddings API でエラー: {e}", file=sys.stderr)
                # 軽くリトライ
                time.sleep(5)
                continue

            id_vec_pairs = []
            for cid, (vec, tokens) in zip(ids, vecs_and_tokens):
                id_vec_pairs.append((cid, vec, tokens))

            update_embeddings(conn, id_vec_pairs)

            processed += len(rows)
            batch_idx += 1
            print(f"  -> 累計 {processed} chunks 更新")

            # レートリミットが気になる場合は軽くsleep
            time.sleep(0.5)

    finally:
        conn.close()


if __name__ == "__main__":
    main()

#!/usr/bin/env python
import os
import argparse
import psycopg2
from psycopg2.extras import DictCursor
from openai import OpenAI

# ===== 設定 =====
DEFAULT_DSN = "dbname=ragdb user=pguser password=pgpass host=localhost port=5433"
EMBED_MODEL = "text-embedding-3-small"
CHAT_MODEL = "gpt-4.1-mini"   # 必要に応じて変えてOK
DEFAULT_QUESTION_TEXT = "ジゴキシンの血中濃度のモニタリングは有効ですか"


# ===== ベクトルを PostgreSQL の vector 文字列に変換 =====
def vec_to_sql_literal(vec):
    # pgvector は [1,2,3] のような表現を受け付ける
    return "[" + ",".join(f"{x:.6f}" for x in vec) + "]"


# ===== 質問 → 埋め込み =====
def embed_query(client: OpenAI, query: str):
    resp = client.embeddings.create(
        model=EMBED_MODEL,
        input=query,
    )
    return resp.data[0].embedding


# ===== chunks から類似チャンクを取得 =====
def retrieve_chunks(conn, doc_id: str, version: str, qvec, k: int = 8):
    qvec_sql = vec_to_sql_literal(qvec)

    sql = """
        SET LOCAL ivfflat.probes = 10;

        SELECT
            id,
            section_path,
            page,
            text,
            1 - (embedding <=> %s::vector) AS cos_sim
        FROM chunks
        WHERE doc_id = %s
          AND version = %s
          AND embedding IS NOT NULL
        ORDER BY embedding <=> %s::vector
        LIMIT %s;
    """

    with conn.cursor(cursor_factory=DictCursor) as cur:
        cur.execute(sql, (qvec_sql, doc_id, version, qvec_sql, k))
        rows = cur.fetchall()

    return rows


# ===== モデルに渡すコンテキストを組み立て =====
def build_context(hits):
    """
    hits: retrieve_chunks() の結果
    """
    blocks = []
    for i, h in enumerate(hits, 1):
        header = f"[{i}] {h['section_path']} (p.{h['page']})"
        body = h["text"]
        blocks.append(header + "\n" + body)

    return "\n\n".join(blocks)


# ===== OpenAI に質問する =====
def ask_with_rag(client: OpenAI, query: str, hits, doc_id: str):
    context = build_context(hits)

    system_prompt = f"""
あなたは日本の循環器専門医を支援する「ガイドライン専用アシスタント」です。
対象ガイドライン: {doc_id}

▼厳守事項
- 回答は **日本語** で行うこと
- 出力は **Markdown形式** とすること（見出し・番号付きリスト・箇条書きを適宜使用）
- ここで渡されたコンテキストの範囲内でのみ回答すること
- ガイドライン本文に **明記されていないことは記載しない** こと
  - 不明な点や記載のない事項は「このガイドライン本文からは読み取れない」と明言する
- 「〜と考えられる」「〜と思われる」などの **あいまいな表現は避ける** こと
  - ガイドラインに記載された内容を、可能な限り **はっきり・具体的** に述べる
- 一般的知識やあなた自身の推測で補わず、**必ず提供されたコンテキストに基づいて**回答すること
- 可能な限り、引用元を
  `［doc: {doc_id}, {{section_path}}, p.{{page}}］`
  のような形式で明示すること
""".strip()

    user_content = f"""以下のガイドラインの抜粋を参照して、質問に答えてください。

=== ガイドライン抜粋 ===
{context}

=== 質問 ===
{query}
"""

    resp = client.chat.completions.create(
        model=CHAT_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        temperature=0.1,
    )

    return resp.choices[0].message.content


def handle_question(client: OpenAI, conn, args, question: str):
    # 1) 質問を埋め込み
    qvec = embed_query(client, question)

    # 2) ベクトル検索
    hits = retrieve_chunks(conn, args.doc_id, args.version, qvec, k=args.top_k)

    if not hits:
        print("関連チャンクが見つかりませんでした…。")
        return

    # 3) モデルに投げる
    answer = ask_with_rag(client, question, hits, args.doc_id)

    print("\n--- 回答 ---")
    print(answer)


def rag_answer(
    question: str,
    doc_id: str,
    version: str = "v1",
    top_k: int = 8,
    dsn: str = DEFAULT_DSN,
) -> str:
    """
    Python から簡単に呼び出せる RAG アンサー関数。
    CLI を経由せず、answer だけ文字列で返す。
    """
    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError("環境変数 OPENAI_API_KEY を設定してください。")

    client = OpenAI()
    conn = psycopg2.connect(dsn)

    try:
        # 1) 埋め込み計算
        qvec = embed_query(client, question)

        # 2) ベクトル検索
        hits = retrieve_chunks(conn, doc_id, version, qvec, k=top_k)
        if not hits:
            return "関連チャンクが見つかりませんでした。"

        # 3) モデルで回答生成
        answer = ask_with_rag(client, question, hits, doc_id)
        return answer
    finally:
        conn.close()



# ===== メイン（CLI対話） =====
def main():
    parser = argparse.ArgumentParser(description="Simple RAG chat for JCS guideline")
    parser.add_argument("--doc-id", default="JCS2015_aonuma_h")
    parser.add_argument("--version", default="v1")
    parser.add_argument("--top-k", type=int, default=8)
    parser.add_argument("--dsn", default=os.getenv("PG_DSN", DEFAULT_DSN))
    args = parser.parse_args()

    # OpenAI API キーは環境変数 OPENAI_API_KEY から読む
    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError("環境変数 OPENAI_API_KEY を設定してください。")

    client = OpenAI()
    conn = psycopg2.connect(args.dsn)

    print("=== ガイドライン RAG チャット ===")
    print(f"doc_id={args.doc_id}, version={args.version}, top_k={args.top_k}")
    print("質問を入力してください。'exit' で終了します。")

    if DEFAULT_QUESTION_TEXT:
        print("\n=== デフォルト質問を処理します ===")
        print(f"質問: {DEFAULT_QUESTION_TEXT}")
        handle_question(client, conn, args, DEFAULT_QUESTION_TEXT)

    try:
        while True:
            try:
                q = input("\n質問> ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\n終了します。")
                break

            if not q:
                continue
            if q.lower() in {"exit", "quit", "q"}:
                print("終了します。")
                break

            handle_question(client, conn, args, q)

    finally:
        conn.close()


if __name__ == "__main__":
    main()

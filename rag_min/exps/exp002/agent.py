# Agent.py
import json
from typing import List, Dict, Optional

from openai import OpenAI
from rag_chat import rag_answer, DEFAULT_DSN  # ← さっき追加した関数を使う

client = OpenAI()

SYSTEM_PROMPT = """\
あなたは日本の診療ガイドライン検索システム用の「ルーターAI」です。
役割は、医師からの質問を読んで、
どのガイドラインPDF（doc_id）を検索すべきかを選ぶことです。

- 与えられた title / tags / 分野だけを使って判断してください。
- 疾患名、臓器名、検査名、治療法、ガイドライン区分（循環器・糖尿病・腎臓など）を手がかりに、
  関連しそうな doc_id を最大3つまで選んでください。
- 明らかに関係ないものは選ばないでください。
- どうしてもわからない場合は空配列 [] を返してください。
"""


def load_guidelines(path: str = "junkanki_title.json") -> List[Dict]:
    """ガイドライン一覧（JSON）を読み込むヘルパー。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # junkanki_title.json の形式を agent.py が期待する形式に変換
    if "pdfs" in data:
        guidelines = []
        for pdf in data["pdfs"]:
            # name から .pdf を除いたものを id として使用
            doc_id = pdf["name"].replace(".pdf", "")
            guidelines.append({
                "id": doc_id,
                "title": pdf["title"],
                "tags": []  # tags は空配列
            })
        return guidelines
    
    # 既存の形式（guidelines.json 形式）の場合はそのまま返す
    return data if isinstance(data, list) else []


def select_guideline(
    query: str,
    guidelines: List[Dict],
    max_docs: int = 3,
) -> List[str]:
    """
    質問文とガイドライン一覧から、
    GPT-4.1 に「どの doc_id を検索候補にするか」を決めさせる。
    戻り値は doc_id のリスト。
    """
    catalog_lines = []
    for g in guidelines:
        tags = ", ".join(g.get("tags", []))
        catalog_lines.append(
            f"- id: {g['id']}\n  title: {g['title']}\n  tags: {tags}"
        )
    catalog_text = "\n".join(catalog_lines)

    user_prompt = f"""\
ユーザーからの質問:
---
{query}
---

利用可能なガイドライン一覧:
---
{catalog_text}
---

ルール:
1. ユーザーの質問に臨床的に関係しそうなガイドラインを最大 {max_docs} 個まで選んでください。
2. 迷った場合は「より直接関連する疾患・病態」に絞ってください。
3. 出力は必ず次の JSON 形式だけにしてください（コメント禁止）:

{{
  "doc_ids": ["JCS2015_aonuma_h"]
}}
"""

    resp = client.chat.completions.create(
        model="gpt-4.1-mini",  # GPT-4.1 系を指定
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.0,
    )

    data = json.loads(resp.choices[0].message.content)
    doc_ids = data.get("doc_ids", [])
    if not isinstance(doc_ids, list):
        return []
    return [str(d) for d in doc_ids]


def agent_chat(
    question: str,
    dsn: Optional[str] = None,
    version: str = "v1",
    top_k: int = 8,
    guideline_json: str = "junkanki_title.json",
) -> str:
    """
    入口は question だけ。
    1) どのガイドラインを使うか選ぶ
    2) そのガイドラインで RAG して回答する
    """
    guidelines = load_guidelines(guideline_json)
    doc_ids = select_guideline(question, guidelines, max_docs=1)

    if not doc_ids:
        return "関連しそうなガイドラインを特定できませんでした。質問をもう少し具体的にしてみてください。"

    doc_id = doc_ids[0]  # とりあえず一番関連度が高いものだけ使う
    dsn = dsn or DEFAULT_DSN

    answer = rag_answer(
        question=question,
        doc_id=doc_id,
        version=version,
        top_k=top_k,
        dsn=dsn,
    )

    # どのガイドラインを使ったか分かるようにヘッダーを付けておく
    return f"[使用ガイドライン: {doc_id}]\n\n{answer}"


if __name__ == "__main__":
    print("=== Agent RAG チャット ===")
    # 質問をハードコード
    q = "大動脈弁閉鎖不全症が既往にある患者の注意すること"
    if q:
        print()
        print(agent_chat(q))

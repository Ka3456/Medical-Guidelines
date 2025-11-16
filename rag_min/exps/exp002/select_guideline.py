# Agent.py
import os
import json
from typing import List, Dict

from openai import OpenAI

# ===== OpenAI クライアント =====
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    raise RuntimeError("環境変数 OPENAI_API_KEY が設定されていません。")

client = OpenAI(api_key=api_key)

SYSTEM_PROMPT = """\
あなたは日本の診療ガイドライン検索システム用の「ルーターAI」です。
役割は、医師からの質問を読んで、
どのガイドラインPDF（doc_id）を検索すべきかを選ぶことだけです。

- ガイドラインの本文は読めません。与えられた title / tags / 分野だけを使って判断してください。
- 疾患名、臓器名、検査名、治療法、ガイドライン区分（循環器・糖尿病・腎臓など）を手がかりに、
  関連しそうな doc_id を最大3つまで選んでください。
- 明らかに関係ないものは選ばないでください。
- どうしてもわからない場合は空配列 [] を返してください。
"""

def load_guidelines(path: str = "guidelines.json") -> List[Dict]:
    """ガイドライン一覧（JSON）を読み込むヘルパー。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # junkanki_title.json の構造に対応: pdfs 配列を取得
    if isinstance(data, dict) and "pdfs" in data:
        pdfs = data["pdfs"]
        # name を id に変換し、tags を空配列として追加
        guidelines = []
        for pdf in pdfs:
            guidelines.append({
                "id": pdf.get("name", "").replace(".pdf", ""),
                "title": pdf.get("title", ""),
                "tags": []  # tags がない場合は空配列
            })
        return guidelines
    
    # 既存の構造（guidelines.json など）に対応
    if isinstance(data, list):
        return data
    
    # その他の場合は空配列を返す
    return []


def select_guidelines(
    query: str,
    guidelines: List[Dict],
    max_docs: int = 3,
) -> List[str]:
    """
    質問文とガイドライン一覧から、
    GPT-4.1 に「どの doc_id を検索候補にするか」を決めさせる。
    戻り値は doc_id のリスト。
    """
    # ガイドライン一覧をプロンプトに埋め込む
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
  "doc_ids": ["JCS2025_PTE_DVT", "JCS2024_AF"]
}}

上記のように doc_ids は文字列の配列とし、選んだガイドラインの id だけを列挙してください。
"""

    response = client.chat.completions.create(
        model="gpt-4.1-mini",  # ← GPT-4.1 を指定
        response_format={"type": "json_object"},  # JSONモード
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    )

    content = response.choices[0].message.content
    data = json.loads(content)

    # 安全側に倒してキーがなければ空配列
    doc_ids = data.get("doc_ids", [])
    if not isinstance(doc_ids, list):
        return []
    return [str(d) for d in doc_ids]

def get_guideline_title(guideline_id: str) -> str:    
    guidelines = load_guidelines("junkanki_title.json")
    for guideline in guidelines:
        if guideline["id"] == guideline_id:
            return guideline["title"]
    return ""


if __name__ == "__main__":
    # 動作テスト用
    guidelines = load_guidelines("junkanki_title.json")
    q = "大動脈乖離が偶然見つかった　症状なし　治療ほうしん"
    selected = select_guidelines(q, guidelines)
    print("選択された doc_id:", selected)
    print("選択されたガイドラインのタイトル:", get_guideline_title(selected[0]))

 

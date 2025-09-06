from __future__ import annotations
import json, re, unicodedata
from pathlib import Path
from typing import List, Dict, Tuple
from collections import defaultdict

# 依存: scikit-learn（TF-IDF用）。入っていなければ pip install scikit-learn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

###############################################################################
# 1) 日本語向けの軽い正規化
###############################################################################
_PUNCT = r"[、。．，・/／\-\–\—\(\)\[\]{}：:；;！!？\?\"'“”‘’→←↑↓＋+＝=＊*％%]"
_NUM = r"[0-9０-９]"
def normalize_ja(s: str) -> str:
    if not s:
        return ""
    # 全角→半角, NFKC
    s = unicodedata.normalize("NFKC", s)
    s = s.lower()
    # 章番号などの数字を 0 に置換してバリエーション抑制（「第10章/第9章」等のばらつき抑制）
    s = re.sub(_NUM, "0", s)
    # 記号除去
    s = re.sub(_PUNCT, " ", s)
    # 余分な空白統一
    s = re.sub(r"\s+", " ", s).strip()
    return s

###############################################################################
# 2) ルールベースのキーワード → 章候補辞書
#    ※必要に応じて追記/調整してください
###############################################################################
RULES: Dict[str, List[str]] = {
    # 定義・分類
    r"(定義|ステージ|分類|hfr?ef|hfp?ef|hfmr?ef|hfimp?ef|lvef)": ["第2章 定義"],
    # 診断・検査・評価
    r"(診断|アルゴリズム|バイオマーカー|心エコー|超音波|ct|mri|pet|nyha|運動耐容能|身体機能|遺伝学的検査|リスクスコア)":
        ["第4章 診断と経時的評価"],
    # 予防
    r"(予防|ステージa|発症予防|進展予防|生活習慣|スクリーン)":
        ["第5章 心不全予防"],
    # 慢性期治療（薬物/非薬物）
    r"(治療|薬|薬物|ガイド治療|アルゴリズム|ace|arb|arni|sglt2|mra|β遮断|利尿|デバイス|crt|icd|アブレーション|運動療法|リハビリ|植込|介入)":
        ["第6章 心不全に対する治療"],
    # 急性非代償性
    r"(急性非代償|adhf|急性期|初期対応|急性期管理|ニトログリセリン|カテコラミン)":
        ["第7章 急性非代償性心不全"],
    # ステージD/移植等
    r"(治療抵抗|ステージd|強心薬|補助循環|補助人工心臓|心臓移植|症状緩和)":
        ["第8章 治療抵抗性心不全"],
    # 特別な病態
    r"(肥大型心筋症|アミロイド|サルコイド|フレイル|サルコペニア|肺高血圧|妊娠|周産期|心房心筋症|中性脂肪蓄積|腫瘍随伴)":
        ["第9章 特別な病態・疾患"],
    # 併存症
    r"(併存症|腎機能|貧血|糖尿病|copd|睡眠時無呼吸|甲状腺|肝|うつ|認知)":
        ["第10章 併存症"],
    # 疾病管理
    r"(多職種|患者教育|セルフケア|栄養|遠隔|デジタル|心臓リハ|就労|社会復帰)":
        ["第11章 疾病管理"],
    # 緩和
    r"(緩和ケア|acp|意思決定|臨床倫理|治療の中止|差し控え)":
        ["第12章 緩和ケア"],
    # 地域連携
    r"(地域連携|地域包括ケア)":
        ["第13章 地域連携・地域包括ケア"],
    # 質評価
    r"(質の評価|quality|kpi|指標)":
        ["第14章 心不全診療における質の評価"],
    # 研究・将来
    r"(エビデンスギャップ|今後|研究|遺伝子編集|核酸医薬|デバイスの新規話題|治療用アプリ)":
        ["第15章 エビデンスギャップと今後の方向性"],
    # 患者向け
    r"(どんな病気|ならないため|症状って|診断や治療|上手く付き合う|家族と話し合い)":
        ["第16章 市民・患者への情報提供"],
}

# 章内の小節を深掘りしたい時にルールでブーストする例（任意）
SUBRULES: Dict[str, List[str]] = {
    r"(hfr?ef)": ["第6章 > 2.1 LVEFの低下した心不全（HFrEF）"],
    r"(hfp?ef)": ["第6章 > 2.2 LVEFの保たれた心不全（HFpEF）"],
    r"(hfmr?ef)": ["第6章 > 2.3 LVEFの軽度低下した心不全（HFmrEF）"],
    r"(hfimp?ef)": ["第6章 > 2.4 LVEFの改善した心不全（HFimpEF）"],
    r"(デバイス|crt|icd)": ["第6章 > 3.2 植込み型心臓電気デバイス治療"],
    r"(運動療法|リハビリ)": ["第6章 > 3.1 運動療法", "第11章 > 4. 運動療法・包括的心臓リハビリテーション"],
    r"(バイオマーカー|bnp|nt-probnp)": ["第4章 > 3. バイオマーカー","第6章 > 1.4 BNP/NT-proBNPガイド治療の指標としての測定"],
    r"(心エコー|echo)": ["第4章 > 4. 心エコー"],
}

###############################################################################
# 3) TOC読み込み & ベクトル化
###############################################################################
class ChapterRouter:
    def __init__(self, toc: List[dict]):
        # 全 section を正規化テキストに
        self.items = []
        for row in toc:
            text = row.get("section_path", "")
            norm = normalize_ja(text)
            self.items.append({
                "raw": row,
                "norm": norm,
                "section_path": text
            })
        # TF-IDF は section_path だけでなく、見出し語を複製してレーベル強調しておく
        corpus = [it["norm"] for it in self.items]
        self.vectorizer = TfidfVectorizer(analyzer="char", ngram_range=(2,4))
        self.mat = self.vectorizer.fit_transform(corpus)

        # ルール・小節ルールのコンパイル
        self._rules = [(re.compile(pat), dests) for pat, dests in RULES.items()]
        self._subrules = [(re.compile(pat), dests) for pat, dests in SUBRULES.items()]

        # section_path → index の逆引き
        self.idx_of = {it["section_path"]: i for i, it in enumerate(self.items)}

    def _rule_hits(self, q: str) -> Dict[str, float]:
        """ルールにマッチした section_path に重みを加点"""
        scores = defaultdict(float)
        for pat, dests in self._rules:
            if pat.search(q):
                for d in dests:
                    scores[d] += 2.0  # 章レベルの強いブースト
        for pat, dests in self._subrules:
            if pat.search(q):
                for d in dests:
                    scores[d] += 1.2  # 小節レベルのブースト
        return scores

    def _tfidf_scores(self, q: str) -> List[Tuple[int, float]]:
        vq = self.vectorizer.transform([q])
        sims = cosine_similarity(vq, self.mat)[0]
        return list(enumerate(sims))

    def route(self, prompt: str, topk: int = 5) -> List[dict]:
        """上位候補を返す。章(レベル1)を優先しつつ、小節も混ぜられる。"""
        qn = normalize_ja(prompt)
        # ルールスコア
        rule_scores = self._rule_hits(qn)
        # TF-IDFスコア
        tfidf = self._tfidf_scores(qn)

        # スコア融合
        results = []
        for idx, s in tfidf:
            sp = self.items[idx]["section_path"]
            fused = 0.70*s + 0.30*rule_scores.get(sp, 0.0)  # 係数はチューニング可
            results.append((idx, fused))

        # 「章(レベル1)を少し優遇」するブースト
        for i, (idx, sc) in enumerate(results):
            level = self.items[idx]["raw"].get("level", 3)
            if level == 1:
                results[i] = (idx, sc + 0.05)

        # 並び替え
        results.sort(key=lambda x: x[1], reverse=True)

        # 出力整形: 同じ章配下の重複を減らす簡易MMR
        seen_paths = set()
        out = []
        for idx, sc in results:
            row = self.items[idx]["raw"]
            key = row["section_path"]
            # 章名（「第N章 〜」）で束ねたい場合は、章名の先頭（"第N章"）までをキーにしても良い
            if key in seen_paths:
                continue
            seen_paths.add(key)
            out.append({
                "section_path": row["section_path"],
                "level": row.get("level"),
                "start_page": row.get("start_page"),
                "end_page": row.get("end_page"),
                "score": round(float(sc), 6)
            })
            if len(out) >= topk:
                break
        return out

###############################################################################
# 4) 使い方
###############################################################################
if __name__ == "__main__":
    # chapter.json をロード
    toc_json = json.loads(Path("toc/chapter.json").read_text(encoding="utf-8"))
    toc = toc_json["toc"]
    router = ChapterRouter(toc)

    # 例: ユーザーのプロンプト
    queries = [
        "HFpEFの薬物治療は？",
    ]
    for q in queries:
        print("Q:", q)
        hits = router.route(q, topk=5)
        for h in hits:
            print("  -", h)
        print()

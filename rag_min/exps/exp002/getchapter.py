#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PDFから章情報を抽出して chapter.json を生成（絞り込み強化版）

追加機能（前版からの差分）
- strictモード（--strict）：
  * L1は「第\\d章…／略語一覧／改訂にあたって／はじめに」のみ許容（キーワード推定は無効）
  * L2/L3は番号始まり（1. / 1.1 / 1.1.1 など）のみ許容
  * 見出し内の「図/表/単位/数式/疑問符(？/?)」を含むものは見出しから除外（L1は特に厳格）
- テキスト正規化（全角→半角・空白正規化・混在ドット/三点リーダ除去の改善）
- post-cleanupの強化：疑似ルート（文献ファイル名等）や表キャプション化の除外を追加
- gold差分レポート（--gold <HF_chapter.json>）：抽出結果と正解JSONを比較し、ズレを要約表示

依存: PyMuPDF (fitz) → pip install pymupdf
"""

import json
import re
import sys
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import argparse

try:
    import fitz  # PyMuPDF
except Exception as e:
    print("PyMuPDF (fitz) が必要です。`pip install pymupdf` を実行してください。")
    raise

# -----------------------------
# 正規表現・定数
# -----------------------------
TOC_KEYWORDS = ["目次", "Contents", "略語一覧", "改訂にあたって"]

LEVEL1_PATTERNS = [
    r"^第\s*\d+\s*章\s+.+",   # "第1章 はじめに"
    r"^第\s*\d+\s*章\s*$",    # "第1章"
    r"^略語一覧\s*$",
    r"^改訂にあたって\s*$",
    r"^はじめに\s*$",
]

LEVEL2_PATTERNS = [
    r"^\d+\.\s+.+",          # "1. タイトル"
    r"^\d+\.\d+\.\s+.+",     # "1.1. タイトル"
]

LEVEL3_PATTERNS = [
    r"^\d+\.\d+\s+.+",       # "1.1 タイトル"
    r"^\d+\.\d+\.\d+\s+.+",  # "1.1.1 タイトル"
    r"^\d+\.\d+\.\d+$",      # "1.1.1"
]

SENTENCE_LIKE_PAT = re.compile(
    r'(を参照|参照されたい|参照のこと|参照の上|図|表|％|%|eGFR|CrCl|BNP|NT-proBNP|Na\+|K\+|mmol|mg/dL|mEq/L|'
    r'[0-9]\s*(mL|L)\s*/\s*日|kg/日|mmHg|/kg|／日|，|．|。|\.\s*\d+|Fig\.|Table|RR|HR|OR|CI|→)'
)

QUESTION_MARK_PAT = re.compile(r'[？?]')

PSEUDO_ROOT_PAT = re.compile(r'(GL_|文献|_?\d{3,}_|心不全GL_文献)', re.I)

TRUSTED_L1 = [
    r'^第\s*1\s*章', r'^略語一覧$', r'^改訂にあたって$',
    r'^はじめに$'
]

# 全角→半角（数字・スペース・記号の一部）
ZEN2HAN_TABLE = str.maketrans({
    '０':'0','１':'1','２':'2','３':'3','４':'4','５':'5','６':'6','７':'7','８':'8','９':'9',
    '．':'.','，':',','：':':','；':';','（':'(','）':')','％':'%','＋':'+','－':'-','　':' ',
    '？':'?','！':'!','＞':'>','＜':'<','［':'[','］':']','／':'/','＊':'*','＝':'=','｜':'|',
    '‥':'.','…':'.'
})

def normalize_text(text: str) -> str:
    if not text:
        return ""
    t = text.translate(ZEN2HAN_TABLE)
    # ドット/三点リーダ 連続をドット3に寄せてから1つへ
    t = re.sub(r'\.{3,}', '...', t)
    # 空白を単一化
    t = re.sub(r'\s+', ' ', t).strip()
    return t

def is_toc_line(text: str) -> bool:
    """行末にドットリーダー＋ページ番号を持つ目次行っぽいか"""
    if re.search(r'[\.・]{2,}\s*\d+\s*$', text):
        return True
    return False

def clean_section_path(text: str) -> str:
    """目次の行末ページ番号やドットリーダー等を除去"""
    if not text:
        return ""
    t = normalize_text(text)
    t = re.sub(r'[\.・]{1,}\s*\d+\s*$', '', t)  # …… 12 / ... 12 / ・・ 12
    t = re.sub(r'\s+\d+\s*$', '', t)            # <space> 12
    t = re.sub(r'[\.・]{1,}\s*$', '', t)       # ……（末尾のみ）
    t = re.sub(r'\s+', ' ', t).strip()
    # ページ番号や目次用の孤立数字は除去
    if re.match(r'^\d+$', t):
        return ""
    return t

def detect_heading_level(text: str, strict: bool=False) -> Optional[int]:
    """見出しっぽい単一行を 1/2/3 レベル判定。本文やノイズは None"""
    if not text or len(text.strip()) < 2:
        return None
    if re.match(r'^\d+$', text.strip()):
        return None
    if is_toc_line(text):
        return None
    if re.match(r'^\d{4}\s*年\s*\d{1,2}\s*月', text):
        return None

    # strict: 番号／定形のみ通す
    if strict:
        for p in LEVEL3_PATTERNS:
            if re.match(p, text):
                return 3
        for p in LEVEL2_PATTERNS:
            if re.match(p, text) and not re.match(r'^\d+\.\d+\s+', text):
                return 2
        for p in LEVEL1_PATTERNS:
            if re.match(p, text):
                return 1
        return None

    # 通常モード
    for p in LEVEL3_PATTERNS:
        if re.match(p, text):
            return 3
    for p in LEVEL2_PATTERNS:
        if re.match(p, text) and not re.match(r'^\d+\.\d+\s+', text):
            return 2
    for p in LEVEL1_PATTERNS:
        if re.match(p, text):
            return 1
    # 緩いL1キーワードは通常モードのみ
    for kw in ["定義", "疫学", "診断", "予防", "治療", "急性", "緩和",
               "併存症", "特別な病態", "疾病管理", "地域連携", "質の評価"]:
        if text.strip() == kw or text.strip().startswith(kw + " "):
            return 1
    return None

def looks_like_sentence(title: str, strict: bool=False, level: Optional[int]=None, parent: Optional[str]=None) -> bool:
    """文章っぽい見出し（参照/単位/表/図など）を除外"""
    # L1は厳しめ：疑問符/単位/表/図/長文はNG
    if level == 1 or strict:
        if QUESTION_MARK_PAT.search(title):
            return True
        if SENTENCE_LIKE_PAT.search(title):
            return True
        if len(title) >= 40:
            return True
    else:
        if len(title) >= 40 and SENTENCE_LIKE_PAT.search(title):
            return True
        if re.search(r'^\d+(\.\d+){1,3}\s+', title) and re.search(r'(を参照|。|\.)', title):
            return True
    # 市民・患者向けのQ&AをL2で許容したい場合はここで緩和できるが、strictでは外す
    if strict and parent and "市民・患者" in parent and level in (2,3):
        # ここでは緩和しない（さらに絞る趣旨）
        pass
    return False

class PDFChapterExtractor:
    def __init__(self, pdf_path: str, debug: bool = False):
        self.pdf_path = pdf_path
        self.doc = fitz.open(pdf_path)
        self.debug = debug

    # ------- 目次ページ判定（強化） -------
    def _is_toc_like_distribution(self, page_num: int) -> bool:
        lines = [t for t, _ in self._extract_text_with_format(page_num)]
        if not lines:
            return False
        leaders = sum(1 for t in lines if re.search(r'[\.・]{2,}\s*\d+\s*$', normalize_text(t)))
        dai = sum(1 for t in lines if re.match(r'^第\s*\d+\s*章', normalize_text(t)))
        return (leaders >= 5) or (leaders >= 3 and dai >= 2)

    def _is_toc_page(self, page_num: int) -> bool:
        if page_num > 20:
            return False
        page = self.doc[page_num - 1]
        text_items = self._extract_text_with_format(page_num)
        toc_cnt = 0
        num_pat = 0
        total = 0
        for text, _ in text_items:
            t = normalize_text(text)
            if not t or len(t) < 2:
                continue
            total += 1
            if is_toc_line(t):
                toc_cnt += 1
            if re.search(r'[\.・]{1,}\s*\d+\s*$', t) or re.search(r'\s+\d+\s*$', t):
                num_pat += 1
        if total > 0:
            if (toc_cnt / total) > 0.30 or (num_pat / total) > 0.20:
                return True

        page_text = page.get_text()
        if sum(1 for k in TOC_KEYWORDS if k in page_text) >= 2:
            return True
        if self._is_toc_like_distribution(page_num):
            return True
        return False

    # ------- 行テキスト＋フォーマット抽出 -------
    def _extract_text_with_format(self, page_num: int) -> List[Tuple[str, Dict]]:
        page = self.doc[page_num - 1]
        blocks = page.get_text("dict")
        items = []
        for block in blocks.get("blocks", []):
            if "lines" not in block:
                continue
            for line in block["lines"]:
                line_text = ""
                sizes = []
                is_bold = False
                y_pos = None
                for span in line.get("spans", []):
                    txt = span.get("text", "")
                    if not txt.strip():
                        continue
                    nrm = normalize_text(txt)
                    if not nrm:
                        continue
                    line_text = (line_text + " " + nrm) if line_text else nrm
                    sizes.append(span.get("size", 0))
                    flags = span.get("flags", 0)
                    if (flags & 16) > 0:
                        is_bold = True
                    if y_pos is None:
                        bbox = span.get("bbox", [0, 0, 0, 0])
                        y_pos = bbox[1] if bbox else 0
                if line_text:
                    items.append((line_text, {
                        "font_size": max(sizes) if sizes else 0,
                        "is_bold": is_bold,
                        "y_pos": y_pos
                    }))
        return items

    # ------- TOC から抽出 -------
    def _extract_from_toc(self) -> List[Dict]:
        toc = self.doc.get_toc()
        if not toc:
            return []
        res = []
        cur_ch = None
        cur_sec = None
        for level, title, page in toc:
            title = clean_section_path(title)
            if not title:
                continue
            if level == 1:
                cur_ch = title
                sec_path = title
                cur_sec = None
            elif level == 2:
                sec_path = f"{cur_ch} > {title}" if cur_ch else title
                cur_sec = title
            else:
                if cur_ch and cur_sec:
                    sec_path = f"{cur_ch} > {cur_sec} > {title}"
                elif cur_ch:
                    sec_path = f"{cur_ch} > {title}"
                else:
                    sec_path = title
            res.append({"section_path": sec_path, "level": level,
                        "start_page": page, "end_page": None})
        # 連続項の end_page 埋め
        for i in range(len(res) - 1):
            if res[i]["end_page"] is None:
                res[i]["end_page"] = max(res[i+1]["start_page"] - 1, res[i]["start_page"])
        if res and res[-1]["end_page"] is None:
            res[-1]["end_page"] = len(self.doc)
        return res

    # ------- 本文から見出し抽出 -------
    def _extract_from_body(self,
                           min_font_size: float = 8.0,
                           max_pages: Optional[int] = None,
                           skip_toc_pages: bool = True,
                           strict: bool = False) -> List[Dict]:
        total_pages = min(len(self.doc), max_pages) if max_pages else len(self.doc)

        # 文字サイズ分布から動的しきい値（小さめに）
        sizes = []
        for p in range(1, min(total_pages + 1, 10)):
            if skip_toc_pages and self._is_toc_page(p):
                continue
            for _, fmt in self._extract_text_with_format(p):
                if fmt["font_size"] > 0:
                    sizes.append(fmt["font_size"])
        dyn = min_font_size
        if sizes:
            s = sorted(sizes)
            med = s[len(s)//2]
            dyn = max(med * 0.9, min_font_size)

        seen = set()
        cur_ch = None
        cur_sec = None
        out: List[Dict] = []

        for page_num in range(1, total_pages + 1):
            if skip_toc_pages and self._is_toc_page(page_num):
                if self.debug and page_num <= 5:
                    print(f"[DEBUG] skip TOC page {page_num}")
                continue

            text_items = self._extract_text_with_format(page_num)

            if self.debug and page_num <= 5:
                page = self.doc[page_num - 1]
                print(f"\n[DEBUG] page={page_num} H={page.rect.height:.1f}")
                for idx, (t, fmt) in enumerate(text_items[:20]):
                    ph = page.rect.height or 1
                    ry = (fmt["y_pos"] / ph) * 100
                    print(f"  [{idx+1}] {fmt['font_size']:.1f}pt bold={fmt['is_bold']} y={ry:.1f}% :: {t[:80]}")

            for text, fmt in text_items:
                t_clean = clean_section_path(text)
                if not t_clean:
                    continue

                level = detect_heading_level(t_clean, strict=strict)
                if not level:
                    continue

                # 上部位置制約：L1は上位30%、L2/L3は上位50%
                page_h = self.doc[page_num - 1].rect.height or 1.0
                ry = (fmt["y_pos"] / page_h)
                if (level == 1 and ry > 0.30) or (level in (2, 3) and ry > 0.50):
                    continue

                # フォント/太字しきい値
                if fmt["font_size"] < 7:
                    continue
                if not fmt["is_bold"] and fmt["font_size"] < max(9, dyn):
                    continue

                parent = cur_ch if level in (2,3) else None
                if looks_like_sentence(t_clean, strict=strict, level=level, parent=parent):
                    continue

                # 同ページ・同テキストの重複除外
                key = (page_num, t_clean[:160])
                if key in seen:
                    continue
                seen.add(key)

                # パス構築
                if level == 1:
                    cur_ch = t_clean
                    cur_sec = None
                    sec_path = t_clean
                elif level == 2:
                    sec_path = f"{cur_ch} > {t_clean}" if cur_ch else t_clean
                    cur_sec = t_clean
                else:
                    if cur_ch and cur_sec:
                        sec_path = f"{cur_ch} > {cur_sec} > {t_clean}"
                    elif cur_ch:
                        sec_path = f"{cur_ch} > {t_clean}"
                    else:
                        sec_path = t_clean

                out.append({"section_path": sec_path, "level": level,
                            "start_page": page_num, "end_page": None})

        # 粗い end_page 補完
        out.sort(key=lambda x: (x["start_page"], x["level"]))
        for i in range(len(out) - 1):
            if out[i]["end_page"] is None:
                out[i]["end_page"] = max(out[i+1]["start_page"] - 1, out[i]["start_page"])
        if out and out[-1]["end_page"] is None:
            out[-1]["end_page"] = total_pages
        return out

    # ------- end_page を階層一貫性で補完 -------
    @staticmethod
    def _hierarchical_endpage_fix(items: List[Dict], total_pages: int) -> List[Dict]:
        items = sorted(items, key=lambda x: (x["start_page"], x["level"]))
        stack: List[Tuple[int, int]] = []
        for i, it in enumerate(items):
            while stack and stack[-1][0] >= it["level"]:
                _, idx = stack.pop()
                if items[idx]["end_page"] is None:
                    items[idx]["end_page"] = max(it["start_page"] - 1, items[idx]["start_page"])
            stack.append((it["level"], i))

        while stack:
            _, idx = stack.pop()
            if items[idx]["end_page"] is None:
                items[idx]["end_page"] = max(total_pages, items[idx]["start_page"])

        for it in items:
            if it["end_page"] < it["start_page"]:
                it["end_page"] = it["start_page"]
        return items

    # ------- post cleanup -------
    def _post_cleanup(self, items: List[Dict]) -> List[Dict]:
        total = len(self.doc)
        out = []
        for it in items:
            title = it["section_path"]
            # 過大なルート（PDFの80%以上）または疑似ルート名を除外
            if it["level"] == 1 and it["end_page"] is not None:
                span = it["end_page"] - it["start_page"] + 1
                if span >= int(total * 0.80) and (PSEUDO_ROOT_PAT.search(title) or len(title) <= 6):
                    continue
            # L1の表・図・単位混在は除外
            if it["level"] == 1 and (SENTENCE_LIKE_PAT.search(title) or QUESTION_MARK_PAT.search(title)):
                continue
            out.append(it)
        return out

    # ------- 信頼できるL1より前を削除 -------
    @staticmethod
    def _first_reliable_l1_page(items: List[Dict]) -> int:
        for it in sorted(items, key=lambda x: (x["start_page"], x["level"])):
            if it["level"] == 1 and any(re.match(p, it["section_path"]) for p in TRUSTED_L1):
                return it["start_page"]
        return 1

    @staticmethod
    def _cut_before(items: List[Dict], min_page: int) -> List[Dict]:
        return [it for it in items if it["start_page"] >= min_page]

    # ------- gold差分（簡易） -------
    @staticmethod
    def _gold_diff(gold_path: str, pred_items: List[Dict]) -> str:
        try:
            gold = json.loads(Path(gold_path).read_text(encoding="utf-8"))
            gold_items = gold.get("toc", [])
        except Exception as e:
            return f"[gold diff] gold読み込み失敗: {e}"

        # L1のみ比較（タイトルと開始ページ）
        gL1 = [(x["section_path"], x["start_page"], x["end_page"]) for x in gold_items if x.get("level")==1]
        pL1 = [(x["section_path"], x["start_page"], x["end_page"]) for x in pred_items if x.get("level")==1]

        def norm_title(t): return normalize_text(t)

        gmap = {norm_title(t): (s,e) for t,s,e in gL1}
        pmap = {norm_title(t): (s,e) for t,s,e in pL1}

        missing = [t for t in gmap.keys() if t not in pmap]
        extra   = [t for t in pmap.keys() if t not in gmap]
        shifted = []
        for t in gmap.keys() & pmap.keys():
            gs, ge = gmap[t]
            ps, pe = pmap[t]
            if gs != ps or ge != pe:
                shifted.append((t, (gs,ge), (ps,pe)))

        lines = []
        lines.append(f"[gold diff] L1 gold={len(gL1)} pred={len(pL1)}")
        if missing:
            lines.append(f"  - missing ({len(missing)}): " + ", ".join(list(missing)[:5]) + (" ..." if len(missing)>5 else ""))
        if extra:
            lines.append(f"  - extra   ({len(extra)}): " + ", ".join(list(extra)[:5]) + (" ..." if len(extra)>5 else ""))
        if shifted:
            ex = "; ".join([f"{t} gold{gs}-{ge}/pred{ps}-{pe}" for t,(gs,ge),(ps,pe) in shifted[:5]])
            lines.append(f"  - shifted ({len(shifted)}): {ex}" + (" ..." if len(shifted)>5 else ""))
        if not (missing or extra or shifted):
            lines.append("  ✓ 完全一致（L1）")
        return "\n".join(lines)

    # ------- 生成メイン -------
    def generate_chapter_json(self,
                              doc_id: str,
                              version: str = "v1.0",
                              toc_only: bool = False,
                              min_font_size: float = 8.0,
                              max_pages: Optional[int] = None,
                              skip_toc_pages: bool = True,
                              strict: bool = False,
                              output_path: Optional[str] = None,
                              gold_path: Optional[str] = None) -> Dict:
        # 1) TOCから取得
        headings = self._extract_from_toc()

        # 2) 必要に応じて本文解析を併用
        if not toc_only and (not headings or len(headings) < 3):
            if headings:
                print(f"TOCは{len(headings)}件。本文解析も併用します…")
            else:
                print("TOCが見つからず。本文解析で抽出します…")
            body = self._extract_from_body(min_font_size=min_font_size,
                                           max_pages=max_pages,
                                           skip_toc_pages=skip_toc_pages,
                                           strict=strict)
            page_set = {h["start_page"] for h in headings}
            for h in body:
                if h["start_page"] not in page_set:
                    headings.append(h)
            headings.sort(key=lambda x: (x["start_page"], x["level"]))

        # 3) 階層一貫性で end_page を最終補完
        total_pages = min(len(self.doc), max_pages) if max_pages else len(self.doc)
        headings = self._hierarchical_endpage_fix(headings, total_pages)

        # 4) 追加クリーンアップ
        headings = self._post_cleanup(headings)
        minp = self._first_reliable_l1_page(headings)
        headings = self._cut_before(headings, minp)

        result = {"doc_id": doc_id, "version": version, "toc": headings}

        # 5) gold差分
        if gold_path:
            print(self._gold_diff(gold_path, headings))

        if output_path:
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            print(f"出力: {output_path}")
        return result

    def close(self):
        if self.doc:
            self.doc.close()


def main():
    ap = argparse.ArgumentParser(description="PDFから章情報を抽出し chapter.json を生成（絞り込み強化版）")
    ap.add_argument("pdf", help="入力PDFパス")
    ap.add_argument("out", nargs="?", help="出力JSONパス（省略可）")
    ap.add_argument("--doc-id", default=None)
    ap.add_argument("--version", default="v1.0")
    ap.add_argument("--toc-only", action="store_true", help="TOCのみで抽出")
    ap.add_argument("--no-skip-toc", action="store_true", help="本文解析時も目次ページをスキップしない")
    ap.add_argument("--strict", action="store_true", help="見出し判定を厳格化（番号/定形のみ許容）")
    ap.add_argument("--min-font", type=float, default=8.0, help="本文解析の最小フォントサイズ下限")
    ap.add_argument("--max-pages", type=int, default=None, help="先頭からの走査ページ上限（速度検証用）")
    ap.add_argument("--gold", type=str, default=None, help="gold chapter.json へのパス（差分レポート）")
    ap.add_argument("--debug", action="store_true")
    args = ap.parse_args()

    pdf_path = Path(args.pdf)
    if not pdf_path.exists():
        print(f"PDFが見つかりません: {pdf_path}")
        sys.exit(1)

    out_path = args.out or str(pdf_path.with_name(f"{pdf_path.stem}_chapter.json"))
    doc_id = args.doc_id or pdf_path.stem

    ex = PDFChapterExtractor(str(pdf_path), debug=args.debug)
    try:
        ex.generate_chapter_json(
            doc_id=doc_id,
            version=args.version,
            toc_only=args.toc_only,
            min_font_size=args.min_font,
            max_pages=args.max_pages,
            skip_toc_pages=not args.no_skip_toc,
            strict=args.strict,
            output_path=out_path,
            gold_path=args.gold
        )
    finally:
        ex.close()


if __name__ == "__main__":
    main()

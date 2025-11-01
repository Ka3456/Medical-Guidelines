#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PDFから目次を抽出してJSON形式で出力
"""

import re
import json
from pathlib import Path
from datetime import datetime

# 目次ヘッダーのパターン
RE_TOC_HEADER = re.compile(r'^\s*(目次|もくじ|CONTENTS?)\s*$', re.IGNORECASE)

# ドットリーダのパターン（...、・・・、……、‥‥など）
# . = 半角ドット, 。 = 全角句点, ・ = 中点, … = 三点リーダー, ‥ = 二点リーダー
RE_DOT_LEADER = re.compile(r'\.{2,}|。{2,}|・{2,}|…{1,}|‥{2,}')

# ページ番号のパターン（行末の数字、p211、211pなどの形式も対応）
RE_PAGE_NUM = re.compile(r'[pP]?\s*(\d+)\s*[pP]?\s*$')

# ドットリーダーの後のページ番号パターン（「‥‥‥ 101」「... 98」などに対応）
# ドットリーダーの後にスペース（全角・半角、1文字以上）と数字が続く
# \s+ = 半角スペース, \u3000+ = 全角スペース
RE_PAGE_NUM_AFTER_DOT = re.compile(r'(?:\.{2,}|。{2,}|・{2,}|…{1,}|‥{2,})[\s\u3000]+(\d+)')

# 行頭の印刷ページ番号のパターン（目次ページに印刷されているページ番号、例："100 "）
# 行頭の2-4桁の数字とその後のスペースを削除（セクション番号"3.2"はピリオドがあるので保護される）
RE_LEADING_PAGE_NUM = re.compile(r'^\s*\d{2,4}\s+')

def find_toc_string(lines_with_page: list[tuple[int, str]]):
    """
    目次という文字列を見つける
    returns: (見つかったページ番号, 見つかった行の位置（何番目か、0から始まる）, 見つかった行のテキスト) or None
    """
    # 目次を見つける
    idx = -1
    for i, (page, line) in enumerate(lines_with_page):
        if RE_TOC_HEADER.match(line):
            idx = i  # idx = index（インデックス）の略。リストの中での位置（何番目か、0から始まる）
            
            # 目次の後ろにある行のうち、ドットリーダを含む行だけを取得
            # 2行に分かれている場合（前の行と結合）に対応
            start = idx + 1
            end = len(lines_with_page)  # すべての行を処理
            dot_lines = []
            # processed_indices: 処理済み行のインデックスを記録するset（集合）
            # 目的: 2行に分かれている目次項目を結合する際、前の行を二重に処理しないようにする
            # 例:
            #   [j-1]: "1. はじめに"          <- この行のインデックスを記録
            #   [j]:   "... ... ... 10"        <- ドットリーダーとページ番号あり
            #   → 結合して "1. はじめに ... ... ... 10" として追加
            #   → j-1 を processed_indices に追加
            #   → 次に j-1 の行がループで処理される際、スキップされる
            processed_indices = set()  # 処理済み行を記録
            
            for j in range(start, end):
                # processed_indices チェックの詳細説明:
                # - j が processed_indices に含まれている = 既に前の行として結合処理された行
                # - 例: 行[j-1] が行[j] と結合された場合、行[j-1] のインデックスが記録される
                # - 次回ループで j-1 を処理する際、既に結合済みなのでスキップする
                # - これにより、同じ行が二重に dot_lines に追加されるのを防ぐ
                if j in processed_indices:
                    continue  # 既に処理済み（前の行として結合された）場合はスキップ
                
                p, l = lines_with_page[j]
                
                # ========== 最終的に追加されるための条件 ==========
                # 条件1: 処理済みでない（既にチェック済み）
                cond1_processed = j not in processed_indices
                
                # 条件2: ドットリーダーが含まれる
                has_dot_leader = RE_DOT_LEADER.search(l)
                cond2_has_dot_leader = bool(has_dot_leader)
                
                # 条件3: ページ番号が含まれる
                # 行末のページ番号（p211、211pなど）またはドットリーダーの後のページ番号（‥‥‥ 101など）
                page_match_end = RE_PAGE_NUM.search(l)
                page_match_after_dot = RE_PAGE_NUM_AFTER_DOT.search(l)
                has_page_num = bool(page_match_end) or bool(page_match_after_dot)
                cond3_has_page_num = has_page_num
                
                # 全条件を満たすかチェック
                # パターンA: ドットリーダーあり + ページ番号あり（通常のケース）
                # パターンB: ドットリーダーなし + ページ番号あり + 前の行がドットリーダーあり（2行に分かれているケース）
                pattern_a = cond1_processed and cond2_has_dot_leader and cond3_has_page_num
                
                # パターンBのチェック: 前の行がドットリーダーを含んでいるか確認
                pattern_b = False
                if cond1_processed and not cond2_has_dot_leader and cond3_has_page_num and j > start:
                    prev_p, prev_l = lines_with_page[j - 1]
                    prev_has_dot = RE_DOT_LEADER.search(prev_l)
                    prev_no_page = not (RE_PAGE_NUM.search(prev_l) or RE_PAGE_NUM_AFTER_DOT.search(prev_l))
                    pattern_b = bool(prev_has_dot) and prev_no_page
                
                all_basic_conditions = pattern_a or pattern_b
                
                if not all_basic_conditions:
                    continue
                
                if True:  # 全基本条件を満たした場合
                    # 直前の行をチェック（2行に分かれている場合に対応）
                    combined_line = l
                    combined_page = p
                    
                    if j > start:  # 前の行がある場合
                        prev_p, prev_l = lines_with_page[j - 1]
                        
                        # パターンBの場合（現在の行はページ番号のみ、前の行はドットリーダーあり）は強制的に結合
                        if pattern_b:
                            combined_line = f"{prev_l.strip()} {l.strip()}"
                            combined_page = prev_p
                            processed_indices.add(j - 1)
                        else:
                            # ========== 行結合されるための条件（パターンA用） ==========
                            # 条件1: 前の行がドットリーダーを含まない
                            prev_has_dot = RE_DOT_LEADER.search(prev_l)
                            cond_join1_no_dot = not prev_has_dot
                            
                            # 条件2: 前の行がページ番号だけではない
                            prev_is_page_only = RE_PAGE_NUM.match(prev_l.strip())
                            cond_join2_not_page_only = not prev_is_page_only
                            
                            # 条件3: 前の行が空行ではない
                            prev_not_empty = bool(prev_l.strip())
                            cond_join3_not_empty = prev_not_empty
                            
                            # 条件4: 前の行がページ近接している（prev_p <= p and p - prev_p <= 2）
                            prev_page_ok = prev_p <= p and p - prev_p <= 2
                            cond_join4_page_ok = prev_page_ok
                            
                            # 全条件を満たすかチェック
                            all_join_conditions = (cond_join1_no_dot and 
                                                  cond_join2_not_page_only and 
                                                  cond_join3_not_empty and 
                                                  cond_join4_page_ok)
                            
                            if all_join_conditions:
                                # 前の行と結合
                                combined_line = f"{prev_l.strip()} {l.strip()}"
                                combined_page = prev_p
                                # processed_indices.add(j - 1) の意味:
                                # - 行[j-1] を 行[j] と結合したため、行[j-1] は単独では処理しない
                                # - j-1 を processed_indices に追加することで、次回ループで j-1 が処理される際にスキップされる
                                # - これにより、結合された行が二重に dot_lines に追加されることを防ぐ
                                processed_indices.add(j - 1)  # 前の行も処理済みにする
                    
                    dot_lines.append((j, combined_page, combined_line))
            
            if dot_lines:
                # JSON形式に変換（section_path、start_page、end_page）
                json_items = []
                for j, p, l in dot_lines:
                    # ページ番号を抽出（行末のページ番号またはドットリーダーの後のページ番号）
                    page_match = RE_PAGE_NUM_AFTER_DOT.search(l) or RE_PAGE_NUM.search(l)
                    if page_match:
                        page_num = int(page_match.group(1))
                        # タイトル部分を抽出（ドットリーダーとページ番号を除く）
                        title = l
                        # ドットリーダーの後のページ番号を削除（「‥‥‥ 101」→「‥‥‥」部分だけ残る→後でドットリーダーも削除）
                        title = RE_PAGE_NUM_AFTER_DOT.sub('', title).strip()
                        # 行末のページ番号を削除
                        title = RE_PAGE_NUM.sub('', title).strip()
                        # ドットリーダーを削除
                        title = RE_DOT_LEADER.sub('', title).strip()
                        # 行頭の印刷ページ番号を削除（目次ページに印刷されているページ番号、例："100 "）
                        title = RE_LEADING_PAGE_NUM.sub('', title).strip()
                        
                        json_item = {
                            "section_path": title,
                            "start_page": page_num,
                            "end_page": page_num  # 最初は同じページ、後で次の項目のstart_page-1に更新
                        }
                        json_items.append(json_item)
                        
                        
                
                # end_pageを更新（次の項目のstart_page - 1）
                for i in range(len(json_items) - 1):
                    next_start = json_items[i + 1]["start_page"] - 1
                    # end_pageがstart_pageより小さくなった場合は、start_pageと同じにする
                    if next_start < json_items[i]["start_page"]:
                        json_items[i]["end_page"] = json_items[i]["start_page"]
                    else:
                        json_items[i]["end_page"] = next_start
                
                return (page, idx, line, json_items)
            else:
                return (page, idx, line, [])
    
    return (None, None, None, [])

def main():
    # テスト用: PDFからテキスト抽出（簡単版）
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf", type=Path)
    ap.add_argument("-o", "--out", type=Path, default=None, help="出力JSONファイルパス")
    args = ap.parse_args()
    
    pdf_path = args.pdf
    out_json = args.out or pdf_path.with_name(pdf_path.stem + "_chapter.json")
    
    # PyMuPDFで読み込み
    try:
        import fitz
        lines = []
        with fitz.open(pdf_path) as doc:
            for i, p in enumerate(doc, start=1):
                text = p.get_text("text") or ""
                for ln in text.splitlines():
                    t = ln.strip()
                    if t:
                        lines.append((i, t))
      
    except Exception as e:
        print(f"[error] PDF読み込み失敗: {e}")
        return
    
    # 目次検出
    result = find_toc_string(lines)
    if result and result[0] is not None:
        page, idx, line, json_items = result
   
        if json_items:
            # メタデータを含むJSONオブジェクトを作成
            output_data = {
                "pdf_filename": pdf_path.name,
                "created_at": datetime.now().isoformat(),
                "toc": json_items
            }
            
            # JSONファイルに保存
            out_json.write_text(
                json.dumps(output_data, ensure_ascii=False, indent=2),
                encoding="utf-8"
            )

if __name__ == "__main__":
    main()

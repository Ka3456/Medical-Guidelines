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

# ページ番号のパターン（行末の数字）
RE_PAGE_NUM = re.compile(r'\s+(\d{1,4})\s*$')

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
            print(f"[debug] ★ 目次を見つけました！")
            print(f"  - インデックス: {idx}")
            print(f"  - ページ: {page}")
            print(f"  - 行内容: {line}")
            
            # 目次の後ろにある行のうち、ドットリーダを含む行だけを取得
            # 2行に分かれている場合（前の行と結合）に対応
            start = idx + 1
            end = min(len(lines_with_page), idx + 200)  # 目次の後ろ200行まで探す
            dot_lines = []
            processed_indices = set()  # 処理済み行を記録
            
            for j in range(start, end):
                if j in processed_indices:
                    continue  # 既に処理済み（前の行として結合された）場合はスキップ
                
                p, l = lines_with_page[j]
                
                # ドットリーダーとページ番号を含む行かチェック
                if RE_DOT_LEADER.search(l) and RE_PAGE_NUM.search(l):
                    # 直前の行をチェック（2行に分かれている場合に対応）
                    combined_line = l
                    combined_page = p
                    
                    if j > start:  # 前の行がある場合
                        prev_p, prev_l = lines_with_page[j - 1]
                        # 前の行が結合候補かチェック
                        # - ドットリーダーを含まない
                        # - ページ番号だけでない
                        # - 同じページまたは次のページ（近接している）
                        if (not RE_DOT_LEADER.search(prev_l) and 
                            not RE_PAGE_NUM.match(prev_l.strip()) and
                            prev_l.strip() and
                            prev_p <= p and p - prev_p <= 1):
                            # 前の行と結合
                            combined_line = f"{prev_l.strip()} {l.strip()}"
                            combined_page = prev_p
                            processed_indices.add(j - 1)  # 前の行も処理済みにする
                            print(f"[debug] 行結合: [{j-1}] + [{j}]")
                    
                    dot_lines.append((j, combined_page, combined_line))
            
            print(f"[debug] ドットリーダを含む行: {len(dot_lines)}行")
            
            if dot_lines:
                # JSON形式に変換（section_path、start_page、end_page）
                json_items = []
                for j, p, l in dot_lines:
                    # 行末のページ番号を抽出
                    page_match = RE_PAGE_NUM.search(l)
                    if page_match:
                        page_num = int(page_match.group(1))
                        # タイトル部分を抽出（ドットリーダーとページ番号を除く）
                        title = RE_PAGE_NUM.sub('', l).strip()  # ページ番号を削除
                        title = RE_DOT_LEADER.sub('', title).strip()  # ドットリーダーを削除
                        
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
                
                print(f"[debug] JSON項目数: {len(json_items)}")
                return (page, idx, line, json_items)
            else:
                print("[debug] ドットリーダを含む行が見つかりませんでした")
                return (page, idx, line, [])
    
    print("[debug] ✗ 目次が見つかりませんでした")
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
    
    print(f"[debug] PDFファイル: {pdf_path}")
    print(f"[debug] 出力JSON: {out_json}")
    
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
        print(f"[debug] PDF読み込み成功: {len(lines)}行")
      
    except Exception as e:
        print(f"[error] PDF読み込み失敗: {e}")
        return
    
    # 目次検出
    result = find_toc_string(lines)
    if result and result[0] is not None:
        page, idx, line, json_items = result
        print(f"[debug] 目次検出完了: {len(json_items) if json_items else 0}項目")
   
        if json_items:
            # メタデータを含むJSONオブジェクトを作成
            output_data = {
                "pdf_filename": pdf_path.name,
                "created_at": datetime.now().isoformat(),
                "toc": json_items
            }
            
            print(f"[debug] JSONデータ作成完了")
            print(f"  - pdf_filename: {output_data['pdf_filename']}")
            print(f"  - created_at: {output_data['created_at']}")
            print(f"  - toc項目数: {len(output_data['toc'])}")
            print(f"\n[debug] 抽出された項目（具体的な名前）:")
            for i, item in enumerate(output_data['toc'], 1):
                print(f"  [{i:2d}] {item['section_path'][:60]:60s} (p{item['start_page']:3d}-{item['end_page']:3d})")
            
            # JSONファイルに保存
            out_json.write_text(
                json.dumps(output_data, ensure_ascii=False, indent=2),
                encoding="utf-8"
            )
            print(f"[debug] JSONファイル保存完了: {out_json}")
        else:
            print("[debug] JSON項目がありません")
    else:
        print("[debug] 目次が見つかりませんでした")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pdf/フォルダ内のすべてのPDFを処理してchapter/フォルダに保存
"""

import json
from pathlib import Path
from datetime import datetime
import fitz  # PyMuPDF

# robus_getchaper.pyから関数をインポート
from robus_getchaper import find_toc_string

# パスの設定
BASE_DIR = Path(__file__).parent
PDF_DIR = BASE_DIR.parent.parent / "pdf"
CHAPTER_DIR = BASE_DIR / "chapter"

def process_pdf(pdf_path: Path) -> None:
    """
    単一のPDFファイルを処理してchapter JSONを生成・保存
    """
    print(f"処理中: {pdf_path.name}")
    
    # PDFからテキストを抽出
    try:
        lines = []
        with fitz.open(pdf_path) as doc:
            for i, p in enumerate(doc, start=1):
                text = p.get_text("text") or ""
                for ln in text.splitlines():
                    t = ln.strip()
                    if t:
                        lines.append((i, t))
    except Exception as e:
        print(f"  [エラー] PDF読み込み失敗: {e}")
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
            
            # 出力ファイルパス
            output_filename = pdf_path.stem + "_chapter.json"
            output_path = CHAPTER_DIR / output_filename
            
            # JSONファイルに保存
            output_path.write_text(
                json.dumps(output_data, ensure_ascii=False, indent=2),
                encoding="utf-8"
            )
            print(f"  [OK] 保存完了: {output_path}")
        else:
            print(f"  [警告] 目次が見つかりませんでした")
    else:
        print(f"  [警告] 目次が見つかりませんでした")


def main():
    """
    メイン処理: pdf/フォルダ内のすべてのPDFを処理
    """
    # chapterディレクトリを作成（存在しない場合）
    CHAPTER_DIR.mkdir(parents=True, exist_ok=True)
    
    # pdfディレクトリが存在しない場合
    if not PDF_DIR.exists():
        print(f"[エラー] PDFディレクトリが見つかりません: {PDF_DIR}")
        return
    
    # pdfディレクトリ内のすべてのPDFファイルを取得
    pdf_files = list(PDF_DIR.glob("*.pdf"))
    
    if not pdf_files:
        print(f"[警告] PDFファイルが見つかりません: {PDF_DIR}")
        return
    
    print(f"見つかったPDFファイル数: {len(pdf_files)}")
    print(f"出力先: {CHAPTER_DIR}")
    print("-" * 60)
    
    # 各PDFを処理
    for pdf_path in pdf_files:
        process_pdf(pdf_path)
    
    print("-" * 60)
    print("処理完了")


if __name__ == "__main__":
    main()


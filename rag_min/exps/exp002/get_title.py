#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PDFからタイトルを抽出して表示するスクリプト
PDFフォルダ内のすべてのPDFを処理してJSONファイルを作成することも可能
"""

import sys
import argparse
import json
from pathlib import Path
from datetime import datetime
import fitz  # PyMuPDF

# パスの設定
BASE_DIR = Path(__file__).parent
PDF_DIR = BASE_DIR.parent.parent / "pdf"


def get_title_from_pdf(pdf_path: Path) -> str:
    """
    PDFからタイトルを抽出
    
    Args:
        pdf_path: PDFファイルのパス
        
    Returns:
        抽出されたタイトル文字列
    """
    try:
        with fitz.open(pdf_path) as doc:
            # まずメタデータからタイトルを取得
            metadata = doc.metadata
            if metadata.get("title") and metadata["title"].strip():
                title = metadata["title"].strip()
                if len(title) >= 5:
                    return title
            
            # メタデータにタイトルがない場合、最初のページから抽出
            if len(doc) > 0:
                first_page = doc[0]
                
                # フォントサイズ情報を使って候補を収集
                candidates = []  # (font_size, text) のリスト
                blocks = first_page.get_text("dict")["blocks"]
                
                for block in blocks:
                    if "lines" in block:
                        for line in block["lines"]:
                            for span in line["spans"]:
                                font_size = span.get("size", 0)
                                text_content = span.get("text", "").strip()
                                # 数字だけの行や、短すぎる行をスキップ
                                if text_content and len(text_content) >= 5:
                                    # 数字だけの行をスキップ（例: "1", "2025"など）
                                    if not text_content.replace(" ", "").replace("　", "").isdigit():
                                        candidates.append((font_size, text_content))
                
                # フォントサイズが大きい順にソート
                candidates.sort(key=lambda x: x[0], reverse=True)
                
                # 最初の候補（最大フォントサイズ）を返す
                if candidates:
                    return candidates[0][1]
                
                # フォントサイズ情報が使えない場合、テキスト行から探す
                text = first_page.get_text("text")
                if text:
                    lines = [line.strip() for line in text.splitlines() if line.strip()]
                    # 5文字以上の行を探す
                    for line in lines:
                        if len(line) >= 5:
                            # 数字だけの行をスキップ
                            if not line.replace(" ", "").replace("　", "").isdigit():
                                return line
                    # 5文字以上の行がない場合、最初の行を返す
                    if lines:
                        return lines[0]
            
            return "タイトルが見つかりませんでした"
            
    except Exception as e:
        return f"エラー: {e}"


def process_all_pdfs_to_json():
    """
    pdf/フォルダ内のすべてのPDFを処理して、ファイル名とタイトルのペアをJSONに保存
    """
    # PDFディレクトリが存在しない場合
    if not PDF_DIR.exists():
        print(f"[エラー] PDFディレクトリが見つかりません: {PDF_DIR}", file=sys.stderr)
        sys.exit(1)
    
    # pdfディレクトリ内のすべてのPDFファイルを取得
    pdf_files = sorted(PDF_DIR.glob("*.pdf"))
    
    if not pdf_files:
        print(f"[警告] PDFファイルが見つかりません: {PDF_DIR}", file=sys.stderr)
        sys.exit(1)
    
    print(f"見つかったPDFファイル数: {len(pdf_files)}")
    print("-" * 60)
    
    # 結果を格納するリスト
    results = []
    
    # 各PDFを処理
    for pdf_path in pdf_files:
        print(f"処理中: {pdf_path.name}")
        title = get_title_from_pdf(pdf_path)
        results.append({
            "name": pdf_path.name,
            "title": title
        })
        print(f"  タイトル: {title}")
    
    # JSONファイルに保存
    output_path = BASE_DIR / "junkanki_title.json"
    output_data = {
        "created_at": datetime.now().isoformat(),
        "pdf_dir": str(PDF_DIR),
        "pdfs": results
    }
    
    output_path.write_text(
        json.dumps(output_data, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    
    print("-" * 60)
    print(f"処理完了: {len(results)}件のPDFを処理しました")
    print(f"出力先: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="PDFからタイトルを抽出して表示、またはpdf/フォルダ内のすべてのPDFを処理してJSONを作成",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
例:
  # 単一のPDFのタイトルを表示
  python get_title.py path/to/file.pdf
  
  # pdf/フォルダ内のすべてのPDFを処理してJSONを作成
  python get_title.py --all
        """
    )
    parser.add_argument("pdf", type=Path, nargs="?", help="PDFファイルのパス（--all指定時は不要）")
    parser.add_argument("--all", action="store_true", help="pdf/フォルダ内のすべてのPDFを処理してJSONを作成")
    args = parser.parse_args()
    
    # --allオプションが指定された場合
    if args.all:
        process_all_pdfs_to_json()
        return
    
    # 単一のPDFファイルを処理
    if not args.pdf:
        parser.print_help()
        sys.exit(1)
    
    pdf_path = args.pdf
    
    if not pdf_path.exists():
        print(f"エラー: ファイルが見つかりません: {pdf_path}", file=sys.stderr)
        sys.exit(1)
    
    title = get_title_from_pdf(pdf_path)
    print(title)


if __name__ == "__main__":
    main()


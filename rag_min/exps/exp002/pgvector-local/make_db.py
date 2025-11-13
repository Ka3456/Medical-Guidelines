#!/usr/bin/env python3
"""
pdf/配下のPDFとchapter/配下の章JSONを突き合わせて、ペアリング状況をログ出力するスクリプト。

想定ディレクトリ構成：
  rag_min/
    ├── pdf/                … PDF原本（JCSxxxx_*.pdf）
    └── exps/exp002/
          ├── chapter/      … 章情報JSON（*_chapter.json）
          └── pgvector-local/make_db.py  ← 本スクリプト
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple


def log_info(message: str, verbose: bool) -> None:
    if verbose:
        print(message)


def log_warn(message: str, verbose: bool) -> None:
    if verbose:
        print(message)


def log_error(message: str) -> None:
    print(message, file=sys.stderr)


def resolve_default_paths() -> Tuple[Path, Path]:
    """
    スクリプトの配置場所から既定の pdf / chapter ディレクトリを導出する。
    - pdf : rag_min/pdf
    - chapter : rag_min/exps/exp002/chapter
    """
    script_dir = Path(__file__).resolve().parent
    exp002_dir = script_dir.parent
    rag_min_root = script_dir.parents[2]
    pdf_dir = rag_min_root / "pdf"
    chapter_dir = exp002_dir / "chapter"
    return pdf_dir, chapter_dir


def load_chapter_index(chapter_dir: Path, verbose: bool) -> Dict[str, Path]:
    """
    chapterディレクトリ内のJSONを読み込み、`pdf_filename` をキーにPathを引ける辞書を返す。
    JSONが不正/`pdf_filename`欠如の場合はスキップして警告する。
    """
    index: Dict[str, Path] = {}

    for json_path in sorted(chapter_dir.glob("*.json")):
        try:
            with json_path.open("r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as exc:  # JSONDecodeError含む
            log_error(f"[ERROR] JSON読込失敗: {json_path.name} ({exc})")
            continue

        pdf_name = data.get("pdf_filename")
        if not pdf_name:
            # fallback: ファイル名の"_chapter"除去で推測
            stem = json_path.stem
            if stem.endswith("_chapter"):
                pdf_name = f"{stem[:-8]}.pdf"
                log_warn(
                    f"[WARN] `pdf_filename`欠如のため推測: "
                    f"{json_path.name} -> {pdf_name}",
                    verbose,
                )
            else:
                log_warn(
                    f"[WARN] `pdf_filename`取得不可のためスキップ: {json_path.name}",
                    verbose,
                )
                continue

        if pdf_name in index:
            log_warn(
                f"[WARN] 同一pdf_filenameに複数のJSONが存在: "
                f"{pdf_name} -> {index[pdf_name].name}, {json_path.name}",
                verbose,
            )
        # 最新のものを優先（後勝ち）
        index[pdf_name] = json_path

    return index


def pair_pdfs_and_chapters(
    pdf_files: List[Path], chapter_index: Dict[str, Path]
) -> Tuple[List[Tuple[Path, Path]], List[Path], List[Path]]:
    """
    PDF ↔ chapter JSON の突き合わせ。
    戻り値: (ペアリスト, 未マッチPDF, 未マッチJSON)
    """
    pairs: List[Tuple[Path, Path]] = []
    matched_json_paths: set[Path] = set()

    for pdf_path in pdf_files:
        chapter_path = chapter_index.get(pdf_path.name)
        if chapter_path:
            pairs.append((pdf_path, chapter_path))
            matched_json_paths.add(chapter_path)
        else:
            # stemベースでも一応検索（念のため）
            alt = f"{pdf_path.stem}_chapter.json"
            for candidate_pdf_name, jp in chapter_index.items():
                if jp.name == alt:
                    pairs.append((pdf_path, jp))
                    matched_json_paths.add(jp)
                    break

    unmatched_pdfs = [
        pdf
        for pdf in pdf_files
        if not any(pair[0] == pdf for pair in pairs)
    ]
    unmatched_jsons = [
        json_path
        for json_path in chapter_index.values()
        if json_path not in matched_json_paths
    ]

    return pairs, unmatched_pdfs, unmatched_jsons


def run_command(cmd: List[str], verbose: bool) -> bool:
    log_info(f"[CMD] {' '.join(cmd)}", verbose)
    try:
        subprocess.run(cmd, check=True)
        return True
    except subprocess.CalledProcessError as exc:
        log_error(f"[ERROR] コマンド失敗 (returncode={exc.returncode}): {' '.join(cmd)}")
        return False


def run_pipeline_for_pair(
    pdf_path: Path,
    chapter_path: Path,
    doc_id: str,
    version: str,
    scripts_dir: Path,
    verbose: bool,
) -> Tuple[bool, bool]:
    rag_script = scripts_dir / "rag_build_db.py"
    embed_script = scripts_dir / "embed_chunks_openai.py"

    if not rag_script.exists():
        log_error(f"[ERROR] rag_build_db.py が見つかりません: {rag_script}")
        return False, False
    if not embed_script.exists():
        log_error(f"[ERROR] embed_chunks_openai.py が見つかりません: {embed_script}")
        return False, False

    rag_cmd = [
        sys.executable,
        str(rag_script),
        "--pdf",
        str(pdf_path),
        "--chapter-json",
        str(chapter_path),
        "--doc-id",
        doc_id,
        "--version",
        version,
    ]
    rag_ok = run_command(rag_cmd, verbose)

    embed_ok = False
    if rag_ok:
        embed_cmd = [
            sys.executable,
            str(embed_script),
            "--doc-id",
            doc_id,
            "--version",
            version,
        ]
        embed_ok = run_command(embed_cmd, verbose)

    return rag_ok, embed_ok


def main() -> None:
    default_pdf_dir, default_chapter_dir = resolve_default_paths()

    parser = argparse.ArgumentParser(
        description="pdf/ と chapter/ を突き合わせてペアリング状況を確認します。"
    )
    parser.add_argument(
        "--pdf-dir",
        default=str(default_pdf_dir),
        help=f"PDF格納ディレクトリ (既定: {default_pdf_dir})",
    )
    parser.add_argument(
        "--chapter-dir",
        default=str(default_chapter_dir),
        help=f"章JSON格納ディレクトリ (既定: {default_chapter_dir})",
    )
    parser.add_argument(
        "--version",
        default="v1",
        help="コマンド実行時に使用するversion値 (既定: v1)",
    )
    parser.add_argument(
        "--skip-pipeline",
        action="store_true",
        help="ペアリング後の rag_build_db.py / embed_chunks_openai.py 実行をスキップします。",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="詳細ログを表示します。",
    )
    args = parser.parse_args()

    pdf_dir = Path(args.pdf_dir).expanduser().resolve()
    chapter_dir = Path(args.chapter_dir).expanduser().resolve()
    version = args.version
    skip_pipeline = args.skip_pipeline
    verbose = args.verbose

    log_info(f"[INFO] PDFディレクトリ    : {pdf_dir}", verbose)
    log_info(f"[INFO] chapterディレクトリ: {chapter_dir}", verbose)

    if not pdf_dir.exists():
        log_error(f"[ERROR] PDFディレクトリが見つかりません: {pdf_dir}")
        return
    if not chapter_dir.exists():
        log_error(f"[ERROR] chapterディレクトリが見つかりません: {chapter_dir}")
        return

    pdf_files = sorted(pdf_dir.glob("*.pdf"))
    if not pdf_files:
        log_warn(f"[WARN] PDFファイルが見つかりません: {pdf_dir}", verbose)

    log_info(f"[INFO] PDFファイル数: {len(pdf_files)}", verbose)

    chapter_index = load_chapter_index(chapter_dir, verbose)
    log_info(f"[INFO] chapter JSON数: {len(chapter_index)}", verbose)

    pairs, unmatched_pdfs, unmatched_jsons = pair_pdfs_and_chapters(
        pdf_files, chapter_index
    )

    if pairs:
        for pdf_path, chapter_path in pairs:
            log_info(
                f"[PAIR] {pdf_path.name} <-> {chapter_path.name} "
                f"({pdf_path} :: {chapter_path})",
                verbose,
            )

    if unmatched_pdfs:
        for pdf_path in unmatched_pdfs:
            log_warn(f"[WARN] 対応するchapter JSONなし: {pdf_path.name}", verbose)

    if unmatched_jsons:
        for json_path in unmatched_jsons:
            log_warn(
                f"[WARN] 対応するPDFが見つかりません: "
                f"{json_path.name} (期待PDF: {json_path.stem.replace('_chapter', '')}.pdf)",
                verbose,
            )

    pipeline_success = 0
    pipeline_total = 0
    failed_docs: List[str] = []

    if not skip_pipeline and pairs:
        scripts_dir = Path(__file__).resolve().parent
        for pdf_path, chapter_path in pairs:
            doc_id = pdf_path.stem
            pipeline_total += 1
            print(f"[PIPELINE] doc_id={doc_id} を処理中...")
            rag_ok, embed_ok = run_pipeline_for_pair(
                pdf_path,
                chapter_path,
                doc_id,
                version,
                scripts_dir,
                verbose,
            )
            if rag_ok and embed_ok:
                pipeline_success += 1
            else:
                failed_docs.append(doc_id)

    summary_parts = [
        f"ペア: {len(pairs)}",
        f"未マッチPDF: {len(unmatched_pdfs)}",
        f"未マッチchapter JSON: {len(unmatched_jsons)}",
    ]
    if not skip_pipeline:
        summary_parts.append(
            f"pipeline OK: {pipeline_success}/{pipeline_total}"
        )
    print(f"[SUMMARY] {' / '.join(summary_parts)}")

    if failed_docs:
        for doc_id in failed_docs:
            log_error(f"[ERROR] パイプライン失敗: doc_id={doc_id}")


if __name__ == "__main__":
    main()


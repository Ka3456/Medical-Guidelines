#!/usr/bin/env python3
"""
Medical Guideline RAG Service
RAGロジックを独立したサービスクラスとして実装
"""
import os
import json
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime

import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction
from openai import OpenAI

from .route_chapter import ChapterRouter


class MedicalGuidelineRAGService:
    """医療ガイドラインRAGサービスクラス"""
    
    def __init__(
        self,
        persist_dir: str = "/tmp/chroma_db",   # ★ Cloud Run デフォルト
        toc_path: str = "toc/chapter.json",    # ★ リポジトリ同梱デフォルト
        output_dir: str = "/tmp/output",
        collection: str = "guidelines",
        openai_api_key: Optional[str] = None
    ) -> None:
        """
        RAGサービスの初期化
        
        Args:
            persist_dir: ChromaDBの永続化ディレクトリ
            toc_path: 目次JSONファイルのパス
            output_dir: ログ出力ディレクトリ
            collection: ChromaDBコレクション名
            openai_api_key: OpenAI APIキー
        """
        self.persist_dir = persist_dir
        self.toc_path = toc_path
        self.output_dir = output_dir
        self.collection = collection
        
        # OpenAI APIキーの設定
        if openai_api_key is None:
            openai_api_key = os.getenv("OPENAI_API_KEY")
        if not openai_api_key:
            raise RuntimeError("OPENAI_API_KEY が未設定です（.env か環境変数を確認してください）。")
        
        # OpenAI クライアント
        self.client = OpenAI(api_key=openai_api_key)

        # ChromaDB セットアップ
        self.chroma_client = chromadb.PersistentClient(path=persist_dir)
        self.emb_fn = OpenAIEmbeddingFunction(
            model_name="text-embedding-3-large",
            api_key=openai_api_key,
        )
        
        try:
            self.collection = self.chroma_client.get_collection(
                name=collection,
                embedding_function=self.emb_fn,
            )
        except Exception as e:
            raise RuntimeError(f"ChromaDB コレクション取得に失敗: {e}")

        # Chapter ルーター
        toc_json = json.loads(Path(toc_path).read_text(encoding="utf-8"))
        self.chapter_router = ChapterRouter(toc_json["toc"])

        # 出力ディレクトリの作成
        Path(output_dir).mkdir(exist_ok=True)

    def select_chapters(self, question: str, topk: int = 3) -> List[Dict[str, Any]]:
        """
        質問に基づいて関連する章を選択
        
        Args:
            question: 質問文
            topk: 選択する章の数
            
        Returns:
            選択された章のリスト
        """
        return self.chapter_router.route(question, topk=topk)

    def select_chunks(
        self,
        question: str,
        selected_chapters: List[Dict[str, Any]],
        topk: int = 5,
    ) -> List[Dict[str, Any]]:
        """
        質問と選択された章に基づいて関連するチャンクを選択
        
        Args:
            question: 質問文
            selected_chapters: 選択された章のリスト
            topk: 選択するチャンクの数
            
        Returns:
            選択されたチャンクのリスト
        """
        results = self.collection.query(
            query_texts=[question],
            n_results=topk * 2,  
        )
        
        chunks: List[Dict[str, Any]] = []
        for doc, metadata, distance in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0],
        ):
            chunks.append(
                {
                    "content": doc,
                    "metadata": metadata,
                    "distance": float(distance),
                    "relevance_score": 1 - float(distance),
                }
            )

        # Chapter のページ範囲でフィルタ
        relevant: List[Dict[str, Any]] = []
        for ch in chunks:
            page = int(ch["metadata"].get("page", 0))
            for sec in selected_chapters:
                sp = int(sec.get("start_page", 0))
                ep = int(sec.get("end_page", 10**9))
                if sp <= page <= ep:
                    ch["matched_chapter"] = sec["section_path"]
                    relevant.append(ch)
                    break

        relevant.sort(key=lambda x: x["relevance_score"], reverse=True)
        return relevant[:topk]

    def generate_answer(
        self,
        question: str,
        selected_chapters: List[Dict[str, Any]],
        selected_chunks: List[Dict[str, Any]],
    ) -> str:
        """
        GPT-4oを使用して回答を生成
        
        Args:
            question: 質問文
            selected_chapters: 選択された章のリスト
            selected_chunks: 選択されたチャンクのリスト
            
        Returns:
            生成された回答
        """
        context_parts: List[str] = []
        context_parts.append("## 関連する章:")
        for chapter in selected_chapters:
            context_parts.append(
                f"- {chapter['section_path']} (ページ {chapter['start_page']}-{chapter['end_page']})"
            )

        context_parts.append("\n## 関連する内容:")
        for i, chunk in enumerate(selected_chunks, 1):
            context_parts.append(
                f"### チャンク {i} (ページ {chunk['metadata']['page']}):\n{chunk['content']}\n"
            )
        context = "\n".join(context_parts)

        messages = [
            {
                "role": "system",
                "content": (
                    "あなたは心不全診療ガイドラインの専門家です。\n"
                    "提供されたガイドラインの内容に基づいて、医師向けに正確で包括的な回答を提供してください。\n"
                    "回答は以下の形式で行ってください：\n\n"
                    "1. 直接的な回答\n2. 根拠となるガイドラインの内容\n3. 必要に応じて追加の考慮事項\n\n"
                    "回答は日本語で、医療従事者向けの専門的な内容として記述してください。"
                ),
            },
            {
                "role": "user",
                "content": f"質問: {question}\n\n以下の心不全診療ガイドラインの内容を参考に回答してください：\n\n{context}",
            },
        ]

        try:
            resp = self.client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                temperature=0.3,
                max_tokens=2000,
            )
            return resp.choices[0].message.content
        except Exception as e:
            raise RuntimeError(f"GPT 生成エラー: {e}")

    def save_log(self, payload: Dict[str, Any]) -> str:
        """
        処理ログをファイルに保存
        
        Args:
            payload: 保存するデータ
            
        Returns:
            保存されたファイルのパス
        """
        now = datetime.now().strftime("%Y年%m月%d日%H時%M分")
        filepath = Path(self.output_dir) / f"{now}.txt"

        lines: List[str] = []
        lines.append("=" * 80)
        lines.append("Medical Guideline QA System - ログ")
        lines.append(f"実行日時: {now}")
        lines.append("=" * 80)
        lines.append("")

        # Q
        lines.append("【質問】")
        lines.append(payload["question"])
        lines.append("")

        # Chapters
        lines.append("【選択された章】")
        for i, ch in enumerate(payload["selected_chapters"], 1):
            lines.append(f"{i}. {ch['section_path']}")
            lines.append(f"   スコア: {ch['score']:.3f}")
            lines.append(f"   レベル: {ch['level']}")
            lines.append(f"   ページ範囲: {ch['start_page']}-{ch['end_page']}")
            lines.append("")

        # Chunks (完全版)
        lines.append("【選択されたチャンク（完全版）}")
        original_chunks = payload.get("_original_chunks", [])
        for i, ch in enumerate(payload["selected_chunks"], 1):
            lines.append(f"--- チャンク {i} ---")
            lines.append(f"ページ: {ch['page']}")
            lines.append(f"チャンクID: {ch['chunk_id']}")
            lines.append(f"関連章: {ch['matched_chapter']}")
            lines.append(f"関連度スコア: {ch['relevance_score']:.3f}")
            lines.append("")
            lines.append("【チャンク内容】")

            full_content = ""
            for org in original_chunks:
                if (
                    org["metadata"]["page"] == ch["page"]
                    and org["metadata"]["chunk"] == ch["chunk_id"]
                ):
                    full_content = org["content"]
                    break
            lines.append(full_content or "（チャンク内容の取得に失敗しました）")
            lines.append("")
            lines.append("-" * 60)
            lines.append("")

        lines.append("【GPT-4o回答】")
        lines.append(payload["answer"])
        lines.append("")
        lines.append("=" * 80)
        lines.append("ログ終了")
        lines.append("=" * 80)

        filepath.write_text("\n".join(lines), encoding="utf-8")
        return str(filepath)

    def process_question(
        self, 
        question: str, 
        topk_chapters: int = 3, 
        topk_chunks: int = 5
    ) -> Dict[str, Any]:
        """
        質問の一括処理（章選択→チャンク選択→回答生成）
        
        Args:
            question: 質問文
            topk_chapters: 選択する章の数
            topk_chunks: 選択するチャンクの数
            
        Returns:
            処理結果の辞書
        """
        selected_chapters = self.select_chapters(question, topk=topk_chapters)
        selected_chunks = self.select_chunks(question, selected_chapters, topk=topk_chunks)
        answer = self.generate_answer(question, selected_chapters, selected_chunks)

        result = {
            "question": question,
            "selected_chapters": selected_chapters,
            "selected_chunks": [
                {
                    "page": ch["metadata"]["page"],
                    "chunk_id": ch["metadata"].get("chunk"),
                    "matched_chapter": ch.get("matched_chapter"),
                    "relevance_score": ch["relevance_score"],
                    "content_preview": (ch["content"][:200] + "...") if len(ch["content"]) > 200 else ch["content"],
                }
                for ch in selected_chunks
            ],
            "answer": answer,
            "_original_chunks": selected_chunks,  # ログ用
        }
        
        # ログ保存
        log_file = self.save_log(result)
        result["log_file"] = log_file
        return result

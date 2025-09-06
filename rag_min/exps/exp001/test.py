#!/usr/bin/env python3
"""
慢性心不全治療方針の質問処理テスト
- Chapter選択
- チャンク選択  
- GPT-4o回答生成
"""

import os
import json
from pathlib import Path
from typing import List, Dict, Any
from dotenv import load_dotenv
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction
from openai import OpenAI

# 環境設定
load_dotenv("../../.env")
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# 設定
PERSIST_DIR = "data/chroma_db"
COLLECTION = "guidelines"
TOC_PATH = "toc/chapter.json"

# Chapter選択用のルーターをインポート
from route_chapter import ChapterRouter

class MedicalGuidelineQA:
    def __init__(self):
        """初期化: ChromaDBとChapterRouterをセットアップ"""
        # ChromaDBクライアント
        self.chroma_client = chromadb.PersistentClient(path=PERSIST_DIR)
        self.emb_fn = OpenAIEmbeddingFunction(
            model_name="text-embedding-3-large",
            api_key=os.getenv("OPENAI_API_KEY")
        )
        self.collection = self.chroma_client.get_collection(
            name=COLLECTION, 
            embedding_function=self.emb_fn
        )
        
        # Chapter選択用ルーター
        toc_json = json.loads(Path(TOC_PATH).read_text(encoding="utf-8"))
        self.chapter_router = ChapterRouter(toc_json["toc"])
        
        print("✅ MedicalGuidelineQA initialized")
        print(f"   - ChromaDB collection: {COLLECTION}")
        print(f"   - TOC sections: {len(toc_json['toc'])}")
    
    def select_chapters(self, question: str, topk: int = 3) -> List[Dict[str, Any]]:
        """質問に基づいて関連するChapterを選択"""
        print(f"\n🔍 Chapter selection for: '{question}'")
        
        selected_chapters = self.chapter_router.route(question, topk=topk)
        
        print("Selected chapters:")
        for i, chapter in enumerate(selected_chapters, 1):
            print(f"  {i}. {chapter['section_path']} (score: {chapter['score']:.3f})")
            print(f"     Level: {chapter['level']}, Pages: {chapter['start_page']}-{chapter['end_page']}")
        
        return selected_chapters
    
    def select_chunks(self, question: str, selected_chapters: List[Dict[str, Any]], topk: int = 5) -> List[Dict[str, Any]]:
        """選択されたChapterに関連するチャンクを検索"""
        print(f"\n📚 Chunk selection for: '{question}'")
        
        # 質問でベクトル検索
        results = self.collection.query(
            query_texts=[question],
            n_results=topk * 2  # 多めに取得して後でフィルタリング
        )
        
        # 結果を整形
        chunks = []
        for i, (doc, metadata, distance) in enumerate(zip(
            results['documents'][0],
            results['metadatas'][0], 
            results['distances'][0]
        )):
            chunks.append({
                'content': doc,
                'metadata': metadata,
                'distance': distance,
                'relevance_score': 1 - distance  # 距離を関連度スコアに変換
            })
        
        # 選択されたChapterのページ範囲内のチャンクを優先
        relevant_chunks = []
        for chunk in chunks:
            chunk_page = chunk['metadata'].get('page', 0)
            
            # 選択されたChapterのページ範囲内かチェック
            for chapter in selected_chapters:
                start_page = chapter.get('start_page', 0)
                end_page = chapter.get('end_page', 999)
                
                if start_page <= chunk_page <= end_page:
                    chunk['matched_chapter'] = chapter['section_path']
                    relevant_chunks.append(chunk)
                    break
        
        # 関連度でソートして上位を選択
        relevant_chunks.sort(key=lambda x: x['relevance_score'], reverse=True)
        selected_chunks = relevant_chunks[:topk]
        
        print("Selected chunks:")
        for i, chunk in enumerate(selected_chunks, 1):
            print(f"  {i}. Page {chunk['metadata']['page']}, Chunk {chunk['metadata']['chunk']}")
            print(f"     Chapter: {chunk.get('matched_chapter', 'N/A')}")
            print(f"     Relevance: {chunk['relevance_score']:.3f}")
            print(f"     Content preview: {chunk['content'][:100]}...")
            print()
        
        return selected_chunks
    
    def generate_answer(self, question: str, selected_chapters: List[Dict[str, Any]], selected_chunks: List[Dict[str, Any]]) -> str:
        """GPT-4oを使って回答を生成"""
        print(f"\n🤖 Generating answer with GPT-4o...")
        
        # コンテキストを構築
        context_parts = []
        
        # 選択されたChapter情報
        context_parts.append("## 関連する章:")
        for chapter in selected_chapters:
            context_parts.append(f"- {chapter['section_path']} (ページ {chapter['start_page']}-{chapter['end_page']})")
        
        # 選択されたチャンク内容
        context_parts.append("\n## 関連する内容:")
        for i, chunk in enumerate(selected_chunks, 1):
            context_parts.append(f"### チャンク {i} (ページ {chunk['metadata']['page']}):")
            context_parts.append(chunk['content'])
            context_parts.append("")
        
        context = "\n".join(context_parts)
        
        # GPT-4oに送信
        messages = [
            {
                "role": "system",
                "content": """あなたは心不全診療ガイドラインの専門家です。
提供されたガイドラインの内容に基づいて、正確で包括的な回答を提供してください。
回答は以下の形式で行ってください：

1. 直接的な回答
2. 根拠となるガイドラインの内容
3. 必要に応じて追加の考慮事項

回答は日本語で、医療従事者向けの専門的な内容として記述してください。"""
            },
            {
                "role": "user", 
                "content": f"""質問: {question}

以下の心不全診療ガイドラインの内容を参考に回答してください：

{context}"""
            }
        ]
        
        try:
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                temperature=0.3,
                max_tokens=2000
            )
            
            answer = response.choices[0].message.content
            print("✅ Answer generated successfully")
            return answer
            
        except Exception as e:
            print(f"❌ Error generating answer: {e}")
            return f"回答の生成中にエラーが発生しました: {e}"
    
    def process_question(self, question: str) -> Dict[str, Any]:
        """質問処理のメイン関数"""
        print(f"\n{'='*60}")
        print(f"質問: {question}")
        print(f"{'='*60}")
        
        # 1. Chapter選択
        selected_chapters = self.select_chapters(question, topk=3)
        
        # 2. チャンク選択
        selected_chunks = self.select_chunks(question, selected_chapters, topk=5)
        
        # 3. 回答生成
        answer = self.generate_answer(question, selected_chapters, selected_chunks)
        
        # 結果をまとめる
        result = {
            'question': question,
            'selected_chapters': selected_chapters,
            'selected_chunks': [
                {
                    'page': chunk['metadata']['page'],
                    'chunk_id': chunk['metadata']['chunk'],
                    'matched_chapter': chunk.get('matched_chapter'),
                    'relevance_score': chunk['relevance_score'],
                    'content_preview': chunk['content'][:200] + "..." if len(chunk['content']) > 200 else chunk['content']
                }
                for chunk in selected_chunks
            ],
            'answer': answer
        }
        
        return result

def main():
    """メイン実行関数"""
    print("🏥 Medical Guideline QA System")
    print("=" * 50)
    
    # QAシステムを初期化
    qa_system = MedicalGuidelineQA()
    
    # テスト質問
    question = "肥大型心筋症の既往がある患者　禁忌ある？"
    
    # 質問処理
    result = qa_system.process_question(question)
    
    # 結果表示
    print(f"\n{'='*60}")
    print("📋 最終結果")
    print(f"{'='*60}")
    
    print(f"\n❓ 質問: {result['question']}")
    
    print(f"\n📖 選択された章:")
    for i, chapter in enumerate(result['selected_chapters'], 1):
        print(f"  {i}. {chapter['section_path']} (スコア: {chapter['score']:.3f})")
    
    print(f"\n📄 選択されたチャンク:")
    for i, chunk in enumerate(result['selected_chunks'], 1):
        print(f"  {i}. ページ {chunk['page']}, チャンク {chunk['chunk_id']}")
        print(f"     関連章: {chunk['matched_chapter']}")
        print(f"     関連度: {chunk['relevance_score']:.3f}")
        print(f"     内容: {chunk['content_preview']}")
        print()
    
    print(f"\n💡 GPT-4o回答:")
    print("-" * 40)
    print(result['answer'])
    print("-" * 40)

if __name__ == "__main__":
    main()

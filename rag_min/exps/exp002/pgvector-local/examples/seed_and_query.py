#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pgvectorローカル検証用：ダミーデータ投入＆検索スクリプト
外部API依存なしで動作確認できる
"""
import os
import hashlib
import numpy as np
import psycopg

DIM = 1536

def text_to_vec(t: str, dim=DIM):
    """
    テキストから決定論的にダミー埋め込みを作る（再現性重視）
    実際の使用時は OpenAI API などで置き換える
    """
    h = hashlib.sha256(t.encode()).digest()
    rng = np.random.default_rng(int.from_bytes(h[:8], 'little'))
    v = rng.standard_normal(dim).astype(np.float32)
    v /= np.linalg.norm(v) + 1e-12
    return v.tolist()

def main():
    # 接続情報（環境変数 or デフォルト）
    conn_str = (
        f"postgresql://{os.getenv('PGUSER', 'pguser')}:"
        f"{os.getenv('PGPASSWORD', 'pgpass')}@"
        f"{os.getenv('PGHOST', '127.0.0.1')}:"
        f"{os.getenv('PGPORT', '5433')}/"
        f"{os.getenv('PGDATABASE', 'ragdb')}"
    )
    
    print("=" * 72)
    print("pgvectorローカル検証：ダミーデータ投入＆検索")
    print("=" * 72)
    print(f"接続先: {conn_str.split('@')[-1] if '@' in conn_str else conn_str}")
    print()
    
    try:
        with psycopg.connect(conn_str) as conn:
            cur = conn.cursor()
            
            # サンプルドキュメント（医療ガイドライン風）
            docs = [
                ("hf_01", "心不全の定義とステージ分類"),
                ("hf_02", "急性非代償性心不全の初期対応"),
                ("rx_01", "ACE阻害薬とARBの使い分け"),
                ("rx_02", "β遮断薬の増量プロトコル"),
                ("lab_01", "BNPとNT-proBNPの解釈"),
                ("hf_03", "心不全の原因診断"),
                ("rx_03", "利尿薬の種類と適応"),
            ]
            
            print("📝 ドキュメントを投入中...")
            for doc_id, content in docs:
                embedding = text_to_vec(content)
                cur.execute("""
                    INSERT INTO docs (doc_id, content, embedding)
                    VALUES (%s, %s, %s::vector)
                    ON CONFLICT (doc_id) 
                    DO UPDATE SET content=EXCLUDED.content, embedding=EXCLUDED.embedding
                """, (doc_id, content, embedding))
            
            conn.commit()
            print(f"✅ {len(docs)}件のドキュメントを投入しました")
            print()
            
            # 検索クエリ
            test_queries = [
                "β遮断薬の導入タイミング",
                "心不全の初期対応",
                "利尿薬の使い方",
            ]
            
            print("🔍 類似検索テスト")
            print("-" * 72)
            
            for query in test_queries:
                print(f"\n質問: {query}")
                query_vec = text_to_vec(query)
                
                cur.execute("""
                    SELECT doc_id, content,
                           (embedding <=> %s::vector) AS distance
                    FROM docs
                    ORDER BY embedding <=> %s::vector
                    LIMIT 3
                """, (query_vec, query_vec))
                
                results = cur.fetchall()
                if results:
                    print("  上位結果:")
                    for i, (doc_id, content, distance) in enumerate(results, 1):
                        print(f"    {i}. [{doc_id}] {content[:50]}... (距離: {distance:.4f})")
                else:
                    print("  ⚠️  結果なし")
            
            print()
            print("=" * 72)
            print("✅ 検証完了！")
            print("=" * 72)
            
    except psycopg.OperationalError as e:
        print(f"❌ データベース接続エラー: {e}")
        print()
        print("💡 Dockerコンテナが起動しているか確認:")
        print("   docker compose -f docker-compose.yml up -d")
        return 1
    except Exception as e:
        print(f"❌ エラー: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())


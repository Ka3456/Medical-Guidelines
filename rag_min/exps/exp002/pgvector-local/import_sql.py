#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
既存のSQLファイル（JCS2013_ogawah_h.sql）をpgvector-localに投入するスクリプト
"""
import os
import sys
import psycopg
from pathlib import Path

def main():
    # SQLファイルのパス
    sql_file = Path(__file__).parent.parent / "output" / "JCS2013_ogawah_h.sql"
    
    if not sql_file.exists():
        print(f"❌ SQLファイルが見つかりません: {sql_file}")
        return 1
    
    print("=" * 72)
    print("既存SQLファイルをpgvector-localに投入")
    print("=" * 72)
    print(f"SQLファイル: {sql_file}")
    print(f"ファイルサイズ: {sql_file.stat().st_size / 1024 / 1024:.2f} MB")
    print()
    
    # 接続（5433ポートをハードコード）
    conn_str = "postgresql://pguser:pgpass@127.0.0.1:5433/ragdb"
    
    try:
        print("📡 データベースに接続中...")
        conn = psycopg.connect(conn_str)
        conn.autocommit = False
        
        print("📝 SQLファイルを読み込み中...")
        sql_content = sql_file.read_text(encoding='utf-8')
        
        print("🔧 ベクトル形式を変換中...")
        # pgvectorは角括弧形式 [0.0, 0.0, ...] を要求
        # SQLファイルは括弧形式 (0.000000, ...) を使用しているので変換
        import re
        
        # ベクトル値のパターン: '(0.000000,0.000000,...)'::vector
        # を '[0.000000,0.000000,...]'::vector に変換
        def convert_vector_format(match):
            vec_str = match.group(1)  # 括弧の中身
            # 括弧を角括弧に変換
            return f"'[{vec_str}]'::vector"
        
        # パターン: '(...)'::vector を探して '[...]'::vector に変換
        sql_content = re.sub(
            r"'\(([0-9.,\-\s]+)\)'::vector",
            lambda m: f"'[{m.group(1)}]'::vector",
            sql_content
        )
        
        print("💾 SQLを実行中...")
        cur = conn.cursor()
        
        # SQLファイルを実行（セミコロンで分割して実行）
        # ただし、複数行のINSERT文があるので、全体を一度に実行
        cur.execute(sql_content)
        
        conn.commit()
        
        # 投入結果を確認
        cur.execute("SELECT COUNT(*) FROM chunks;")
        chunks_count = cur.fetchone()[0]
        
        cur.execute("SELECT COUNT(*) FROM toc;")
        toc_count = cur.fetchone()[0]
        
        cur.execute("SELECT COUNT(DISTINCT doc_id) FROM chunks;")
        doc_count = cur.fetchone()[0]
        
        print()
        print("✅ SQLファイルの投入が完了しました！")
        print()
        print("📊 投入結果:")
        print(f"   - chunks テーブル: {chunks_count:,} 件")
        print(f"   - toc テーブル: {toc_count:,} 件")
        print(f"   - ドキュメント数: {doc_count} 件")
        print()
        print("=" * 72)
        print("💡 RAG検索を実行:")
        print('   python3 rag_vector.py --q "心不全の初期対応" --doc JCS2013_ogawah_h')
        print("=" * 72)
        
        cur.close()
        conn.close()
        
        return 0
        
    except psycopg.OperationalError as e:
        print(f"❌ データベース接続エラー: {e}")
        print()
        print("💡 Dockerコンテナが起動しているか確認:")
        print("   docker compose ps")
        return 1
    except psycopg.Error as e:
        print(f"❌ SQL実行エラー: {e}")
        print()
        print("💡 エラーの詳細:")
        print(f"   {e}")
        conn.rollback()
        return 1
    except Exception as e:
        print(f"❌ 予期しないエラー: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit(main())


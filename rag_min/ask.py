# ask.py
from dotenv import load_dotenv
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

PERSIST_DIR = "data/chroma_db"
COLLECTION = "guidelines"

def main(question: str, k: int = 5):
    load_dotenv()
    client = chromadb.PersistentClient(path=PERSIST_DIR)
    emb_fn = OpenAIEmbeddingFunction(model_name="text-embedding-3-large")
    col = client.get_or_create_collection(name=COLLECTION, embedding_function=emb_fn)

    res = col.query(query_texts=[question], n_results=k)
    docs = res.get("documents", [[]])[0]
    metas = res.get("metadatas", [[]])[0]
    print("▼ 類似チャンク")
    for i, (d, m) in enumerate(zip(docs, metas), start=1):
        print(f"\n[{i}] {m.get('source')} p.{m.get('page')} chunk {m.get('chunk')}")
        print(d[:500] + ("..." if len(d) > 500 else ""))

if __name__ == "__main__":
    import sys
    assert len(sys.argv) >= 2, "使い方: python ask.py '高血圧の診断基準は？'"
    q = " ".join(sys.argv[1:])
    main(q)

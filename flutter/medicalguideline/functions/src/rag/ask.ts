// functions/src/rag/ask.ts
import {onRequest, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";

const RAG_BASE_URL = defineSecret("RAG_BASE_URL");

// ───────── onRequest（既存・curl向け）─────────
export const askRag = onRequest(
  {region: "asia-northeast1", secrets: [RAG_BASE_URL], timeoutSeconds: 30},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Use POST"});
      return;
    }

    const body = typeof req.body === "string" ?
      JSON.parse(req.body || "{}") : (req.body ?? {});
    const question: string | undefined = body.question ?? body.query;
    if (!question) {
      res.status(400).json({error: "Missing 'question'"});
      return;
    }

    try {
      const upstream = await fetch(`${RAG_BASE_URL.value()}/ask`, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({question}),
      });

      const text = await upstream.text();
      let data: unknown = text;
      try {
        data = JSON.parse(text);
      } catch {
        // Keep original text if parsing fails
      }
      if (!upstream.ok) {
        logger.error("Upstream error", {status: upstream.status, data});
        res.status(upstream.status).json({
          error: "Upstream error",
          detail: data,
        });
        return;
      }
      res.status(200).json(data);
    } catch (e: unknown) {
      logger.error("askRag failed", e);
      const message = e instanceof Error ? e.message : String(e);
      res.status(500).json({
        error: "Internal",
        message: message,
      });
    }
  }
);

// ───────── onCall（Flutter から httpsCallable で呼ぶ用）─────────
export const askRagCallable = onCall(
  {region: "asia-northeast1", secrets: [RAG_BASE_URL], timeoutSeconds: 30},
  async (req) => {
    const question: string | undefined = req.data?.question ?? req.data?.query;
    if (!question) {
      return {error: "Missing 'question'"};
    }

    try {
      const upstream = await fetch(`${RAG_BASE_URL.value()}/ask`, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({question}),
      });

      const text = await upstream.text();
      let data: unknown = text;
      try {
        data = JSON.parse(text);
      } catch {
        // Keep original text if parsing fails
      }
      if (!upstream.ok) {
        logger.error("Upstream error", {status: upstream.status, data});
        return {
          error: "Upstream error",
          detail: data,
          status: upstream.status,
        };
      }
      return data; // ← そのまま Flutter に返す
    } catch (e: unknown) {
      logger.error("askRagCallable failed", e);
      const message = e instanceof Error ? e.message : String(e);
      return {error: "Internal", message: message};
    }
  }
);

// おまけ: /health 相当（onCall で簡易ヘルス）
export const ping = onCall({region: "asia-northeast1"}, async () => {
  return {
    ok: true,
    ready: true,
    ts: Date.now(),
    documents_count: 0, // 実際の文書数は後で実装
    openai_available: true, // 実際の状態は後で実装
  };
});

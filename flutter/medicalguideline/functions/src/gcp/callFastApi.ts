import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import {GoogleAuth} from "google-auth-library";
import axios from "axios";

// Secrets定義（Gitには含まれない、Firebase側で管理）
const FASTAPI_AUDIENCE = defineSecret("FASTAPI_AUDIENCE");
const FASTAPI_URL = defineSecret("FASTAPI_URL");

// サービスアカウント定義
const SERVICE_ACCOUNT =
  "vm-api-client@medical-guideline-bot.iam.gserviceaccount.com";

// ───────── onRequest（SSE ストリーミング対応）─────────
export const callFastApi = onRequest(
  {
    region: "asia-northeast1",
    secrets: [FASTAPI_AUDIENCE, FASTAPI_URL],
    timeoutSeconds: 120,
    cors: true, // CORS を有効化
    serviceAccount: SERVICE_ACCOUNT,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Use POST"});
      return;
    }

    const body = typeof req.body === "string" ?
      JSON.parse(req.body || "{}") : (req.body ?? {});
    const question: string | undefined = body.question;

    if (!question) {
      res.status(400).json({error: "Missing 'question'"});
      return;
    }

    try {
      logger.info("Authenticating with Google Auth...");
      const auth = new GoogleAuth();
      const client = await auth.getIdTokenClient(FASTAPI_AUDIENCE.value());

      // 正しい方法でIDトークンを取得
      const headers = await client.getRequestHeaders();
      const authHeader = headers.get?.("Authorization") ||
                         headers.get?.("authorization") || "";
      const idToken = authHeader.replace("Bearer ", "");

      logger.info("Authentication successful", {
        hasAuthHeader: !!authHeader,
        hasIdToken: !!idToken,
        idTokenLength: idToken.length,
        idTokenPrefix: idToken.substring(0, 30) + "...",
      });

      // SSE ヘッダーを設定
      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");

      // URLから余分な空白・改行を除去
      const fastApiUrl = FASTAPI_URL.value().trim();

      // axios で SSE ストリーミングを取得
      const response = await axios.post(
        fastApiUrl,
        {question},
        {
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${idToken}`,
          },
          responseType: "stream",
          timeout: 120000, // 120秒タイムアウト（Firebase Functions と同じ）
        }
      );

      // ストリーミングをそのまま中継
      response.data.on("data", (chunk: Buffer) => {
        res.write(chunk);
      });

      response.data.on("end", () => {
        res.end();
      });

      response.data.on("error", (err: Error) => {
        logger.error("Stream error", {
          error: err.message,
        });
        res.write(`data: ${JSON.stringify({
          status: "error",
          message: err.message,
        })}\n\n`);
        res.end();
      });
    } catch (err: unknown) {
      // Axios エラーの詳細情報を取得
      if (axios.isAxiosError(err)) {
        logger.error("callFastApi - Axios error", {
          message: err.message,
          code: err.code,
          status: err.response?.status,
          statusText: err.response?.statusText,
          responseData: err.response?.data,
          requestUrl: err.config?.url,
          requestMethod: err.config?.method,
          timeout: err.config?.timeout,
        });
      } else {
        logger.error("callFastApi failed", {
          error: err instanceof Error ? err.message : String(err),
          stack: err instanceof Error ? err.stack : undefined,
        });
      }

      const message = err instanceof Error ? err.message : String(err);

      // エラーもSSE形式で返す
      res.write(`data: ${JSON.stringify({
        status: "error",
        message: message,
      })}\n\n`);
      res.end();
    }
  }
);

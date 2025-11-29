import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

// カスタム例外クラス
class ChatServiceException implements Exception {
  final String message;
  final dynamic originalError;

  ChatServiceException(this.message, this.originalError);

  @override
  String toString() => 'ChatServiceException: $message';
}

class ChatService {
  // Functions（asia-northeast1）ハンドル
  final FirebaseFunctions _fns = FirebaseFunctions.instanceFor(
    region: 'asia-northeast1',
  );

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final callable = _fns.httpsCallable('ping');
      final resp = await callable.call();
      // 返り値は Map<String, dynamic> 想定
      return Map<String, dynamic>.from(resp.data as Map);
    } catch (e) {
      throw Exception('Functions ping failed: $e');
    }
  }

  Future<Map<String, dynamic>> askQuestion(String question, {int k = 5}) async {
    try {
      final callable = _fns.httpsCallable('askRagCallable');
      final resp = await callable.call(<String, dynamic>{
        'question': question,
        // Cloud Run の /ask は k を受け取らない想定なら無視されます
        'k': k,
      });

      // Map で返るので揃える
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      } else if (resp.data is String) {
        // サーバからプレーンテキストが返るケースを吸収
        return {'text': resp.data};
      } else {
        return {'data': resp.data};
      }
    } catch (e) {
      throw Exception('Functions ask failed: $e');
    }
  }

  /// GCP VM (FastAPI) にストリーミングリクエストを送る
  /// SSE形式で回答をリアルタイムに受け取る
  Stream<String> callFastApiStream(String question) async* {
    debugPrint('=== callFastApiStream START ===');
    debugPrint('Question length: ${question.length}');

    try {
      // Firebase Functions の callFastApi エンドポイント URL
      // region: asia-northeast1, projectId: medical-guideline-bot
      final functionUrl =
          'https://asia-northeast1-medical-guideline-bot.cloudfunctions.net/callFastApi';

      debugPrint('Function URL: $functionUrl');

      final request = http.Request('POST', Uri.parse(functionUrl));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'question': question});

      debugPrint('Sending HTTP request...');
      final response = await request.send();
      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('FastAPI request failed: ${response.statusCode}');
      }

      debugPrint('Starting SSE stream processing...');
      int chunkCount = 0;
      int eventCount = 0;

      // SSE ストリームを処理
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        chunkCount++;
        debugPrint('Received chunk #$chunkCount (${chunk.length} chars)');

        // SSE形式をパース: "data: {...}\n\n"
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            debugPrint('Parsing SSE line: ${jsonStr.length} chars');
            try {
              final event = jsonDecode(jsonStr) as Map<String, dynamic>;
              debugPrint('Event parsed - status: ${event['status']}');

              if (event['status'] == 'answer_chunk' &&
                  event['content'] != null) {
                eventCount++;
                final content = event['content'] as String;
                debugPrint(
                  'Yielding content #$eventCount (${content.length} chars)',
                );
                yield content;
              } else if (event['status'] == 'error') {
                debugPrint('Error event received: ${event['message']}');
                throw Exception(event['message'] ?? 'Unknown error');
              }
            } catch (e) {
              debugPrint('❌ Failed to parse SSE event');
              debugPrint('Line: $line');
              debugPrint('Error: $e');
            }
          }
        }
      }

      debugPrint('=== Stream completed ===');
      debugPrint('Total chunks: $chunkCount');
      debugPrint('Total events: $eventCount');
    } catch (e) {
      debugPrint('=== FastAPI Stream エラー ===');
      debugPrint('エラータイプ: ${e.runtimeType}');
      debugPrint('エラー: $e');
      if (e is Exception) {
        debugPrint('Exception details: ${e.toString()}');
      }
      debugPrint('============================');
      throw ChatServiceException('FastAPIとの通信に失敗しました', e);
    }
  }

  /// メッセージ送信（ストリーミング対応）
  /// FastAPI にリクエストを送り、回答をリアルタイムで受け取る
  Stream<String> sendMessageStream(String message) async* {
    try {
      await for (final chunk in callFastApiStream(message)) {
        yield chunk;
      }
    } catch (e) {
      debugPrint('=== ChatService エラー詳細 ===');
      debugPrint('エラータイプ: ${e.runtimeType}');
      debugPrint('エラーメッセージ: $e');
      debugPrint('============================');
      throw ChatServiceException('通信に失敗しました。ネットワーク接続を確認してください。', e);
    }
  }

  /// 従来のメッセージ送信（互換性のため残す）
  /// RAG を使用
  Future<ChatMessage> sendMessage(String message) async {
    try {
      // まずは askRagCallable を使う（/chat が未実装でも動く）
      final result = await askQuestion(message);

      // Cloud Run の返却を想定して素直に取り出す
      final answer =
          result['answer'] ??
          result['response'] ??
          result['text'] ??
          '回答が見つかりませんでした。';

      return ChatMessage.assistant(
        answer,
        '', // 第2引数（使用されていないパラメータ）
        // コスト情報などあれば付与
        costInfo: result['cost_info'] != null
            ? CostInfo.fromJson(Map<String, dynamic>.from(result['cost_info']))
            : null,
      );
    } catch (e) {
      // デバッグ用：エラー詳細を出力
      debugPrint('=== ChatService エラー詳細 ===');
      debugPrint('エラータイプ: ${e.runtimeType}');
      debugPrint('エラーメッセージ: $e');
      debugPrint('============================');

      // エラーを再スローして、呼び出し元で適切にハンドリングできるようにする
      throw ChatServiceException('通信に失敗しました。ネットワーク接続を確認してください。', e);
    }
  }
}

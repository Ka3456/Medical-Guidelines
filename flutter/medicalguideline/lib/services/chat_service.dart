import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
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

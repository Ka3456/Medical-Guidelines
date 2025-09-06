import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class ChatService {
  static const String baseUrl = 'http://localhost:8000';

  // FastAPI の /health に合わせる
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> askQuestion(String question, {int k = 5}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'question': question, 'k': k}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get answer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<ChatMessage> sendMessage(String message) async {
    try {
      // 新しい /chat エンドポイントを使用
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'message': message, 'k': 5, 'include_context': true}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final responseText = result['response'] ?? '回答を生成できませんでした。';
        final costInfo = result['cost_info'] != null
            ? CostInfo.fromJson(result['cost_info'])
            : null;

        return ChatMessage.assistant(responseText, costInfo: costInfo);
      } else {
        throw Exception('Failed to get chat response: ${response.statusCode}');
      }
    } catch (e) {
      // フォールバック: 従来の /ask エンドポイントを使用
      try {
        final result = await askQuestion(message);
        if (result['hits'] != null && result['hits'].isNotEmpty) {
          final responseText = result['hits'][0]['text'] ?? '回答が見つかりませんでした。';
          return ChatMessage.assistant(responseText);
        } else {
          return ChatMessage.assistant('回答が見つかりませんでした。');
        }
      } catch (fallbackError) {
        return ChatMessage.assistant(_getMockResponse(message));
      }
    }
  }

  String _getMockResponse(String message) {
    final responses = [
      'こんにちは！医療ガイドラインについてお聞かせください。',
      'その質問についてはガイドラインを確認する必要があります。',
      '医療の重要な決定は必ず医師にご相談ください。',
      'ガイドラインの推奨事項をお調べしました。',
    ];
    return responses[message.length % responses.length];
  }
}

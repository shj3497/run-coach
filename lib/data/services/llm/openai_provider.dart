import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'llm_provider.dart';

/// OpenAI Chat Completions API 구현체
class OpenAIProvider extends LLMProvider {
  static const String _baseUrl = 'https://api.openai.com/v1';

  final Dio _dio;
  final String _apiKey;
  final String _model;

  OpenAIProvider({
    Dio? dio,
    String? apiKey,
    String? model,
  })  : _apiKey = apiKey ?? dotenv.env['OPENAI_API_KEY']!,
        _model = model ?? dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o',
        _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 120);
  }

  @override
  String get providerName => 'openai';

  @override
  String get modelName => _model;

  @override
  Future<LLMResponse> generate({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    int? maxTokens,
    String responseFormat = 'text',
  }) async {
    try {
      final body = <String, dynamic>{
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
      };

      if (responseFormat == 'json_object') {
        body['response_format'] = {'type': 'json_object'};
      }

      if (maxTokens != null) {
        body['max_tokens'] = maxTokens;
      }

      final response = await _dio.post(
        '/chat/completions',
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final choice = (data['choices'] as List).first as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>;
      final content = message['content'] as String;
      final usage = data['usage'] as Map<String, dynamic>;

      return LLMResponse(
        content: content,
        model: data['model'] as String? ?? _model,
        finishReason: choice['finish_reason'] as String?,
        tokenUsage: TokenUsage(
          promptTokens: usage['prompt_tokens'] as int? ?? 0,
          completionTokens: usage['completion_tokens'] as int? ?? 0,
          totalTokens: usage['total_tokens'] as int? ?? 0,
        ),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final errorBody = e.response!.data;
        String errorMessage = 'OpenAI API 오류 (HTTP $statusCode)';

        if (errorBody is Map<String, dynamic>) {
          final error = errorBody['error'] as Map<String, dynamic>?;
          if (error != null) {
            errorMessage = error['message'] as String? ?? errorMessage;
          }
        }

        throw LLMException(
          message: errorMessage,
          statusCode: statusCode,
          provider: 'openai',
        );
      }

      throw LLMException(
        message: 'OpenAI API 연결 실패: ${e.message}',
        provider: 'openai',
      );
    } catch (e) {
      if (e is LLMException) rethrow;
      throw LLMException(
        message: 'LLM 요청 처리 중 오류: $e',
        provider: 'openai',
      );
    }
  }
}

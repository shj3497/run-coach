/// LLM 프로바이더 추상 인터페이스
///
/// OpenAI, Claude 등 다양한 LLM 프로바이더를 교체할 수 있도록
/// 추상화된 인터페이스를 제공합니다.
abstract class LLMProvider {
  /// 텍스트 생성 요청
  ///
  /// [systemPrompt] 시스템 프롬프트 (역할 정의)
  /// [userPrompt] 사용자 프롬프트 (실제 요청)
  /// [temperature] 생성 온도 (0.0~2.0, 기본 0.7)
  /// [maxTokens] 최대 응답 토큰 수
  /// [responseFormat] 응답 형식 ('text' 또는 'json_object')
  ///
  /// 반환: LLMResponse
  Future<LLMResponse> generate({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    int? maxTokens,
    String responseFormat = 'text',
  });

  /// JSON 형식의 텍스트 생성 요청 (편의 메서드)
  ///
  /// `generate`와 동일하되 responseFormat을 'json_object'로 고정합니다.
  Future<LLMResponse> generateJson({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    int? maxTokens,
  }) {
    return generate(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      responseFormat: 'json_object',
    );
  }

  /// 프로바이더 이름 (예: 'openai', 'claude')
  String get providerName;

  /// 사용 중인 모델명 (예: 'gpt-4o')
  String get modelName;
}

/// LLM 응답 모델
class LLMResponse {
  /// 생성된 텍스트 내용
  final String content;

  /// 사용된 모델명
  final String model;

  /// 토큰 사용량
  final TokenUsage? tokenUsage;

  /// 응답 완료 사유 (stop, length, content_filter 등)
  final String? finishReason;

  const LLMResponse({
    required this.content,
    required this.model,
    this.tokenUsage,
    this.finishReason,
  });

  /// 토큰 사용량을 JSON으로 변환 (DB 저장용)
  Map<String, dynamic>? tokenUsageToJson() => tokenUsage?.toJson();
}

/// 토큰 사용량
class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        promptTokens: json['prompt_tokens'] as int? ?? 0,
        completionTokens: json['completion_tokens'] as int? ?? 0,
        totalTokens: json['total_tokens'] as int? ?? 0,
      );
}

/// LLM 호출 예외
class LLMException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final String? provider;
  final dynamic originalError;

  const LLMException({
    required this.message,
    this.code,
    this.statusCode,
    this.provider,
    this.originalError,
  });

  @override
  String toString() => 'LLMException${provider != null ? '[$provider]' : ''}: $message (code: $code)';

  bool get isRateLimited => statusCode == 429;
  bool get isUnauthorized => statusCode == 401;
  bool get isInsufficientQuota => statusCode == 429 || statusCode == 402;
}

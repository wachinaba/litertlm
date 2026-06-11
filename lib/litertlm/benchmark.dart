import 'dart:convert';

/// Data class to hold benchmark information.
class BenchmarkInfo {
  /// Creates benchmark information.
  const BenchmarkInfo({
    required this.initTimeInSecond,
    required this.timeToFirstTokenInSecond,
    required this.lastPrefillTokenCount,
    required this.lastDecodeTokenCount,
    required this.lastPrefillTokensPerSecond,
    required this.lastDecodeTokensPerSecond,
  });

  /// Creates benchmark information from JSON-compatible values.
  factory BenchmarkInfo.fromJson(Map<String, Object?> json) {
    return BenchmarkInfo(
      initTimeInSecond: (json['initTimeInSecond']! as num).toDouble(),
      timeToFirstTokenInSecond: (json['timeToFirstTokenInSecond']! as num)
          .toDouble(),
      lastPrefillTokenCount: (json['lastPrefillTokenCount']! as num).toInt(),
      lastDecodeTokenCount: (json['lastDecodeTokenCount']! as num).toInt(),
      lastPrefillTokensPerSecond: (json['lastPrefillTokensPerSecond']! as num)
          .toDouble(),
      lastDecodeTokensPerSecond: (json['lastDecodeTokensPerSecond']! as num)
          .toDouble(),
    );
  }

  /// Creates benchmark information from a JSON string.
  factory BenchmarkInfo.fromJsonString(String source) {
    return BenchmarkInfo.fromJson(jsonDecode(source) as Map<String, Object?>);
  }

  /// The time in seconds to initialize the engine and the conversation.
  final double initTimeInSecond;

  /// The time in seconds to the first token.
  final double timeToFirstTokenInSecond;

  /// The number of tokens in the last prefill.
  final int lastPrefillTokenCount;

  /// The number of tokens in the last decode.
  final int lastDecodeTokenCount;

  /// The number of tokens processed per second in the last prefill.
  final double lastPrefillTokensPerSecond;

  /// The number of tokens processed per second in the last decode.
  final double lastDecodeTokensPerSecond;

  /// Converts this benchmark information to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {
      'initTimeInSecond': initTimeInSecond,
      'timeToFirstTokenInSecond': timeToFirstTokenInSecond,
      'lastPrefillTokenCount': lastPrefillTokenCount,
      'lastDecodeTokenCount': lastDecodeTokenCount,
      'lastPrefillTokensPerSecond': lastPrefillTokensPerSecond,
      'lastDecodeTokensPerSecond': lastDecodeTokensPerSecond,
    };
  }
}

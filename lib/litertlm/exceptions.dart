/// Exception thrown for LiteRT-LM runtime failures.
class LiteRtLmException implements Exception {
  /// Creates a LiteRT-LM exception.
  const LiteRtLmException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'LiteRtLmException: $message';
}

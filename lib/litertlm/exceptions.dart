class LiteRtLmException implements Exception {
  const LiteRtLmException(this.message);

  final String message;

  @override
  String toString() => 'LiteRtLmException: $message';
}

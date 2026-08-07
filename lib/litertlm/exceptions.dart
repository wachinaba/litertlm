/// Native LiteRT-LM operation that failed.
enum LiteRtLmOperation {
  /// Native engine initialization.
  engineInitialization(0),

  /// Native conversation creation.
  conversationCreation(1),

  /// Native session creation.
  sessionCreation(2);

  const LiteRtLmOperation(this.nativeValue);

  /// Stable value transported across the native boundary.
  final int nativeValue;
}

/// Exception thrown for LiteRT-LM runtime failures.
class LiteRtLmException implements Exception {
  /// Creates a LiteRT-LM exception.
  const LiteRtLmException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'LiteRtLmException: $message';
}

/// Exception thrown when C++ escapes a native LiteRT-LM API boundary.
class LiteRtLmNativeException extends LiteRtLmException {
  /// Native error code for allocation failure.
  static const int outOfMemoryCode = 2;

  /// Native error code for an otherwise unidentified C++ exception.
  static const int unexpectedExceptionCode = 3;

  /// Creates a native exception for [operation].
  const LiteRtLmNativeException(
    super.message,
    this.operation, {
    required this.code,
  });

  /// Operation that encountered the native exception.
  final LiteRtLmOperation operation;

  /// Stable native error code, including codes unknown to this package version.
  final int code;

  @override
  String toString() =>
      'LiteRtLmNativeException: $message (code: $code, operation: ${operation.name})';
}

/// Exception thrown when a native LiteRT-LM allocation fails.
final class LiteRtLmOutOfMemoryException extends LiteRtLmNativeException {
  /// Creates an out-of-memory exception for [operation].
  const LiteRtLmOutOfMemoryException(LiteRtLmOperation operation)
    : super(
        'Native memory allocation failed.',
        operation,
        code: LiteRtLmNativeException.outOfMemoryCode,
      );

  @override
  String toString() =>
      'LiteRtLmOutOfMemoryException: $message (${operation.name})';
}

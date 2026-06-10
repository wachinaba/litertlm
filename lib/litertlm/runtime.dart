/// Log severity for the native LiteRT-LM library.
enum LogSeverity {
  /// Verbose log severity.
  verbose(0),

  /// Debug log severity.
  debug(1),

  /// Info log severity.
  info(2),

  /// Warning log severity.
  warning(3),

  /// Error log severity.
  error(4),

  /// Fatal log severity.
  fatal(5),

  /// Silent log severity.
  silent(1000);

  /// Creates a log severity.
  const LogSeverity(this.value);

  /// The native log severity value.
  final int value;
}

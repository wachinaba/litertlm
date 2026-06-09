enum LogSeverity {
  verbose(0),
  debug(1),
  info(2),
  warning(3),
  error(4),
  fatal(5),
  silent(1000);

  const LogSeverity(this.value);

  final int value;
}

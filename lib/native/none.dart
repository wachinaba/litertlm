import 'runtime.dart';

/// Creates a runtime for unsupported Dart platforms.
LiteRtLmNativeRuntime createRuntime() {
  throw UnsupportedError('LiteRT-LM is not supported on this platform.');
}

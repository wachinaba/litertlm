import 'dart:io' show Platform;

import 'ffi.dart';
import 'jni.dart';
import 'runtime.dart';

/// Creates the native runtime for the current IO platform.
LiteRtLmNativeRuntime createRuntime() {
  return Platform.isAndroid ? createJniRuntime() : createFfiRuntime();
}

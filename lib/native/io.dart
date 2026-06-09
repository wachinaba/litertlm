import 'dart:io' show Platform;

import 'ffi.dart';
import 'jni.dart';
import 'runtime.dart';

LiteRtLmNativeRuntime createRuntime() {
  return Platform.isAndroid ? LiteRtLmJniRuntime() : LiteRtLmFfiRuntime();
}

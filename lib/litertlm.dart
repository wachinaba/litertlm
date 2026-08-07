import 'dart:math' as math;

import 'litertlm/benchmark.dart';
import 'litertlm/config.dart';
import 'litertlm/runtime.dart';
import 'native/runtime.dart';

export 'litertlm/benchmark.dart' show BenchmarkInfo;
export 'litertlm/capabilities.dart' show Capabilities;
export 'litertlm/config.dart'
    show
        Backend,
        Channel,
        ConversationConfig,
        EngineConfig,
        LoraConfig,
        SamplerConfig,
        SessionConfig;
export 'litertlm/engine.dart'
    show Conversation, Engine, MessageCallback, Session;
export 'litertlm/exceptions.dart'
    show
        LiteRtLmException,
        LiteRtLmNativeException,
        LiteRtLmOperation,
        LiteRtLmOutOfMemoryException;
export 'litertlm/experimental_flags.dart' show ExperimentalFlags;
export 'litertlm/message.dart'
    show
        AudioBytesContent,
        AudioFileContent,
        Content,
        Contents,
        ImageBytesContent,
        ImageFileContent,
        Message,
        Role,
        TextContent,
        ToolCall,
        ToolResponseContent;
export 'litertlm/runtime.dart' show LogSeverity;
export 'litertlm/session.dart'
    show AudioInputData, ImageInputData, InputData, TextInputData;
export 'litertlm/tool.dart' show Tool, ToolManager;

/// Sets the minimum log level for the LiteRT-LM library.
void setMinimumLogLevel(LogSeverity severity) {
  LiteRtLmNativeRuntime.instance.setMinimumLogLevel(severity);
}

/// Runs a LiteRT-LM benchmark with the given prefill and decode token counts.
Future<BenchmarkInfo> benchmark({
  required String modelPath,
  required Backend backend,
  int prefillTokens = 256,
  int decodeTokens = 256,
  String? cacheDir,
}) {
  if (prefillTokens <= 0) {
    throw ArgumentError.value(
      prefillTokens,
      'prefillTokens',
      'must be positive',
    );
  }
  if (decodeTokens <= 0) {
    throw ArgumentError.value(decodeTokens, 'decodeTokens', 'must be positive');
  }

  return LiteRtLmNativeRuntime.instance.benchmark(
    EngineConfig(
      modelPath: modelPath,
      backend: backend,
      maxNumTokens: math.max(prefillTokens, decodeTokens) + 32,
      cacheDir: cacheDir,
    ),
    prefillTokens: prefillTokens,
    decodeTokens: decodeTokens,
  );
}

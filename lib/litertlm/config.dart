import 'dart:convert';

import 'message.dart';
import 'tool.dart';

/// Backend for the LiteRT-LM engine.
enum Backend {
  /// CPU LiteRT backend.
  cpu('cpu'),

  /// GPU LiteRT backend.
  gpu('gpu'),

  /// NPU LiteRT backend.
  npu('npu');

  /// Creates a backend value.
  const Backend(this.name);

  /// The backend name used by the native runtime.
  final String name;
}

/// Configuration for the LiteRT-LM engine.
class EngineConfig {
  /// Creates an engine configuration.
  const EngineConfig({
    required this.modelPath,
    this.backend = Backend.cpu,
    this.visionBackend,
    this.audioBackend,
    this.maxNumTokens,
    this.cacheDir,
    this.loraRank,
    this.audioLoraRank,
  });

  /// The file path to the LiteRT-LM model.
  final String modelPath;

  /// The backend to use for the engine.
  final Backend backend;

  /// The backend to use for the vision executor.
  final Backend? visionBackend;

  /// The backend to use for the audio executor.
  final Backend? audioBackend;

  /// The maximum number of the sum of input and output tokens.
  final int? maxNumTokens;

  /// The directory for placing cache files.
  final String? cacheDir;

  /// The supported rank for LoRA weights.
  final int? loraRank;

  /// The supported rank for Audio LoRA weights.
  final int? audioLoraRank;
}

/// Configuration for a LiteRT-LM conversation.
class ConversationConfig {
  /// Creates a conversation configuration.
  const ConversationConfig({
    this.systemMessage,
    this.initialMessages = const [],
    this.tools = const [],
    this.extraContext = const {},
    this.samplerConfig,
    this.loraPath,
    this.audioLoraPath,
    this.automaticToolCalling = true,
    this.enableConstrainedDecoding = false,
  });

  /// The system message for the conversation.
  final Message? systemMessage;

  /// The initial messages for the conversation.
  final List<Message> initialMessages;

  /// A list of tool objects to be used in the conversation.
  final List<Tool> tools;

  /// Optional context passed to prompt template rendering.
  final Map<String, Object?> extraContext;

  /// Configuration for the sampling process.
  final SamplerConfig? samplerConfig;

  /// Optional file path to the LoRA weights file.
  final String? loraPath;

  /// Optional file path to the Audio LoRA weights file.
  final String? audioLoraPath;

  /// Whether tools will be called automatically.
  final bool automaticToolCalling;

  /// Whether constrained decoding is enabled.
  final bool enableConstrainedDecoding;

  /// Converts this configuration to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {
      if (systemMessage case final systemMessage?)
        'systemMessage': systemMessage.toJson(),
      if (initialMessages.isNotEmpty)
        'initialMessages': initialMessages
            .map((message) => message.toJson())
            .toList(),
      if (tools.isNotEmpty)
        'tools': tools.map((tool) => tool.getToolDescription()).toList(),
      if (extraContext.isNotEmpty) 'extraContext': extraContext,
      if (samplerConfig case final samplerConfig?)
        'samplerConfig': samplerConfig.toJson(),
      'loraPath': ?loraPath,
      'audioLoraPath': ?audioLoraPath,
      'automaticToolCalling': automaticToolCalling,
      'enableConstrainedDecoding': enableConstrainedDecoding,
    };
  }

  /// Converts this configuration to a JSON string.
  String toJsonString() => jsonEncode(toJson());
}

/// Configuration for the sampling process.
class SamplerConfig {
  /// Creates a sampler configuration.
  const SamplerConfig({
    required this.topK,
    required this.topP,
    required this.temperature,
    this.seed = 0,
  });

  /// The number of top logits used during sampling.
  final int topK;

  /// The cumulative probability threshold for nucleus sampling.
  final double topP;

  /// The temperature to use for sampling.
  final double temperature;

  /// The seed to use for randomization.
  final int seed;

  /// Converts this configuration to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {
      'topK': topK,
      'topP': topP,
      'temperature': temperature,
      'seed': seed,
    };
  }
}

import 'message.dart';
import 'tool.dart';

/// Backend for the LiteRT-LM engine.
sealed class Backend {
  /// All backend values without additional configuration.
  static const values = [Backend.cpu(), Backend.gpu(), Backend.npu()];

  /// CPU LiteRT backend.
  const factory Backend.cpu({int? threadCount}) = CpuBackend;

  /// GPU LiteRT backend.
  const factory Backend.gpu() = GpuBackend;

  /// NPU LiteRT backend.
  const factory Backend.npu({String? nativeLibraryDir}) = NpuBackend;

  const Backend._(this.name);

  /// The backend name used by the native runtime.
  final String name;
}

/// CPU LiteRT backend.
class CpuBackend extends Backend {
  /// Creates a CPU backend configuration.
  const CpuBackend({this.threadCount}) : super._('cpu');

  /// The number of threads to use for the CPU backend.
  final int? threadCount;
}

/// GPU LiteRT backend.
class GpuBackend extends Backend {
  /// Creates a GPU backend configuration.
  const GpuBackend() : super._('gpu');
}

/// NPU LiteRT backend.
class NpuBackend extends Backend {
  /// Creates an NPU backend configuration.
  const NpuBackend({this.nativeLibraryDir}) : super._('npu');

  /// Directory containing native NPU libraries.
  final String? nativeLibraryDir;
}

/// Configuration for the LiteRT-LM engine.
class EngineConfig {
  /// Creates an engine configuration.
  const EngineConfig({
    required this.modelPath,
    this.backend = const Backend.cpu(),
    this.visionBackend,
    this.audioBackend,
    this.maxNumTokens,
    this.maxNumImages,
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

  /// The maximum number of images the model can handle.
  final int? maxNumImages;

  /// The directory for placing cache files.
  final String? cacheDir;

  /// The supported rank for LoRA weights.
  final int? loraRank;

  /// The supported rank for Audio LoRA weights.
  final int? audioLoraRank;
}

/// Definition of a channel for model responses.
class Channel {
  /// Creates a channel definition.
  const Channel({
    required this.channelName,
    required this.start,
    required this.end,
  });

  /// The channel name used as the key in [Message.channels].
  final String channelName;

  /// A string that marks the start of the channel.
  final String start;

  /// A string that marks the end of the channel.
  final String end;

  /// Converts this channel to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {'channel_name': channelName, 'start': start, 'end': end};
  }
}

/// Configuration for a LiteRT-LM conversation.
class ConversationConfig {
  /// Creates a conversation configuration.
  const ConversationConfig({
    this.systemMessage,
    this.initialMessages = const [],
    this.tools = const [],
    this.extraContext = const {},
    this.sessionConfig,
    this.automaticToolCalling = true,
    this.channels,
    this.prefillPrefaceOnInit = false,
  });

  /// The system message for the conversation.
  final Message? systemMessage;

  /// The initial messages for the conversation.
  final List<Message> initialMessages;

  /// A list of tool objects to be used in the conversation.
  final List<Tool> tools;

  /// Optional context passed to prompt template rendering.
  final Map<String, Object?> extraContext;

  /// Configuration for the session backing this conversation.
  final SessionConfig? sessionConfig;

  /// Whether tools will be called automatically.
  final bool automaticToolCalling;

  /// Channel definitions for model output, or `null` to use model defaults.
  final List<Channel>? channels;

  /// Whether to prefill the system message, initial messages, and tools into
  /// the conversation KV cache while the conversation is being created.
  ///
  /// Enabling this moves the fixed-prefix prefill cost from the first
  /// [Conversation.sendMessage] call to [Engine.createConversation]. Keep the
  /// returned conversation alive to retain that KV cache.
  final bool prefillPrefaceOnInit;

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
      if (sessionConfig case final sessionConfig?)
        'sessionConfig': sessionConfig.toJson(),
      'automaticToolCalling': automaticToolCalling,
      'prefillPrefaceOnInit': prefillPrefaceOnInit,
      if (channels case final channels?)
        'channels': channels.map((channel) => channel.toJson()).toList(),
    };
  }
}

/// Configuration for a LiteRT-LM session.
class SessionConfig {
  /// Creates a session configuration.
  const SessionConfig({
    this.samplerConfig,
    this.loraConfig,
    this.maxOutputTokens,
    this.applyPromptTemplateInSession,
  });

  /// Configuration for the sampling process.
  final SamplerConfig? samplerConfig;

  /// Configuration for LoRA weights.
  final LoraConfig? loraConfig;

  /// The maximum number of output tokens.
  final int? maxOutputTokens;

  /// Whether to apply prompt template for this session.
  final bool? applyPromptTemplateInSession;

  /// Converts this configuration to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {
      if (samplerConfig case final samplerConfig?)
        'samplerConfig': samplerConfig.toJson(),
      if (loraConfig case final loraConfig?) 'loraConfig': loraConfig.toJson(),
      'maxOutputTokens': ?maxOutputTokens,
      'applyPromptTemplateInSession': ?applyPromptTemplateInSession,
    };
  }
}

/// Configuration for LoRA weights.
class LoraConfig {
  /// Creates a LoRA configuration.
  const LoraConfig({this.loraPath, this.audioLoraPath});

  /// Optional file path to the LoRA weights file.
  final String? loraPath;

  /// Optional file path to the Audio LoRA weights file.
  final String? audioLoraPath;

  /// Converts this configuration to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {'loraPath': ?loraPath, 'audioLoraPath': ?audioLoraPath};
  }
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

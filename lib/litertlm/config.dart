import 'dart:convert';

import 'message.dart';
import 'tool.dart';

enum Backend {
  cpu('cpu'),
  gpu('gpu'),
  npu('npu');

  const Backend(this.name);

  final String name;
}

class EngineConfig {
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

  final String modelPath;
  final Backend backend;
  final Backend? visionBackend;
  final Backend? audioBackend;
  final int? maxNumTokens;
  final String? cacheDir;
  final int? loraRank;
  final int? audioLoraRank;
}

class ConversationConfig {
  const ConversationConfig({
    this.systemInstruction,
    this.initialMessages = const [],
    this.tools = const [],
    this.extraContext = const {},
    this.sessionConfig,
  });

  final Contents? systemInstruction;
  final List<Message> initialMessages;
  final List<Tool> tools;
  final Map<String, Object?> extraContext;

  final SessionConfig? sessionConfig;

  Map<String, Object?> toJson() {
    return {
      if (systemInstruction case final systemInstruction?)
        'systemInstruction': systemInstruction.toJson(),
      if (initialMessages.isNotEmpty)
        'initialMessages': initialMessages
            .map((message) => message.toJson())
            .toList(),
      if (tools.isNotEmpty) 'tools': tools.map((tool) => tool.toJson()).toList(),
      if (extraContext.isNotEmpty) 'extraContext': extraContext,
      if (sessionConfig case final sessionConfig?)
        'sessionConfig': sessionConfig.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class SessionConfig {
  const SessionConfig({this.samplerConfig, this.loraConfig});

  final SamplerConfig? samplerConfig;
  final LoraConfig? loraConfig;

  Map<String, Object?> toJson() {
    return {
      if (samplerConfig case final samplerConfig?)
        'samplerConfig': samplerConfig.toJson(),
      if (loraConfig case final loraConfig?) 'loraConfig': loraConfig.toJson(),
    };
  }
}

class SamplerConfig {
  const SamplerConfig({
    required this.topK,
    required this.topP,
    required this.temperature,
    this.seed = 0,
  });

  final int topK;
  final double topP;
  final double temperature;
  final int seed;

  Map<String, Object?> toJson() {
    return {
      'topK': topK,
      'topP': topP,
      'temperature': temperature,
      'seed': seed,
    };
  }
}

class LoraConfig {
  const LoraConfig({this.loraPath, this.audioLoraPath});

  final String? loraPath;
  final String? audioLoraPath;

  Map<String, Object?> toJson() {
    return {
      if (loraPath case final loraPath?) 'loraPath': loraPath,
      if (audioLoraPath case final audioLoraPath?)
        'audioLoraPath': audioLoraPath,
    };
  }
}

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:litertlm_example/model/asset.dart';
import 'package:litertlm/litertlm.dart';

class _WeatherTool implements Tool {
  bool wasExecuted = false;
  Map<String, Object?>? lastArguments;

  @override
  Map<String, Object?> getToolDescription() {
    return {
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'description': 'Gets the current weather for a city.',
        'parameters': {
          'type': 'object',
          'properties': {
            'city': {'type': 'string', 'description': 'City name.'},
          },
          'required': ['city'],
        },
      },
    };
  }

  @override
  Object? execute(Map<String, Object?> arguments) {
    wasExecuted = true;
    lastArguments = arguments;
    return {'city': arguments['city'], 'temperature': 72};
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sets minimum log level', (tester) async {
    if (kIsWeb) {
      expect(
        () => setMinimumLogLevel(LogSeverity.info),
        throwsUnsupportedError,
      );
    } else {
      expect(() => setMinimumLogLevel(LogSeverity.info), returnsNormally);
    }
  });

  testWidgets('runs inference', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        maxNumTokens: 10,
      ),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation();
      final response = await conversation.sendMessage(Message.user('Hello'));
      expect(response.text.length, greaterThan(5));
      if (!kIsWeb) {
        expect(await conversation.getTokenCount(), greaterThan(0));
      }
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference benchmark', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    Engine? engine;
    Conversation? conversation;
    try {
      ExperimentalFlags.enableBenchmark = true;
      engine = Engine(
        engineConfig: EngineConfig(
          modelPath: modelPath,
          backend: Backend.cpu(),
          maxNumTokens: 10,
        ),
      );
      await engine.initialize();
      conversation = await engine.createConversation();
      final response = await conversation.sendMessage(Message.user('Hello'));
      expect(response.text.length, greaterThan(5));
      final info = await conversation.getBenchmarkInfo();
      expect(info.initTimeInSecond, greaterThanOrEqualTo(0));
      expect(info.timeToFirstTokenInSecond, greaterThanOrEqualTo(0));
      expect(info.lastPrefillTokenCount, greaterThan(0));
      expect(info.lastDecodeTokenCount, greaterThan(0));
      expect(info.lastPrefillTokensPerSecond, greaterThan(0));
      expect(info.lastDecodeTokensPerSecond, greaterThan(0));
    } on UnsupportedError {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) return;
      rethrow;
    } finally {
      ExperimentalFlags.enableBenchmark = false;
      await conversation?.dispose();
      await engine?.dispose();
    }
  });

  testWidgets('runs inference stream', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        maxNumTokens: 10,
      ),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation(
        const ConversationConfig(),
      );
      var streamedChunkCount = 0;
      final streamedResponse = await conversation
          .sendMessageStream(Message.user('How are you'))
          .map((message) {
            streamedChunkCount += 1;
            return message.text;
          })
          .join();
      expect(streamedChunkCount, 7);
      expect(streamedResponse, 'Ꮝgdockdict इक इक इकद्दा');
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference stream callback', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        maxNumTokens: 10,
      ),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation(
        const ConversationConfig(),
      );
      final streamedChunks = <String>[];
      Object? callbackError;
      var isMessageDone = false;
      var isDone = false;
      await conversation.sendMessageWithCallback(
        Message.user('How are you'),
        MessageCallback.from(
          onMessage: (message) {
            streamedChunks.add(message.text);
          },
          onMessageDone: () {
            isMessageDone = true;
          },
          onDone: () {
            isDone = true;
          },
          onError: (error, stackTrace) {
            callbackError = error;
          },
        ),
      );
      expect(isMessageDone, isTrue);
      expect(isDone, isTrue);
      expect(callbackError, isNull);
      expect(streamedChunks.length, 6);
      expect(streamedChunks.join(), 'Ꮝgdockdict इक इक इकद्दा');
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference image', (tester) async {
    if (kIsWeb) {
      expect(
        () => setMinimumLogLevel(LogSeverity.verbose),
        throwsUnsupportedError,
      );
    } else {
      expect(() => setMinimumLogLevel(LogSeverity.verbose), returnsNormally);
    }

    final modelPath = await resolveModelAssetPath(
      'assets/models/gemma-4-E2B-it.litertlm',
    );
    final imagePath = await resolveModelAssetPath('assets/images/apple.png');
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        visionBackend: Backend.cpu(),
      ),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation();
      final response = await conversation.sendMessage(
        Message.userContents(
          Contents([
            Content.text('Describe this image.'),
            Content.imageFile(imagePath),
          ]),
        ),
      );
      expect(response.text.length, greaterThan(5));
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference audio', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/gemma-4-E2B-it.litertlm',
    );
    final audioPath = await resolveModelAssetPath(
      'assets/audio/have_a_wonderful_day.wav',
    );
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        audioBackend: Backend.cpu(),
      ),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation();
      final response = await conversation.sendMessage(
        Message.userContents(
          Contents([
            Content.audioFile(audioPath),
            Content.text('Describe this audio. What does it say?'),
          ]),
        ),
      );
      expect(response.text.length, greaterThan(5));
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference tool call', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/gemma-4-E2B-it.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(modelPath: modelPath, backend: Backend.cpu()),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation(
        ConversationConfig(
          automaticToolCalling: false,
          tools: [_WeatherTool()],
        ),
      );
      final response = await conversation.sendMessage(
        Message.user('Use get_weather for Mountain View.'),
      );
      expect(response.toolCalls, isNotEmpty);
      expect(response.toolCalls.first.name, 'get_weather');
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference constrained decoding tool call', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/gemma-4-E2B-it.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(modelPath: modelPath, backend: Backend.cpu()),
    );
    Conversation? conversation;
    try {
      ExperimentalFlags.enableConversationConstrainedDecoding = true;
      await engine.initialize();
      conversation = await engine.createConversation(
        ConversationConfig(
          automaticToolCalling: false,
          tools: [_WeatherTool()],
        ),
      );
      final response = await conversation.sendMessage(
        Message.user('Use get_weather for Mountain View.'),
      );
      expect(response.toolCalls, isNotEmpty);
      expect(response.toolCalls.first.name, 'get_weather');
    } finally {
      ExperimentalFlags.enableConversationConstrainedDecoding = false;
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference tool call auto', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/gemma-4-E2B-it.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(modelPath: modelPath, backend: Backend.cpu()),
    );
    final weatherTool = _WeatherTool();
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation(
        ConversationConfig(automaticToolCalling: true, tools: [weatherTool]),
      );
      final response = await conversation.sendMessage(
        Message.user('Use get_weather for Mountain View.'),
      );
      expect(weatherTool.wasExecuted, isTrue);
      expect(weatherTool.lastArguments, isNotNull);
      expect(response.toolCalls, isEmpty);
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('runs inference session', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        maxNumTokens: 10,
      ),
    );
    Session? session;
    try {
      await engine.initialize();
      session = await engine.createSession();
      await session.runPrefill([InputData.text('How are you')]);
      final response = await session.runDecode();
      expect(response.length, greaterThan(5));
    } finally {
      await session?.dispose();
      await engine.dispose();
    }
  });

  testWidgets('checks model capabilities', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      expect(() => Capabilities(modelPath), throwsUnsupportedError);
      return;
    }

    final capabilities = Capabilities(modelPath);
    try {
      expect(capabilities.modelPath, modelPath);
      expect(capabilities.isAlive, isTrue);
      expect(capabilities.hasSpeculativeDecodingSupport(), isA<bool>());
    } finally {
      await capabilities.dispose();
    }
    expect(capabilities.isAlive, isFalse);
  });

  testWidgets('runs benchmark', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    if (kIsWeb) {
      await expectLater(
        benchmark(
          modelPath: modelPath,
          backend: Backend.cpu(),
          prefillTokens: 4,
          decodeTokens: 4,
        ),
        throwsUnsupportedError,
      );
      return;
    }

    final info = await benchmark(
      modelPath: modelPath,
      backend: Backend.cpu(),
      prefillTokens: 4,
      decodeTokens: 4,
    );
    expect(info.initTimeInSecond, greaterThanOrEqualTo(0));
    expect(info.timeToFirstTokenInSecond, greaterThanOrEqualTo(0));
    expect(info.lastPrefillTokenCount, greaterThan(0));
    expect(info.lastDecodeTokenCount, greaterThan(0));
    expect(info.lastPrefillTokensPerSecond, greaterThan(0));
    expect(info.lastDecodeTokensPerSecond, greaterThan(0));
  });

  testWidgets('runs inference channel', (tester) async {
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu(),
        maxNumTokens: 10,
      ),
    );
    const channelConfig = ConversationConfig(
      channels: [Channel(channelName: 'thought', start: 'Ꮝg', end: ' ')],
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        conversation = await engine.createConversation(channelConfig);
        final response = await conversation.sendMessage(
          Message.user('How are you'),
        );
        expect(response.text, 'इक इक इकद्दा');
        expect(response.channels['thought'], 'dockdict');
      } else {
        await expectLater(
          engine.createConversation(channelConfig),
          throwsUnsupportedError,
        );
      }
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  });
}

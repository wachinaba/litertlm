import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:litertlm/litertlm.dart';

class _WeatherTool implements Tool {
  const _WeatherTool();

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
            'units': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['city'],
        },
      },
    };
  }

  @override
  Object? execute(Map<String, Object?> arguments) {
    return {
      'city': arguments['city'],
      'days': [1, 2],
      'custom': DateTime.utc(2026, 1, 2),
    };
  }
}

void main() {
  test('exports log level API', () {
    expect(setMinimumLogLevel, isA<void Function(LogSeverity)>());
    expect(LogSeverity.verbose.value, 0);
    expect(LogSeverity.debug.value, 1);
    expect(LogSeverity.info.value, 2);
    expect(LogSeverity.warning.value, 3);
    expect(LogSeverity.error.value, 4);
    expect(LogSeverity.fatal.value, 5);
    expect(LogSeverity.silent.value, 1000);
  });

  test('exports engine config API', () {
    final config = EngineConfig(modelPath: 'model.litertlm');

    expect(config.backend, const Backend.cpu());
    expect(config.modelPath, 'model.litertlm');
  });

  test('out-of-memory exception is a LiteRtLmException', () {
    const error = LiteRtLmOutOfMemoryException(
      LiteRtLmOperation.conversationCreation,
    );

    expect(error, isA<LiteRtLmException>());
    expect(error, isA<LiteRtLmNativeException>());
    expect(error.code, LiteRtLmNativeException.outOfMemoryCode);
    expect(error.operation, LiteRtLmOperation.conversationCreation);
    expect(error.operation.nativeValue, 1);
  });

  test('native exception retains unknown error codes', () {
    const error = LiteRtLmNativeException(
      'Future native failure.',
      LiteRtLmOperation.sessionCreation,
      code: 42,
    );

    expect(error.code, 42);
    expect(error.operation, LiteRtLmOperation.sessionCreation);
  });

  test('exports experimental flags API', () {
    try {
      ExperimentalFlags.enableBenchmark = true;
      ExperimentalFlags.enableSpeculativeDecoding = false;
      ExperimentalFlags.enableConversationConstrainedDecoding = true;
      ExperimentalFlags.filterChannelContentFromKvCache = true;
      ExperimentalFlags.visualTokenBudget = 280;

      expect(ExperimentalFlags.enableBenchmark, isTrue);
      expect(ExperimentalFlags.enableSpeculativeDecoding, isFalse);
      expect(ExperimentalFlags.enableConversationConstrainedDecoding, isTrue);
      expect(ExperimentalFlags.filterChannelContentFromKvCache, isTrue);
      expect(ExperimentalFlags.visualTokenBudget, 280);

      ExperimentalFlags.enableSpeculativeDecoding = null;
      expect(ExperimentalFlags.enableSpeculativeDecoding, isNull);
      ExperimentalFlags.filterChannelContentFromKvCache = null;
      expect(ExperimentalFlags.filterChannelContentFromKvCache, isNull);
      ExperimentalFlags.visualTokenBudget = null;
      expect(ExperimentalFlags.visualTokenBudget, isNull);
    } finally {
      ExperimentalFlags.enableBenchmark = false;
      ExperimentalFlags.enableSpeculativeDecoding = null;
      ExperimentalFlags.enableConversationConstrainedDecoding = false;
      ExperimentalFlags.filterChannelContentFromKvCache = null;
      ExperimentalFlags.visualTokenBudget = null;
    }
  });

  test('exports callback streaming API', () {
    final messages = <Message>[];
    Object? error;
    var isMessageDone = false;
    var isDone = false;
    final callback = MessageCallback.from(
      onMessage: messages.add,
      onMessageDone: () {
        isMessageDone = true;
      },
      onDone: () {
        isDone = true;
      },
      onError: (callbackError, stackTrace) {
        error = callbackError;
      },
    );

    callback.onMessage(Message.model(contents: Contents.text('hello')));
    callback.onMessageDone();
    callback.onDone();
    expect(callback, isA<MessageCallback>());
    expect(messages.single.text, 'hello');
    expect(isMessageDone, isTrue);
    expect(isDone, isTrue);
    expect(error, isNull);
  });

  test('serializes rich messages', () {
    final message = Message.userContents(
      Contents([
        Content.text('describe this'),
        Content.imageBytes(Uint8List.fromList([1, 2, 3])),
      ]),
    );

    final json = message.toJson();
    expect(json['role'], 'user');
    expect(json['content'], [
      {'type': 'text', 'text': 'describe this'},
      {'type': 'image', 'blob': 'AQID'},
    ]);

    final parsed = Message.fromJson(json);
    expect(parsed.role, Role.user);
    expect(parsed.text, 'describe this');
    expect(parsed.contents.values, hasLength(2));
  });

  test('serializes empty stream sentinel message', () {
    const message = Message();

    expect(message.role, isNull);
    expect(message.isEmpty, isTrue);
    expect(message.toJson(), isEmpty);
    expect(Message.model().isEmpty, isFalse);
    expect(Message.model().toJson(), {'role': 'model'});
  });

  test('serializes conversation preface config', () {
    final config = ConversationConfig(
      systemMessage: Message.system('be concise'),
      initialMessages: [Message.user('hello')],
      extraContext: {'locale': 'en-US'},
      sessionConfig: SessionConfig(
        samplerConfig: SamplerConfig(topK: 8, topP: 0.9, temperature: 0.7),
        loraConfig: LoraConfig(loraPath: 'adapter.bin'),
        maxOutputTokens: 128,
        applyPromptTemplateInSession: false,
      ),
      automaticToolCalling: false,
      prefillPrefaceOnInit: true,
    );

    final json =
        jsonDecode(jsonEncode(config.toJson())) as Map<String, Object?>;
    expect(json['systemMessage'], {
      'role': 'system',
      'content': [
        {'type': 'text', 'text': 'be concise'},
      ],
    });
    expect(json['initialMessages'], isA<List<Object?>>());
    expect(json['extraContext'], {'locale': 'en-US'});
    final sessionConfig = json['sessionConfig'] as Map<String, Object?>;
    expect(sessionConfig['samplerConfig'], {
      'topK': 8,
      'topP': 0.9,
      'temperature': 0.7,
      'seed': 0,
    });
    expect(sessionConfig['loraConfig'], {'loraPath': 'adapter.bin'});
    expect(sessionConfig['maxOutputTokens'], 128);
    expect(sessionConfig['applyPromptTemplateInSession'], false);
    expect(json['automaticToolCalling'], false);
    expect(json['prefillPrefaceOnInit'], true);
  });

  test('serializes session input data', () {
    final json = [
      InputData.text('hello'),
      InputData.imageBytes(Uint8List.fromList([1, 2, 3])),
      InputData.audioBytes(Uint8List.fromList([4, 5])),
    ].map((input) => input.toJson()).toList();

    expect(json, [
      {'type': 'text', 'text': 'hello'},
      {'type': 'image', 'blob': 'AQID'},
      {'type': 'audio', 'blob': 'BAU='},
    ]);
  });

  test('serializes executable tool descriptions', () {
    final manager = ToolManager(tools: [const _WeatherTool()]);

    final json = jsonDecode(manager.toolsJsonDescription) as List<Object?>;
    final tool = json.single as Map<String, Object?>;
    expect(tool['type'], 'function');
    expect(tool['function'], {
      'name': 'get_weather',
      'description': 'Gets the current weather for a city.',
      'parameters': {
        'type': 'object',
        'properties': {
          'city': {'type': 'string', 'description': 'City name.'},
          'units': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['city'],
      },
    });
  });

  test('executes tools and normalizes responses', () async {
    final manager = ToolManager(tools: [const _WeatherTool()]);

    final response = await manager.execute(
      name: 'get_weather',
      arguments: {'city': 'Mountain View'},
    );

    expect(response, {
      'city': 'Mountain View',
      'days': [1, 2],
      'custom': '2026-01-02 00:00:00.000Z',
    });
  });

  test('parses tool-call arguments encoded as object or string', () {
    final objectArguments = ToolCall.fromJson({
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'arguments': {'city': 'Mountain View'},
      },
    });
    final stringArguments = ToolCall.fromJson({
      'type': 'function',
      'function': {'name': 'get_weather', 'arguments': '{"city":"New York"}'},
    });

    expect(objectArguments.arguments, {'city': 'Mountain View'});
    expect(stringArguments.arguments, {'city': 'New York'});
  });
}

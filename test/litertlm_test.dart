import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:litertlm/litertlm.dart';

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

    expect(config.backend, Backend.cpu);
    expect(config.modelPath, 'model.litertlm');
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

  test('serializes conversation preface config', () {
    final config = ConversationConfig(
      systemInstruction: Contents.text('be concise'),
      initialMessages: [Message.user('hello')],
      extraContext: {'locale': 'en-US'},
      sessionConfig: SessionConfig(
        samplerConfig: SamplerConfig(topK: 8, topP: 0.9, temperature: 0.7),
      ),
    );

    final json = jsonDecode(config.toJsonString()) as Map<String, Object?>;
    expect(json['systemInstruction'], [
      {'type': 'text', 'text': 'be concise'},
    ]);
    expect(json['initialMessages'], isA<List<Object?>>());
    expect(json['extraContext'], {'locale': 'en-US'});
    expect(json['sessionConfig'], {
      'samplerConfig': {'topK': 8, 'topP': 0.9, 'temperature': 0.7, 'seed': 0},
    });
  });
}

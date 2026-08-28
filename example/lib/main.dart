import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:litertlm/litertlm.dart';

import 'model/asset.dart';

class LiteRtLmExample {
  static Future<String> run({
    required String modelPath,
    required Backend backend,
    required int maxNumTokens,
    required String message,
  }) async {
    // Create an engine instance with EngineConfig.
    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: backend,
        maxNumTokens: maxNumTokens,
      ),
    );

    final output = <String>[];
    final weatherTool = WeatherTool();
    Conversation? conversation;
    try {
      // Initialize the engine.
      // This step is expected to fail if the engine config is invalid for the device or model.
      await engine.initialize();
      debugPrint('engine.initialize succeeded');
      // Create a conversation.
      conversation = await engine.createConversation(
        ConversationConfig(
          systemMessage: Message.system(
            'You are a concise assistant. Use tools when appropriate.',
          ),
          tools: [weatherTool],
          prefillPrefaceOnInit: true,
        ),
      );
      debugPrint('engine.createConversation succeeded');
      // Send a message and get the response.
      final response = await conversation.sendMessageStateless(
        Message.user(message),
      );
      debugPrint('conversation.sendMessageStateless succeeded');
      int? tokenCount;
      try {
        tokenCount = await conversation.getTokenCount();
      } on UnsupportedError catch (error) {
        debugPrint('Token count is unavailable: $error');
      }
      if (weatherTool.record != null) output.add(weatherTool.record!);
      output.add('response: ${response.text}');
      debugPrint('Response: ${response.text}, token count: $tokenCount');
      return output.join('\n');
    } on LiteRtLmException catch (error) {
      if (weatherTool.record != null) output.add(weatherTool.record!);
      output.add('error: ${error.message}');
      return output.join('\n');
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  }
}

class WeatherTool implements Tool {
  String? record;

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
    final response = {
      'city': arguments['city'],
      'temperature': 72,
      'condition': 'sunny',
    };
    record =
        'tool call: get_weather params=${jsonEncode(arguments)} response=${jsonEncode(response)}';
    return response;
  }
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _messageController = TextEditingController(
    text: 'Get weather for `Seattle`.',
  );
  List<String> _modelAssets = const [];
  String? _modelAsset;
  Backend _backend = Backend.values.first;
  int _maxNumTokens = 16;
  bool _running = false;
  String _response = '';

  @override
  void initState() {
    super.initState();
    _loadModelAssets();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _modelAsset,
                items: [
                  for (final asset in _modelAssets)
                    DropdownMenuItem(value: asset, child: Text(asset)),
                ],
                onChanged: (asset) => setState(() => _modelAsset = asset),
              ),
              const SizedBox(height: 16),
              DropdownButton<Backend>(
                value: _backend,
                items: [
                  for (final backend in Backend.values)
                    DropdownMenuItem(
                      value: backend,
                      child: Text(backend.name.toUpperCase()),
                    ),
                ],
                onChanged: (backend) {
                  if (backend != null) setState(() => _backend = backend);
                },
              ),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: _maxNumTokens,
                items: [
                  for (final value in [16, 256, 1024])
                    DropdownMenuItem(value: value, child: Text('$value')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _maxNumTokens = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(controller: _messageController),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _running ? null : _inference,
                child: const Text('Inference'),
              ),
              const SizedBox(height: 16),
              _running
                  ? const CircularProgressIndicator()
                  : SelectableText(_response),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _inference() async {
    setState(() => _response = '');
    final modelAsset = _modelAsset;
    final message = _messageController.text;
    if (modelAsset == null) {
      setState(() => _response = 'No model asset selected.');
      return;
    }
    if (message.isEmpty) {
      setState(() => _response = 'Message should not be empty.');
      return;
    }

    final modelPath = await resolveModelAssetPath(modelAsset);
    setState(() => _running = true);
    try {
      final response = await compute(
        (args) => LiteRtLmExample.run(
          modelPath: args.$1,
          backend: args.$2,
          maxNumTokens: args.$3,
          message: args.$4,
        ),
        (modelPath, _backend, _maxNumTokens, message),
      );
      setState(() => _response = response);
    } finally {
      setState(() => _running = false);
    }
  }

  Future<void> _loadModelAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets =
        manifest
            .listAssets()
            .where((asset) => asset.endsWith('.litertlm'))
            .toList()
          ..sort();
    setState(() {
      _modelAssets = assets;
      _modelAsset = assets.isEmpty ? null : assets.first;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

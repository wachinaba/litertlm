import 'package:flutter/material.dart';
import 'package:litertlm/litertlm.dart';

import 'model/asset.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hello World!'),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _test, child: Text('Test')),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _test() async {
    setMinimumLogLevel(LogSeverity.verbose);
    final modelPath = await resolveModelAssetPath(
      'assets/models/test_lm.litertlm',
    );

    final engine = Engine(
      engineConfig: EngineConfig(
        modelPath: modelPath,
        backend: Backend.cpu,
        maxNumTokens: 16,
      ),
    );
    Conversation? conversation;
    try {
      await engine.initialize();
      conversation = await engine.createConversation();
      final response = await conversation.sendMessage(Message.user('Hello'));
      debugPrint(response.text);
      final streamedResponse = await conversation
          .sendMessageStream(Message.user('Hello again'))
          .map((message) => message.text)
          .join();
      debugPrint(streamedResponse);
    } finally {
      await conversation?.dispose();
      await engine.dispose();
    }
  }
}

import 'dart:convert';

import '../native/runtime.dart';
import 'config.dart';
import 'exceptions.dart';
import 'message.dart';

part 'conversation.dart';

class Engine {
  Engine({required this.engineConfig})
    : _handle = LiteRtLmNativeRuntime.instance.createEngine(engineConfig);

  final EngineConfig engineConfig;
  final EngineHandle _handle;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      throw const LiteRtLmException('Engine is already initialized.');
    }
    await LiteRtLmNativeRuntime.instance.initializeEngine(_handle);
    _isInitialized = true;
  }

  Future<Conversation> createConversation([
    ConversationConfig conversationConfig = const ConversationConfig(),
  ]) async {
    if (!_isInitialized) {
      throw const LiteRtLmException('Engine is not initialized.');
    }
    final handle = await LiteRtLmNativeRuntime.instance.createConversation(
      _handle,
      conversationConfig,
    );
    return Conversation._(handle);
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      LiteRtLmNativeRuntime.instance.deleteEngine(_handle);
      _isInitialized = false;
    }
  }
}

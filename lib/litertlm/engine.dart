import 'dart:convert';

import '../native/runtime.dart';
import 'config.dart';
import 'exceptions.dart';
import 'message.dart';
import 'tool.dart';

part 'conversation.dart';

/// Manages the lifecycle of a LiteRT-LM engine.
class Engine {
  /// Creates an engine with the given configuration.
  Engine({required this.engineConfig})
    : _handle = LiteRtLmNativeRuntime.instance.createEngine(engineConfig);

  /// The configuration for the engine.
  final EngineConfig engineConfig;
  final EngineHandle _handle;
  bool _isInitialized = false;

  /// Whether the engine is initialized and ready for use.
  bool get isInitialized => _isInitialized;

  /// Initializes the native LiteRT-LM engine.
  Future<void> initialize() async {
    if (_isInitialized) {
      throw const LiteRtLmException('Engine is already initialized.');
    }
    await LiteRtLmNativeRuntime.instance.initializeEngine(_handle);
    _isInitialized = true;
  }

  /// Creates a new conversation from the initialized engine.
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
    return Conversation._(
      handle,
      ToolManager(tools: conversationConfig.tools),
      automaticToolCalling: conversationConfig.automaticToolCalling,
    );
  }

  /// Releases the native LiteRT-LM engine resources.
  Future<void> dispose() async {
    if (_isInitialized) {
      LiteRtLmNativeRuntime.instance.deleteEngine(_handle);
      _isInitialized = false;
    }
  }
}

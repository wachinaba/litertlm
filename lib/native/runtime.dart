import 'io.dart' if (dart.library.js_interop) 'web.dart' as platform;

import '../litertlm/config.dart';
import '../litertlm/message.dart';
import '../litertlm/runtime.dart';

/// Internal bridge implemented by each LiteRT-LM platform runtime.
abstract interface class LiteRtLmNativeRuntime {
  /// Runtime implementation for the current platform.
  static final LiteRtLmNativeRuntime instance = platform.createRuntime();

  /// Creates a native engine handle.
  EngineHandle createEngine(EngineConfig config);

  /// Initializes a native engine.
  Future<void> initializeEngine(EngineHandle engine);

  /// Creates a native conversation handle.
  Future<ConversationHandle> createConversation(
    EngineHandle engine,
    ConversationConfig config,
  );

  /// Sends a message and returns the model response.
  Future<Message> sendMessage(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  });

  /// Sends a message and streams response chunks.
  Stream<Message> sendMessageStream(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  });

  /// Cancels generation for a native conversation.
  void cancelConversation(ConversationHandle conversation);

  /// Gets the number of tokens in the conversation KV Cache.
  Future<int> getTokenCount(ConversationHandle conversation);

  /// Renders a message using the native prompt template.
  Future<String> renderMessageIntoString(
    ConversationHandle conversation,
    String messageJson,
  );

  /// Deletes a native conversation handle.
  void deleteConversation(ConversationHandle conversation);

  /// Deletes a native engine handle.
  void deleteEngine(EngineHandle engine);

  /// Sets the minimum native log severity.
  void setMinimumLogLevel(LogSeverity severity);
}

/// Opaque native engine handle.
abstract interface class EngineHandle {}

/// Opaque native conversation handle.
abstract interface class ConversationHandle {}

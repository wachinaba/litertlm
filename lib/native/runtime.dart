import 'io.dart' if (dart.library.js_interop) 'web.dart' as platform;

import '../litertlm/config.dart';
import '../litertlm/message.dart';
import '../litertlm/runtime.dart';

abstract interface class LiteRtLmNativeRuntime {
  static final LiteRtLmNativeRuntime instance = platform.createRuntime();

  EngineHandle createEngine(EngineConfig config);

  Future<void> initializeEngine(EngineHandle engine);

  Future<ConversationHandle> createConversation(
    EngineHandle engine,
    ConversationConfig config,
  );

  Future<Message> sendMessage(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  });

  Stream<Message> sendMessageStream(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  });

  void cancelConversation(ConversationHandle conversation);

  Future<int> getTokenCount(ConversationHandle conversation);

  Future<String> renderMessageIntoString(
    ConversationHandle conversation,
    String messageJson,
  );

  void deleteConversation(ConversationHandle conversation);

  void deleteEngine(EngineHandle engine);

  void setMinimumLogLevel(LogSeverity severity);
}

abstract interface class EngineHandle {}

abstract interface class ConversationHandle {}

import 'io.dart' if (dart.library.js_interop) 'web.dart' as platform;

import '../litertlm/benchmark.dart';
import '../litertlm/config.dart';
import '../litertlm/message.dart';
import '../litertlm/runtime.dart';
import '../litertlm/session.dart';

/// Internal bridge implemented by each LiteRT-LM platform runtime.
abstract interface class LiteRtLmNativeRuntime {
  /// Runtime implementation for the current platform.
  static final LiteRtLmNativeRuntime instance = platform.createRuntime();

  /// Whether benchmark collection is enabled when creating engines.
  bool get enableBenchmark;

  set enableBenchmark(bool value);

  /// Whether speculative decoding is explicitly enabled for engine creation.
  bool? get enableSpeculativeDecoding;

  set enableSpeculativeDecoding(bool? value);

  /// Whether constrained decoding is enabled when creating conversations.
  bool get enableConversationConstrainedDecoding;

  set enableConversationConstrainedDecoding(bool value);

  /// Whether channel content is filtered from the KV cache.
  bool get filterChannelContentFromKvCache;

  set filterChannelContentFromKvCache(bool value);

  /// The visual token budget.
  int? get visualTokenBudget;

  set visualTokenBudget(int? value);

  /// Creates a native engine handle.
  EngineHandle createEngine(EngineConfig config);

  /// Loads model capability information.
  CapabilitiesHandle createCapabilities(String modelPath);

  /// Checks whether loaded capabilities support speculative decoding.
  bool hasSpeculativeDecodingSupport(CapabilitiesHandle capabilities);

  /// Deletes loaded capability information.
  void deleteCapabilities(CapabilitiesHandle capabilities);

  /// Runs a native benchmark.
  Future<BenchmarkInfo> benchmark(
    EngineConfig config, {
    required int prefillTokens,
    required int decodeTokens,
  });

  /// Initializes a native engine.
  Future<void> initializeEngine(EngineHandle engine);

  /// Creates a native conversation handle.
  Future<ConversationHandle> createConversation(
    EngineHandle engine,
    ConversationConfig config,
  );

  /// Creates a native session handle.
  Future<SessionHandle> createSession(
    EngineHandle engine,
    SessionConfig config,
  );

  /// Sends a message and returns the model response.
  Future<Message> sendMessage(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  });

  /// Sends a message and streams response chunks to a callback.
  Future<void> sendMessageWithCallback(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
    required void Function(Message message) onMessage,
    required void Function() onDone,
    required void Function(Object error, StackTrace stackTrace) onError,
  });

  /// Cancels generation for a native conversation.
  void cancelConversation(ConversationHandle conversation);

  /// Runs session prefill.
  Future<void> runSessionPrefill(
    SessionHandle session,
    List<InputData> inputData,
  );

  /// Runs session decode.
  Future<String> runSessionDecode(SessionHandle session);

  /// Generates session content.
  Future<String> generateSessionContent(
    SessionHandle session,
    List<InputData> inputData,
  );

  /// Generates session content as a text stream.
  Stream<String> generateSessionContentStream(
    SessionHandle session,
    List<InputData> inputData,
  );

  /// Cancels generation for a native session.
  void cancelSession(SessionHandle session);

  /// Gets the number of tokens in the conversation KV Cache.
  Future<int> getTokenCount(ConversationHandle conversation);

  /// Gets benchmark information from a native conversation.
  Future<BenchmarkInfo> getBenchmarkInfo(ConversationHandle conversation);

  /// Renders a message using the native prompt template.
  Future<String> renderMessageIntoString(
    ConversationHandle conversation,
    String messageJson,
  );

  /// Deletes a native conversation handle.
  void deleteConversation(ConversationHandle conversation);

  /// Deletes a native session handle.
  void deleteSession(SessionHandle session);

  /// Deletes a native engine handle.
  void deleteEngine(EngineHandle engine);

  /// Sets the minimum native log severity.
  void setMinimumLogLevel(LogSeverity severity);
}

/// Opaque native engine handle.
abstract interface class EngineHandle {}

/// Opaque native capabilities handle.
abstract interface class CapabilitiesHandle {}

/// Opaque native conversation handle.
abstract interface class ConversationHandle {}

/// Opaque native session handle.
abstract interface class SessionHandle {}

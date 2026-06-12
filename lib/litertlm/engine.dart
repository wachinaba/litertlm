import 'dart:async';
import 'dart:convert';

import '../native/runtime.dart';
import 'benchmark.dart';
import 'config.dart';
import 'exceptions.dart';
import 'message.dart';
import 'session.dart';
import 'tool.dart';

const _recurringToolCallLimit = 25;

/// Receives chunks from callback-style conversation streaming.
abstract interface class MessageCallback {
  /// Creates a callback from individual lifecycle handlers.
  factory MessageCallback.from({
    required void Function(Message message) onMessage,
    required void Function() onDone,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    return _ForwardingMessageCallback(
      onMessage: onMessage,
      onDone: onDone,
      onError: onError,
    );
  }

  /// Called for each streamed message chunk.
  void onMessage(Message message);

  /// Called when the stream finishes successfully.
  void onDone();

  /// Called when the stream fails.
  void onError(Object error, StackTrace stackTrace);
}

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

  /// Creates a new lower-level session from the initialized engine.
  Future<Session> createSession([
    SessionConfig sessionConfig = const SessionConfig(),
  ]) async {
    if (!_isInitialized) {
      throw const LiteRtLmException('Engine is not initialized.');
    }
    final handle = await LiteRtLmNativeRuntime.instance.createSession(
      _handle,
      sessionConfig,
    );
    return Session._(handle);
  }

  /// Releases the native LiteRT-LM engine resources.
  Future<void> dispose() async {
    if (_isInitialized) {
      LiteRtLmNativeRuntime.instance.deleteEngine(_handle);
      _isInitialized = false;
    }
  }
}

/// Represents a conversation with the LiteRT-LM model.
class Conversation {
  Conversation._(
    this._handle,
    this._toolManager, {
    required this._automaticToolCalling,
  });

  ConversationHandle? _handle;
  final ToolManager _toolManager;
  final bool _automaticToolCalling;

  /// Whether the conversation is alive and ready to be used.
  bool get isAlive => _handle != null;

  /// Sends a message to the conversation and returns the response.
  Future<Message> sendMessage(
    Message message, {
    Map<String, Object?>? extraContext,
  }) async {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    final extraContextJson = extraContext == null || extraContext.isEmpty
        ? null
        : jsonEncode(extraContext);
    var currentMessage = message;
    for (var round = 0; round < _recurringToolCallLimit; round += 1) {
      final response = await LiteRtLmNativeRuntime.instance.sendMessage(
        handle,
        jsonEncode(currentMessage.toJson()),
        extraContextJson: extraContextJson,
      );
      if (!_automaticToolCalling || response.toolCalls.isEmpty) {
        return response;
      }
      currentMessage = await _handleToolCalls(response.toolCalls);
    }
    throw const LiteRtLmException(
      'Recurring tool call limit exceeded: $_recurringToolCallLimit.',
    );
  }

  /// Sends a message to the conversation and streams the response.
  Stream<Message> sendMessageStream(
    Message message, {
    Map<String, Object?>? extraContext,
  }) {
    late StreamController<Message> controller;
    var isCanceled = false;

    controller = StreamController<Message>(
      onListen: () {
        sendMessageWithCallback(
          message,
          _ForwardingMessageCallback(
            onMessage: (chunk) {
              if (!isCanceled) {
                controller.add(chunk);
              }
            },
            onDone: () {
              if (!isCanceled) {
                unawaited(controller.close());
              }
            },
            onError: (error, stackTrace) {
              if (!isCanceled) {
                controller.addError(error, stackTrace);
                unawaited(controller.close());
              }
            },
          ),
          extraContext: extraContext,
        ).ignore();
      },
      onCancel: () async {
        isCanceled = true;
        await cancel();
      },
    );

    return controller.stream;
  }

  /// Sends a message to the conversation and streams chunks to [callback].
  Future<void> sendMessageWithCallback(
    Message message,
    MessageCallback callback, {
    Map<String, Object?>? extraContext,
  }) async {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    final extraContextJson = extraContext == null || extraContext.isEmpty
        ? null
        : jsonEncode(extraContext);
    final controller = _ToolCallingMessageCallback(
      handle: handle,
      userCallback: callback,
      handleToolCalls: _handleToolCalls,
      automaticToolCalling: _automaticToolCalling,
      extraContextJson: extraContextJson,
    );
    return controller.send(message);
  }

  Future<Message> _handleToolCalls(List<ToolCall> toolCalls) async {
    final responses = <Content>[];
    for (final toolCall in toolCalls) {
      try {
        final result = await _toolManager.execute(
          name: toolCall.name,
          arguments: toolCall.arguments,
        );
        responses.add(
          Content.toolResponse(name: toolCall.name, response: result),
        );
      } catch (error) {
        throw LiteRtLmException(
          'Tool "${toolCall.name}" execution failed: $error',
        );
      }
    }
    return Message.tool(Contents(responses));
  }

  /// Gets the number of tokens in the conversation KV Cache.
  Future<int> getTokenCount() {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.getTokenCount(handle);
  }

  /// Gets benchmark information from the conversation.
  Future<BenchmarkInfo> getBenchmarkInfo() {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.getBenchmarkInfo(handle);
  }

  /// Renders the message into a string according to the template.
  Future<String> renderMessageIntoString(Message message) {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.renderMessageIntoString(
      handle,
      jsonEncode(message.toJson()),
    );
  }

  /// Cancels the ongoing inference process.
  Future<void> cancel() async {
    final handle = _handle;
    if (handle != null) {
      LiteRtLmNativeRuntime.instance.cancelConversation(handle);
    }
  }

  /// Releases the native conversation resources.
  Future<void> dispose() async {
    final handle = _handle;
    if (handle != null) {
      LiteRtLmNativeRuntime.instance.deleteConversation(handle);
      _handle = null;
    }
  }
}

class _ForwardingMessageCallback implements MessageCallback {
  const _ForwardingMessageCallback({
    required this._onMessage,
    required this._onDone,
    required this._onError,
  });

  final void Function(Message message) _onMessage;
  final void Function() _onDone;
  final void Function(Object error, StackTrace stackTrace) _onError;

  @override
  void onMessage(Message message) {
    _onMessage(message);
  }

  @override
  void onDone() {
    _onDone();
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    _onError(error, stackTrace);
  }
}

class _ToolCallingMessageCallback {
  _ToolCallingMessageCallback({
    required this.handle,
    required this.userCallback,
    required this.handleToolCalls,
    required this.automaticToolCalling,
    required this.extraContextJson,
  });

  final ConversationHandle handle;
  final MessageCallback userCallback;
  final Future<Message> Function(List<ToolCall> toolCalls) handleToolCalls;
  final bool automaticToolCalling;
  final String? extraContextJson;
  final Completer<void> _done = Completer<void>();
  List<ToolCall>? _pendingToolCalls;
  var _toolCallCount = 0;
  var _reportedError = false;

  Future<void> send(Message message) {
    _send(message);
    return _done.future;
  }

  void _send(Message message) {
    if (_done.isCompleted) return;
    unawaited(_sendAsync(message));
  }

  Future<void> _sendAsync(Message message) async {
    try {
      await LiteRtLmNativeRuntime.instance.sendMessageWithCallback(
        handle,
        jsonEncode(message.toJson()),
        extraContextJson: extraContextJson,
        onMessage: _onMessage,
        onDone: _onDone,
        onError: _onError,
      );
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  void _onMessage(Message message) {
    if (_done.isCompleted) return;
    if (automaticToolCalling && message.toolCalls.isNotEmpty) {
      if (_toolCallCount >= _recurringToolCallLimit) {
        _onError(
          const LiteRtLmException(
            'Recurring tool call limit exceeded: $_recurringToolCallLimit.',
          ),
          StackTrace.current,
        );
        return;
      }
      _toolCallCount += 1;
      _pendingToolCalls = message.toolCalls;
      return;
    }
    if (!automaticToolCalling ||
        !message.contents.isEmpty ||
        message.channels.isNotEmpty) {
      userCallback.onMessage(message);
    }
  }

  void _onDone() {
    if (_done.isCompleted) return;
    final pendingToolCalls = _pendingToolCalls;
    if (pendingToolCalls != null) {
      _pendingToolCalls = null;
      unawaited(_sendToolResponse(pendingToolCalls));
      return;
    }
    try {
      userCallback.onDone();
      _done.complete();
    } catch (error, stackTrace) {
      _done.completeError(error, stackTrace);
    }
  }

  Future<void> _sendToolResponse(List<ToolCall> toolCalls) async {
    try {
      _send(await handleToolCalls(toolCalls));
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (_reportedError) return;
    _reportedError = true;
    if (!_done.isCompleted) {
      try {
        userCallback.onError(error, stackTrace);
        _done.completeError(error, stackTrace);
      } catch (callbackError, callbackStackTrace) {
        _done.completeError(callbackError, callbackStackTrace);
      }
    }
  }
}

/// Lower-level LiteRT-LM session API.
class Session {
  Session._(this._handle);

  SessionHandle? _handle;

  /// Whether the session is alive and ready to use.
  bool get isAlive => _handle != null;

  /// Runs the prefill step for the given input data.
  Future<void> runPrefill(List<InputData> inputData) {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Session is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.runSessionPrefill(handle, inputData);
  }

  /// Runs the decode step and returns the generated text.
  Future<String> runDecode() {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Session is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.runSessionDecode(handle);
  }

  /// Generates content from the given input data.
  Future<String> generateContent(List<InputData> inputData) {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Session is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.generateSessionContent(
      handle,
      inputData,
    );
  }

  /// Generates content from the given input data and streams text chunks.
  Stream<String> generateContentStream(List<InputData> inputData) {
    final handle = _handle;
    if (handle == null) {
      return Stream.error(
        const LiteRtLmException('Session is already disposed.'),
      );
    }
    return LiteRtLmNativeRuntime.instance.generateSessionContentStream(
      handle,
      inputData,
    );
  }

  /// Cancels any ongoing session processing.
  void cancelProcess() {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Session is already disposed.');
    }
    LiteRtLmNativeRuntime.instance.cancelSession(handle);
  }

  /// Releases native session resources.
  Future<void> dispose() async {
    final handle = _handle;
    if (handle != null) {
      LiteRtLmNativeRuntime.instance.deleteSession(handle);
      _handle = null;
    }
  }
}

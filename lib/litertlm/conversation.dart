part of 'engine.dart';

const _recurringToolCallLimit = 25;

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
        currentMessage.toJsonString(),
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
  }) async* {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    final extraContextJson = extraContext == null || extraContext.isEmpty
        ? null
        : jsonEncode(extraContext);
    var currentMessage = message;
    for (var round = 0; round < _recurringToolCallLimit; round += 1) {
      final pendingToolCalls = <ToolCall>[];
      await for (final chunk
          in LiteRtLmNativeRuntime.instance.sendMessageStream(
            handle,
            currentMessage.toJsonString(),
            extraContextJson: extraContextJson,
          )) {
        if (_automaticToolCalling && chunk.toolCalls.isNotEmpty) {
          pendingToolCalls.addAll(chunk.toolCalls);
        }
        if (!_automaticToolCalling ||
            !chunk.contents.isEmpty ||
            chunk.channels.isNotEmpty) {
          yield chunk;
        }
      }

      if (!_automaticToolCalling || pendingToolCalls.isEmpty) {
        return;
      }
      currentMessage = await _handleToolCalls(pendingToolCalls);
    }
    throw const LiteRtLmException(
      'Recurring tool call limit exceeded: $_recurringToolCallLimit.',
    );
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

  /// Renders the message into a string according to the template.
  Future<String> renderMessageIntoString(Message message) {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.renderMessageIntoString(
      handle,
      message.toJsonString(),
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

part of 'engine.dart';

class Conversation {
  Conversation._(this._handle);

  ConversationHandle? _handle;

  bool get isAlive => _handle != null;

  Future<Message> sendMessage(
    Message message, {
    Map<String, Object?>? extraContext,
  }) {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    final extraContextJson = extraContext == null || extraContext.isEmpty
        ? null
        : jsonEncode(extraContext);
    return LiteRtLmNativeRuntime.instance.sendMessage(
      handle,
      message.toJsonString(),
      extraContextJson: extraContextJson,
    );
  }

  Stream<Message> sendMessageStream(
    Message message, {
    Map<String, Object?>? extraContext,
  }) {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    final extraContextJson = extraContext == null || extraContext.isEmpty
        ? null
        : jsonEncode(extraContext);
    return LiteRtLmNativeRuntime.instance.sendMessageStream(
      handle,
      message.toJsonString(),
      extraContextJson: extraContextJson,
    );
  }

  Future<int> getTokenCount() {
    final handle = _handle;
    if (handle == null) {
      throw const LiteRtLmException('Conversation is already disposed.');
    }
    return LiteRtLmNativeRuntime.instance.getTokenCount(handle);
  }

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

  Future<void> cancel() async {
    final handle = _handle;
    if (handle != null) {
      LiteRtLmNativeRuntime.instance.cancelConversation(handle);
    }
  }

  Future<void> dispose() async {
    final handle = _handle;
    if (handle != null) {
      LiteRtLmNativeRuntime.instance.deleteConversation(handle);
      _handle = null;
    }
  }
}

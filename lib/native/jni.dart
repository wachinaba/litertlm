// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:jni/_internal.dart' as jni_internal;
import 'package:jni/jni.dart';

import '../litertlm/config.dart';
import '../litertlm/exceptions.dart';
import '../litertlm/message.dart';
import '../litertlm/runtime.dart';
import 'runtime.dart';

class LiteRtLmJniRuntime implements LiteRtLmNativeRuntime {
  final _class = JClass.forName('org/rockstudio/litertlm/LiteRtLmJniBridge');

  late final _createEngine = _class.staticMethodId(
    'createEngine',
    '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;)Lcom/google/ai/edge/litertlm/Engine;',
  );
  late final _initializeEngine = _class.staticMethodId(
    'initializeEngine',
    '(Lcom/google/ai/edge/litertlm/Engine;)V',
  );
  late final _deleteEngine = _class.staticMethodId(
    'deleteEngine',
    '(Lcom/google/ai/edge/litertlm/Engine;)V',
  );
  late final _createConversation = _class.staticMethodId(
    'createConversation',
    '(Lcom/google/ai/edge/litertlm/Engine;Ljava/lang/String;)Lcom/google/ai/edge/litertlm/Conversation;',
  );
  late final _sendMessage = _class.staticMethodId(
    'sendMessage',
    '(Lcom/google/ai/edge/litertlm/Conversation;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;',
  );
  late final _sendMessageStream = _class.staticMethodId(
    'sendMessageStream',
    '(Lcom/google/ai/edge/litertlm/Conversation;Ljava/lang/String;Ljava/lang/String;Lcom/google/ai/edge/litertlm/MessageCallback;)V',
  );
  late final _messageToJson = _class.staticMethodId(
    'messageToJson',
    '(Lcom/google/ai/edge/litertlm/Message;)Ljava/lang/String;',
  );
  late final _cancelConversation = _class.staticMethodId(
    'cancelConversation',
    '(Lcom/google/ai/edge/litertlm/Conversation;)V',
  );
  late final _getTokenCount = _class.staticMethodId(
    'getTokenCount',
    '(Lcom/google/ai/edge/litertlm/Conversation;)I',
  );
  late final _renderMessageToString = _class.staticMethodId(
    'renderMessageToString',
    '(Lcom/google/ai/edge/litertlm/Conversation;Ljava/lang/String;)Ljava/lang/String;',
  );
  late final _deleteConversation = _class.staticMethodId(
    'deleteConversation',
    '(Lcom/google/ai/edge/litertlm/Conversation;)V',
  );

  late final _setMinimumLogLevel = _class.staticMethodId(
    'setMinimumLogLevel',
    '(I)V',
  );

  @override
  EngineHandle createEngine(EngineConfig config) {
    final modelPath = config.modelPath.toJString();
    final backend = config.backend.name.toJString();
    final visionBackend = (config.visionBackend?.name ?? '').toJString();
    final audioBackend = (config.audioBackend?.name ?? '').toJString();
    final cacheDir = (config.cacheDir ?? '').toJString();
    try {
      return _JniEngineHandle(
        _createEngine.call(_class, JObject.type, [
          modelPath,
          backend,
          visionBackend,
          audioBackend,
          JValueInt(config.maxNumTokens ?? _unsetInt),
          cacheDir,
        ]),
      );
    } finally {
      modelPath.release();
      backend.release();
      visionBackend.release();
      audioBackend.release();
      cacheDir.release();
    }
  }

  @override
  Future<void> initializeEngine(EngineHandle engine) async {
    final jniEngine = engine as _JniEngineHandle;
    _initializeEngine.call(_class, jvoid.type, [jniEngine.engine]);
  }

  @override
  Future<ConversationHandle> createConversation(
    EngineHandle engine,
    ConversationConfig config,
  ) async {
    final jniEngine = engine as _JniEngineHandle;
    final configJson = config.toJsonString().toJString();
    try {
      return _JniConversationHandle(
        _createConversation.call(_class, JObject.type, [
          jniEngine.engine,
          configJson,
        ]),
      );
    } finally {
      configJson.release();
    }
  }

  @override
  Future<Message> sendMessage(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  }) async {
    final jniConversation = conversation as _JniConversationHandle;
    final message = messageJson.toJString();
    final extraContext = (extraContextJson ?? '').toJString();
    try {
      final response = _sendMessage
          .call(_class, JString.type, [
            jniConversation.conversation,
            message,
            extraContext,
          ])
          .toDartString(releaseOriginal: true);
      return Message.fromJsonString(response);
    } finally {
      message.release();
      extraContext.release();
    }
  }

  @override
  Stream<Message> sendMessageStream(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  }) {
    final jniConversation = conversation as _JniConversationHandle;
    JObject? streamCallback;
    late StreamController<Message> controller;

    controller = StreamController<Message>(
      onListen: () {
        streamCallback = _MessageCallback.implement(
          _MessageCallbackImplementation(
            onMessage: (message) {
              final messageJson = _messageToJson
                  .call(_class, JString.type, [message])
                  .toDartString(releaseOriginal: true);
              controller.add(Message.fromJsonString(messageJson));
            },
            onDone: () {
              unawaited(controller.close());
              streamCallback?.release();
              streamCallback = null;
            },
            onError: (throwable) {
              controller.addError(LiteRtLmException(throwable.toString()));
              unawaited(controller.close());
              streamCallback?.release();
              streamCallback = null;
            },
          ),
        );
        final message = messageJson.toJString();
        final extraContext = (extraContextJson ?? '').toJString();
        try {
          _sendMessageStream.call(_class, jvoid.type, [
            jniConversation.conversation,
            message,
            extraContext,
            streamCallback,
          ]);
        } catch (error) {
          streamCallback?.release();
          streamCallback = null;
          controller.addError(error);
          unawaited(controller.close());
        } finally {
          message.release();
          extraContext.release();
        }
      },
      onCancel: () {
        if (streamCallback != null) {
          _cancelConversation.call(_class, jvoid.type, [
            jniConversation.conversation,
          ]);
          streamCallback?.release();
          streamCallback = null;
        }
      },
    );

    return controller.stream;
  }

  @override
  void cancelConversation(ConversationHandle conversation) {
    final jniConversation = conversation as _JniConversationHandle;
    _cancelConversation.call(_class, jvoid.type, [
      jniConversation.conversation,
    ]);
  }

  @override
  Future<int> getTokenCount(ConversationHandle conversation) async {
    final jniConversation = conversation as _JniConversationHandle;
    return _getTokenCount.call(_class, jint.type, [
      jniConversation.conversation,
    ]);
  }

  @override
  Future<String> renderMessageIntoString(
    ConversationHandle conversation,
    String messageJson,
  ) async {
    final jniConversation = conversation as _JniConversationHandle;
    final message = messageJson.toJString();
    try {
      return _renderMessageToString
          .call(_class, JString.type, [jniConversation.conversation, message])
          .toDartString(releaseOriginal: true);
    } finally {
      message.release();
    }
  }

  @override
  void deleteConversation(ConversationHandle conversation) {
    final jniConversation = conversation as _JniConversationHandle;
    _deleteConversation.call(_class, jvoid.type, [
      jniConversation.conversation,
    ]);
    jniConversation.conversation.release();
  }

  @override
  void deleteEngine(EngineHandle engine) {
    final jniEngine = engine as _JniEngineHandle;
    _deleteEngine.call(_class, jvoid.type, [jniEngine.engine]);
    jniEngine.engine.release();
  }

  @override
  void setMinimumLogLevel(LogSeverity severity) {
    _setMinimumLogLevel.call(_class, jvoid.type, [JValueInt(severity.value)]);
  }
}

class _JniEngineHandle implements EngineHandle {
  _JniEngineHandle(this.engine);

  final JObject engine;
}

class _JniConversationHandle implements ConversationHandle {
  _JniConversationHandle(this.conversation);

  final JObject conversation;
}

class _MessageCallback extends JObject {
  _MessageCallback.fromReference(super.reference) : super.fromReference();

  static JObject implement(_MessageCallbackImplementation implementation) {
    final implementer = JImplementer();
    implementIn(implementer, implementation);
    return implementer.implement<JObject>();
  }

  static final _implementations = <int, _MessageCallbackImplementation>{};

  static jni_internal.JObjectPtr _invoke(
    int port,
    jni_internal.JObjectPtr descriptor,
    jni_internal.JObjectPtr args,
  ) {
    return _invokeMethod(
      port,
      jni_internal.MethodInvocation.fromAddresses(
        0,
        descriptor.address,
        args.address,
      ),
    );
  }

  static final jni_internal.Pointer<
    jni_internal.NativeFunction<
      jni_internal.JObjectPtr Function(
        jni_internal.Int64,
        jni_internal.JObjectPtr,
        jni_internal.JObjectPtr,
      )
    >
  >
  _invokePointer = jni_internal.Pointer.fromFunction(_invoke);

  static jni_internal.JObjectPtr _invokeMethod(
    int port,
    jni_internal.MethodInvocation invocation,
  ) {
    try {
      final descriptor = invocation.methodDescriptor.toDartString(
        releaseOriginal: true,
      );
      final args = invocation.args;
      final implementation = _implementations[port]!;

      if (descriptor == r'onMessage(Lcom/google/ai/edge/litertlm/Message;)V') {
        implementation.onMessage(args![0]!);
        return jni_internal.nullptr;
      }
      if (descriptor == r'onDone()V') {
        implementation.onDone();
        return jni_internal.nullptr;
      }
      if (descriptor == r'onError(Ljava/lang/Throwable;)V') {
        implementation.onError(args![0]!);
        return jni_internal.nullptr;
      }
      throw LiteRtLmException('Unknown MessageCallback method: $descriptor');
    } catch (error) {
      return jni_internal.ProtectedJniExtensions.newDartException(error);
    }
  }

  static void implementIn(
    JImplementer implementer,
    _MessageCallbackImplementation implementation,
  ) {
    late final jni_internal.RawReceivePort port;
    port = jni_internal.RawReceivePort((message) {
      if (message == null) {
        _implementations.remove(port.sendPort.nativePort);
        port.close();
        return;
      }
      final invocation = jni_internal.MethodInvocation.fromMessage(message);
      final result = _invokeMethod(port.sendPort.nativePort, invocation);
      jni_internal.ProtectedJniExtensions.returnResult(
        invocation.result,
        result,
      );
    });
    implementer.add(
      'com.google.ai.edge.litertlm.MessageCallback',
      port,
      _invokePointer,
      const [
        r'onMessage(Lcom/google/ai/edge/litertlm/Message;)V',
        r'onDone()V',
        r'onError(Ljava/lang/Throwable;)V',
      ],
    );
    _implementations[port.sendPort.nativePort] = implementation;
  }
}

class _MessageCallbackImplementation {
  _MessageCallbackImplementation({
    required this.onMessage,
    required this.onDone,
    required this.onError,
  });

  final void Function(JObject message) onMessage;
  final void Function() onDone;
  final void Function(JObject throwable) onError;
}

const _unsetInt = -0x80000000;

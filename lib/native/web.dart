import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../litertlm/config.dart';
import '../litertlm/exceptions.dart';
import '../litertlm/message.dart';
import '../litertlm/runtime.dart';
import '../litertlm/tool.dart';
import 'runtime.dart';

const _sdkModuleUrl =
    'https://cdn.jsdelivr.net/npm/@litert-lm/core@0.13.1/+esm';
const _sdkLoadTimeout = Duration(seconds: 30);
const _samplerTypeTopP = 2;

LiteRtLmNativeRuntime createRuntime() => LiteRtLmWebRuntime();

class LiteRtLmWebRuntime implements LiteRtLmNativeRuntime {
  Future<JSObject>? _sdkModule;

  @override
  EngineHandle createEngine(EngineConfig config) {
    final jsEngine = _loadSdk()
        .timeout(
          _sdkLoadTimeout,
          onTimeout: () => throw const LiteRtLmException(
            'Timed out loading the LiteRT-LM JS SDK.',
          ),
        )
        .then((sdk) {
          final settings = <String, Object?>{
            'model': config.modelPath,
            'backend': _backendValue(sdk, config.backend),
          };

          final maxNumTokens = config.maxNumTokens;
          if (maxNumTokens != null) {
            settings['mainExecutorSettings'] = {'maxNumTokens': maxNumTokens};
          }

          final engineConstructor = sdk.getProperty<JSObject>('Engine'.toJS);
          return _promiseToFuture<JSObject>(
            engineConstructor.callMethod<JSPromise<JSObject>>(
              'create'.toJS,
              _parseJson(jsonEncode(settings)),
            ),
          );
        });
    return _WebEngineHandle(jsEngine);
  }

  @override
  Future<void> initializeEngine(EngineHandle engine) async {
    await (engine as _WebEngineHandle).engine;
  }

  @override
  Future<ConversationHandle> createConversation(
    EngineHandle engine,
    ConversationConfig config,
  ) async {
    final jsEngine = await (engine as _WebEngineHandle).engine;
    final jsConfig = _conversationConfigToJs(config);
    final conversation = await _promiseToFuture<JSObject>(
      jsEngine.callMethod<JSPromise<JSObject>>(
        'createConversation'.toJS,
        jsConfig,
      ),
    );
    return _WebConversationHandle(conversation);
  }

  @override
  Future<Message> sendMessage(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  }) async {
    if (extraContextJson != null) {
      throw UnsupportedError(
        'Per-message extraContext is not supported by the LiteRT-LM JS SDK. '
        'Use ConversationConfig.extraContext on web.',
      );
    }
    final jsConversation = conversation as _WebConversationHandle;
    final response = await _promiseToFuture<JSObject>(
      jsConversation.conversation.callMethod<JSPromise<JSObject>>(
        'sendMessage'.toJS,
        _parseJson(messageJson),
      ),
    );
    return Message.fromJsonString(_stringifyJson(response));
  }

  @override
  Stream<Message> sendMessageStream(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  }) {
    if (extraContextJson != null) {
      return Stream.error(
        UnsupportedError(
          'Per-message extraContext is not supported by the LiteRT-LM JS SDK. '
          'Use ConversationConfig.extraContext on web.',
        ),
      );
    }
    final jsConversation = conversation as _WebConversationHandle;
    late StreamController<Message> controller;
    JSObject? streamCallback;

    controller = StreamController<Message>(
      onListen: () {
        final onChunk = ((JSAny chunk) {
          controller.add(Message.fromJsonString(_stringifyJson(chunk)));
        }).toJS;
        final onError = ((JSAny error) {
          controller.addError(LiteRtLmException(error.toString()));
          unawaited(controller.close());
        }).toJS;
        final onDone = (() {
          unawaited(controller.close());
        }).toJS;

        streamCallback = _startMessageStream(
          jsConversation.conversation,
          _parseJson(messageJson),
          onChunk,
          onError,
          onDone,
        );
      },
      onCancel: () {
        final callback = streamCallback;
        if (callback != null) {
          callback.callMethod<JSAny?>('cancel'.toJS);
        }
        return null;
      },
    );

    return controller.stream;
  }

  @override
  void cancelConversation(ConversationHandle conversation) {
    final handle = conversation as _WebConversationHandle;
    handle.conversation.callMethod<JSAny?>('cancel'.toJS);
  }

  @override
  Future<int> getTokenCount(ConversationHandle conversation) async {
    final handle = conversation as _WebConversationHandle;
    final tokenCount = await _promiseToFuture<JSNumber>(
      handle.conversation.callMethod<JSPromise<JSNumber>>('getTokenCount'.toJS),
    );
    return tokenCount.toDartInt;
  }

  @override
  Future<String> renderMessageIntoString(
    ConversationHandle conversation,
    String messageJson,
  ) async {
    throw UnsupportedError(
      'renderMessageIntoString is not supported by the LiteRT-LM JS SDK.',
    );
  }

  @override
  void deleteConversation(ConversationHandle conversation) {
    final handle = conversation as _WebConversationHandle;
    _ignoreJsPromise(handle.conversation.callMethod<JSAny?>('delete'.toJS));
  }

  @override
  void deleteEngine(EngineHandle engine) {
    final handle = engine as _WebEngineHandle;
    unawaited(
      handle.engine.then((jsEngine) {
        _ignoreJsPromise(jsEngine.callMethod<JSAny?>('delete'.toJS));
      }),
    );
  }

  @override
  void setMinimumLogLevel(LogSeverity severity) {
    throw UnsupportedError(
      'setMinimumLogLevel is not supported on web because the LiteRT-LM JS SDK '
      'does not expose log-level configuration.',
    );
  }

  Future<JSObject> _loadSdk() {
    final existing = globalContext.getProperty<JSObject?>('litertlm'.toJS);
    if (existing != null) {
      return Future.value(existing);
    }

    return _sdkModule ??= _importSdkModule();
  }

  Future<JSObject> _importSdkModule() async {
    final importer = _newFunction(
      'specifier'.toJS,
      '''
const timeoutMs = ${_sdkLoadTimeout.inMilliseconds};
return Promise.race([
  import(specifier),
  new Promise((_, reject) => setTimeout(
    () => reject(new Error(
      'Timed out importing ' + specifier + ' after ' + timeoutMs + 'ms'
    )),
    timeoutMs
  )),
]);
'''
          .toJS,
    );
    return _promiseToFuture<JSObject>(
      importer.callAsFunction(null, _sdkModuleUrl.toJS) as JSPromise<JSObject>,
    );
  }

  int _backendValue(JSObject sdk, Backend backend) {
    final backends = sdk.getProperty<JSObject>('Backend'.toJS);
    return switch (backend) {
      Backend.cpu => backends.getProperty<JSNumber>('CPU'.toJS).toDartInt,
      Backend.gpu =>
        backends.getProperty<JSNumber>('GPU_ARTISAN'.toJS).toDartInt,
      Backend.npu => throw UnsupportedError(
        'NPU backend is not supported by the LiteRT-LM JS SDK.',
      ),
    };
  }

  JSObject _parseJson(String value) {
    final json = globalContext.getProperty<JSObject>('JSON'.toJS);
    return json.callMethod<JSObject>('parse'.toJS, value.toJS);
  }

  JSObject _conversationConfigToJs(ConversationConfig config) {
    final sessionConfig = <String, Object?>{};
    final dartSessionConfig = config.sessionConfig;
    final loraConfig = dartSessionConfig?.loraConfig;
    if (loraConfig != null &&
        (loraConfig.loraPath != null || loraConfig.audioLoraPath != null)) {
      throw UnsupportedError(
        'LoRA config is not supported by the LiteRT-LM JS SDK.',
      );
    }

    final samplerConfig = dartSessionConfig?.samplerConfig;
    if (samplerConfig != null) {
      sessionConfig['samplerParams'] = {
        'type': _samplerTypeTopP,
        'k': samplerConfig.topK,
        'p': samplerConfig.topP,
        'temperature': samplerConfig.temperature,
        'seed': samplerConfig.seed,
      };
    }
    final jsConfig = <String, Object?>{'sessionConfig': sessionConfig};
    final preface = <String, Object?>{};
    final messages = <Object?>[
      if (config.systemInstruction != null)
        Message.systemContents(config.systemInstruction!).toJson(),
      ...config.initialMessages.map((message) => message.toJson()),
    ];
    if (messages.isNotEmpty) {
      preface['messages'] = messages;
    }
    final tools = _toolDescriptionsForPreface(config.tools);
    if (tools.isNotEmpty) {
      preface['tools'] = tools;
    }
    if (config.extraContext.isNotEmpty) {
      preface['extraContext'] = config.extraContext;
    }
    if (preface.isNotEmpty) {
      jsConfig['preface'] = preface;
    }
    return _parseJson(jsonEncode(jsConfig));
  }

  List<Object?> _toolDescriptionsForPreface(List<Tool> tools) {
    return tools.map((tool) {
      final json = tool.toJson();
      final function = json['function'];
      if (function is Map<String, Object?>) {
        return {
          'name': function['name'],
          if (function['description'] != null) 'description': function['description'],
          if (function['parameters'] != null) 'parameters': function['parameters'],
        };
      }
      return json;
    }).toList(growable: false);
  }

  String _stringifyJson(JSAny value) {
    final json = globalContext.getProperty<JSObject>('JSON'.toJS);
    return json.callMethod<JSString>('stringify'.toJS, value).toDart;
  }

  Future<T> _promiseToFuture<T extends JSAny?>(JSPromise<T> promise) async {
    try {
      return await promise.toDart;
    } catch (error) {
      throw LiteRtLmException(error.toString());
    }
  }

  void _ignoreJsPromise(JSAny? value) {
    if (value is JSPromise<JSAny?>) {
      unawaited(_promiseToFuture<JSAny?>(value).catchError((_) => null));
    }
  }

  JSObject _startMessageStream(
    JSObject conversation,
    JSObject message,
    JSFunction onChunk,
    JSFunction onError,
    JSFunction onDone,
  ) {
    final args = _parseJson('{}');
    args.setProperty('conversation'.toJS, conversation);
    args.setProperty('message'.toJS, message);
    args.setProperty('onChunk'.toJS, onChunk);
    args.setProperty('onError'.toJS, onError);
    args.setProperty('onDone'.toJS, onDone);

    final starter = _newFunction(
      'args'.toJS,
      r'''
const { conversation, message, onChunk, onError, onDone } = args;
const stream = conversation.sendMessageStreaming(message);
const reader = stream.getReader();
let isCancelled = false;

function pump() {
  reader.read().then(({ value, done }) => {
    if (isCancelled) return;
    if (done) {
      onDone();
      return;
    }
    onChunk(value);
    pump();
  }).catch((error) => {
    if (!isCancelled) onError(error);
  });
}

pump();
return {
  cancel() {
    isCancelled = true;
    reader.cancel();
    if (typeof conversation.cancel === 'function') {
      conversation.cancel();
    }
  }
};
'''
          .toJS,
    );
    return starter.callAsFunction(null, args) as JSObject;
  }
}

class _WebEngineHandle implements EngineHandle {
  _WebEngineHandle(this.engine);

  final Future<JSObject> engine;
}

class _WebConversationHandle implements ConversationHandle {
  _WebConversationHandle(this.conversation);

  final JSObject conversation;
}

@JS('Function')
external JSFunction _newFunction(JSString argumentName, JSString body);

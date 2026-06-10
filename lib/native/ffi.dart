import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../litertlm/config.dart';
import '../litertlm/exceptions.dart';
import '../litertlm/message.dart';
import '../litertlm/runtime.dart';
import 'runtime.dart';

const _codeAssetName = 'package:litertlm/native/ffi.dart';
const _nativeFfiSupportAssetName =
    'package:litertlm/src/native_ffi_support.dart';
const _samplerTypeTopP = 2;

/// Creates the FFI-backed native runtime.
LiteRtLmNativeRuntime createFfiRuntime() => _LiteRtLmFfiRuntime();

class _LiteRtLmFfiRuntime implements LiteRtLmNativeRuntime {
  @override
  EngineHandle createEngine(EngineConfig config) {
    final modelPath = config.modelPath.toNativeUtf8();
    final backend = config.backend.name.toNativeUtf8();
    final visionBackend = _toOptionalNativeUtf8(config.visionBackend?.name);
    final audioBackend = _toOptionalNativeUtf8(config.audioBackend?.name);
    final settings = _engineSettingsCreate(
      modelPath,
      backend,
      visionBackend,
      audioBackend,
    );
    malloc.free(modelPath);
    malloc.free(backend);
    _freeOptionalNativeUtf8(visionBackend);
    _freeOptionalNativeUtf8(audioBackend);

    if (settings == nullptr) {
      throw const LiteRtLmException(
        'Could not create LiteRT-LM engine settings.',
      );
    }

    final maxNumTokens = config.maxNumTokens;
    if (maxNumTokens != null) {
      _engineSettingsSetMaxNumTokens(settings, maxNumTokens);
    }

    final cacheDir = config.cacheDir;
    if (cacheDir != null && cacheDir.isNotEmpty) {
      final cacheDirPointer = cacheDir.toNativeUtf8();
      try {
        _engineSettingsSetCacheDir(settings, cacheDirPointer);
      } finally {
        malloc.free(cacheDirPointer);
      }
    }

    final loraRank = config.loraRank;
    if (loraRank != null) {
      _engineSettingsSetLoraRank(settings, loraRank);
      if (loraRank > 0) {
        _setSupportedLoraRank(
          settings,
          loraRank,
          _engineSettingsSetSupportedLoraRanks,
          'LoRA',
        );
      }
    }

    final audioLoraRank = config.audioLoraRank;
    if (audioLoraRank != null) {
      _engineSettingsSetAudioLoraRank(settings, audioLoraRank);
      if (audioLoraRank > 0) {
        _setSupportedLoraRank(
          settings,
          audioLoraRank,
          _engineSettingsSetSupportedAudioLoraRanks,
          'audio LoRA',
        );
      }
    }

    return _FfiEngineHandle(settings: settings);
  }

  @override
  Future<void> initializeEngine(EngineHandle engine) async {
    final ffiEngine = engine as _FfiEngineHandle;

    try {
      final engine = _engineCreate(ffiEngine.settings);
      if (engine == nullptr) {
        throw const LiteRtLmException('Could not create LiteRT-LM engine.');
      }
      ffiEngine.pointer = engine;
    } finally {
      _engineSettingsDelete(ffiEngine.settings);
    }
  }

  @override
  Future<ConversationHandle> createConversation(
    EngineHandle engine,
    ConversationConfig config,
  ) async {
    final ffiEngine = engine as _FfiEngineHandle;
    final conversationConfig = _conversationConfigCreate();
    if (conversationConfig == nullptr) {
      throw const LiteRtLmException(
        'Could not create LiteRT-LM conversation config.',
      );
    }

    Pointer<Opaque> sessionConfig = nullptr;
    try {
      sessionConfig = _sessionConfigCreate();
      if (sessionConfig == nullptr) {
        throw const LiteRtLmException(
          'Could not create LiteRT-LM session config.',
        );
      }

      _applySessionConfig(sessionConfig, config);

      _conversationConfigSetSessionConfig(conversationConfig, sessionConfig);
      _applyConversationConfig(conversationConfig, config);
      final conversation = _conversationCreate(
        ffiEngine.pointer!,
        conversationConfig,
      );
      if (conversation == nullptr) {
        throw const LiteRtLmException(
          'Could not create LiteRT-LM conversation.',
        );
      }
      return _FfiConversationHandle(pointer: conversation);
    } finally {
      if (sessionConfig != nullptr) {
        _sessionConfigDelete(sessionConfig);
      }
      _conversationConfigDelete(conversationConfig);
    }
  }

  @override
  Future<Message> sendMessage(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  }) async {
    final ffiConversation = conversation as _FfiConversationHandle;
    final messageJsonPointer = messageJson.toNativeUtf8();
    final extraContextPointer = _toOptionalNativeUtf8(extraContextJson);
    Pointer<Opaque> response;
    try {
      response = _conversationSendMessage(
        ffiConversation.pointer,
        messageJsonPointer,
        extraContextPointer,
        nullptr,
      );
    } finally {
      malloc.free(messageJsonPointer);
      _freeOptionalNativeUtf8(extraContextPointer);
    }
    if (response == nullptr) {
      throw const LiteRtLmException('Could not send LiteRT-LM message.');
    }

    try {
      final responseString = _jsonResponseGetString(response);
      if (responseString == nullptr) {
        throw const LiteRtLmException('Could not read LiteRT-LM response.');
      }
      return Message.fromJsonString(responseString.toDartString());
    } finally {
      _jsonResponseDelete(response);
    }
  }

  @override
  Stream<Message> sendMessageStream(
    ConversationHandle conversation,
    String messageJson, {
    String? extraContextJson,
  }) {
    final ffiConversation = conversation as _FfiConversationHandle;
    late StreamController<Message> controller;
    _FfiStreamCallback? streamCallback;

    controller = StreamController<Message>(
      onListen: () {
        final messageJsonPointer = messageJson.toNativeUtf8();
        final extraContextPointer = _toOptionalNativeUtf8(extraContextJson);
        late final _FfiStreamCallback currentStreamCallback;
        final callback = NativeCallable<_DartStreamCallbackNative>.listener((
          Pointer<Utf8> chunk,
          bool isFinal,
          Pointer<Utf8> errorMessage,
        ) {
          _handleStreamCallback(
            currentStreamCallback,
            chunk,
            isFinal,
            errorMessage,
          );
        });
        currentStreamCallback = _FfiStreamCallback(
          controller: controller,
          conversation: ffiConversation.pointer,
          callback: callback,
        );
        streamCallback = currentStreamCallback;

        int result;
        try {
          result = _conversationSendMessageStream(
            ffiConversation.pointer,
            messageJsonPointer,
            extraContextPointer,
            nullptr,
            Native.addressOf<NativeFunction<_StreamCallbackNative>>(
              _streamCallbackBridge,
            ),
            callback.nativeFunction.cast<Opaque>(),
          );
        } finally {
          malloc.free(messageJsonPointer);
          _freeOptionalNativeUtf8(extraContextPointer);
        }

        if (result != 0) {
          controller.addError(
            LiteRtLmException(
              'Could not start LiteRT-LM message stream: $result.',
            ),
          );
          scheduleMicrotask(() => _disposeFfiStream(currentStreamCallback));
        }
      },
      onCancel: () {
        final callback = streamCallback;
        if (callback == null || callback.isDone) {
          return null;
        }
        callback.isCanceled = true;
        _conversationCancelProcess(callback.conversation);
        return callback.done.future;
      },
    );

    return controller.stream;
  }

  @override
  void cancelConversation(ConversationHandle conversation) {
    final ffiConversation = conversation as _FfiConversationHandle;
    _conversationCancelProcess(ffiConversation.pointer);
  }

  @override
  Future<int> getTokenCount(ConversationHandle conversation) async {
    final ffiConversation = conversation as _FfiConversationHandle;
    final tokenCount = _conversationGetTokenCount(ffiConversation.pointer);
    if (tokenCount < 0) {
      throw const LiteRtLmException('Could not get LiteRT-LM token count.');
    }
    return tokenCount;
  }

  @override
  Future<String> renderMessageIntoString(
    ConversationHandle conversation,
    String messageJson,
  ) async {
    final ffiConversation = conversation as _FfiConversationHandle;
    final messageJsonPointer = messageJson.toNativeUtf8();
    Pointer<Utf8> rendered;
    try {
      rendered = _conversationRenderMessageToString(
        ffiConversation.pointer,
        messageJsonPointer,
      );
    } finally {
      malloc.free(messageJsonPointer);
    }
    if (rendered == nullptr) {
      throw const LiteRtLmException('Could not render LiteRT-LM message.');
    }
    return rendered.toDartString();
  }

  @override
  void deleteConversation(ConversationHandle conversation) {
    final ffiConversation = conversation as _FfiConversationHandle;
    _conversationDelete(ffiConversation.pointer);
  }

  @override
  void deleteEngine(EngineHandle engine) {
    final ffiEngine = engine as _FfiEngineHandle;
    _engineDelete(ffiEngine.pointer!);
  }

  @override
  void setMinimumLogLevel(LogSeverity severity) {
    _setMinimumLogLevel(severity.value);
  }

  Pointer<Utf8> _toOptionalNativeUtf8(String? value) {
    if (value == null) {
      return nullptr.cast<Utf8>();
    }
    return value.toNativeUtf8();
  }

  void _freeOptionalNativeUtf8(Pointer<Utf8> value) {
    if (value != nullptr) {
      malloc.free(value);
    }
  }

  void _applySessionConfig(
    Pointer<Opaque> sessionConfig,
    ConversationConfig config,
  ) {
    final samplerConfig = config.samplerConfig;
    if (samplerConfig != null) {
      final samplerParams = calloc<_LiteRtLmSamplerParams>();
      try {
        samplerParams.ref
          ..type = _samplerTypeTopP
          ..topK = samplerConfig.topK
          ..topP = samplerConfig.topP
          ..temperature = samplerConfig.temperature
          ..seed = samplerConfig.seed;
        _sessionConfigSetSamplerParams(sessionConfig, samplerParams);
      } finally {
        calloc.free(samplerParams);
      }
    }

    _setLoraPath(sessionConfig, config.loraPath, _sessionConfigSetLoraPath);
    _setLoraPath(
      sessionConfig,
      config.audioLoraPath,
      _sessionConfigSetAudioLoraPath,
    );
  }

  void _setLoraPath(
    Pointer<Opaque> sessionConfig,
    String? path,
    int Function(Pointer<Opaque>, Pointer<Utf8>) setter,
  ) {
    if (path == null) {
      return;
    }

    final pathPointer = path.toNativeUtf8();
    try {
      final result = setter(sessionConfig, pathPointer);
      if (result != 0) {
        throw LiteRtLmException('Could not set LiteRT-LM LoRA path: $path.');
      }
    } finally {
      malloc.free(pathPointer);
    }
  }

  void _setSupportedLoraRank(
    Pointer<Opaque> settings,
    int rank,
    int Function(Pointer<Opaque>, Pointer<Int>, int) setter,
    String label,
  ) {
    final ranks = calloc<Int>();
    try {
      ranks.value = rank;
      final result = setter(settings, ranks, 1);
      if (result != 0) {
        throw LiteRtLmException(
          'Could not set supported LiteRT-LM $label ranks.',
        );
      }
    } finally {
      calloc.free(ranks);
    }
  }

  void _applyConversationConfig(
    Pointer<Opaque> conversationConfig,
    ConversationConfig config,
  ) {
    final systemMessage = config.systemMessage;
    if (systemMessage != null) {
      final systemMessageJson = systemMessage.toJsonString();
      _withNativeUtf8(systemMessageJson, (pointer) {
        _conversationConfigSetSystemMessage(conversationConfig, pointer);
      });
    }

    if (config.initialMessages.isNotEmpty) {
      final messages = config.initialMessages
          .map((message) => message.toJson())
          .toList(growable: false);
      _withNativeUtf8(jsonEncode(messages), (pointer) {
        _conversationConfigSetMessages(conversationConfig, pointer);
      });
    }

    if (config.tools.isNotEmpty) {
      final tools = config.tools
          .map((tool) => tool.getToolDescription())
          .toList(growable: false);
      _withNativeUtf8(jsonEncode(tools), (pointer) {
        _conversationConfigSetTools(conversationConfig, pointer);
      });
    }

    if (config.extraContext.isNotEmpty) {
      _withNativeUtf8(jsonEncode(config.extraContext), (pointer) {
        _conversationConfigSetExtraContext(conversationConfig, pointer);
      });
    }

    if (config.enableConstrainedDecoding) {
      _conversationConfigSetEnableConstrainedDecoding(conversationConfig, true);
    }
  }

  void _withNativeUtf8(String value, void Function(Pointer<Utf8>) callback) {
    final pointer = value.toNativeUtf8();
    try {
      callback(pointer);
    } finally {
      malloc.free(pointer);
    }
  }
}

class _FfiEngineHandle implements EngineHandle {
  _FfiEngineHandle({required this.settings});

  final Pointer<Opaque> settings;
  Pointer<Opaque>? pointer;
}

class _FfiConversationHandle implements ConversationHandle {
  _FfiConversationHandle({required this.pointer});

  final Pointer<Opaque> pointer;
}

class _FfiStreamCallback {
  _FfiStreamCallback({
    required this.controller,
    required this.conversation,
    required this.callback,
  });

  final StreamController<Message> controller;
  final Pointer<Opaque> conversation;
  final NativeCallable<_DartStreamCallbackNative> callback;
  final Completer<void> done = Completer<void>();
  bool isCanceled = false;
  bool isDone = false;
}

void _handleStreamCallback(
  _FfiStreamCallback streamCallback,
  Pointer<Utf8> chunk,
  bool isFinal,
  Pointer<Utf8> errorMessage,
) {
  if (streamCallback.isDone) {
    return;
  }

  if (errorMessage != nullptr) {
    try {
      if (!streamCallback.isCanceled) {
        streamCallback.controller.addError(
          LiteRtLmException(errorMessage.toDartString()),
        );
      }
    } finally {
      _nativeFree(errorMessage.cast<Void>());
    }
    scheduleMicrotask(() => _disposeFfiStream(streamCallback));
    return;
  }

  if (chunk != nullptr && !streamCallback.isCanceled) {
    try {
      streamCallback.controller.add(
        Message.fromJsonString(chunk.toDartString()),
      );
    } catch (error, stackTrace) {
      streamCallback.controller.addError(error, stackTrace);
    } finally {
      _nativeFree(chunk.cast<Void>());
    }
  }

  if (isFinal) {
    scheduleMicrotask(() => _disposeFfiStream(streamCallback));
  }
}

void _disposeFfiStream(_FfiStreamCallback streamCallback) {
  if (streamCallback.isDone) {
    return;
  }

  streamCallback.isDone = true;
  if (!streamCallback.isCanceled && !streamCallback.controller.isClosed) {
    unawaited(streamCallback.controller.close());
  }
  streamCallback.callback.close();
  if (!streamCallback.done.isCompleted) {
    streamCallback.done.complete();
  }
}

typedef _EngineSettingsCreateNative =
    Pointer<Opaque> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
    );
typedef _EngineSettingsSetMaxNumTokensNative =
    Void Function(Pointer<Opaque>, Int);
typedef _EngineSettingsSetCacheDirNative =
    Void Function(Pointer<Opaque>, Pointer<Utf8>);
typedef _EngineSettingsSetLoraRankNative = Void Function(Pointer<Opaque>, Int);
typedef _EngineSettingsSetSupportedLoraRanksNative =
    Int Function(Pointer<Opaque>, Pointer<Int>, Size);
typedef _EngineCreateNative = Pointer<Opaque> Function(Pointer<Opaque>);
typedef _SessionConfigSetSamplerParamsNative =
    Void Function(Pointer<Opaque>, Pointer<_LiteRtLmSamplerParams>);
typedef _SessionConfigSetLoraPathNative =
    Int Function(Pointer<Opaque>, Pointer<Utf8>);
typedef _ConversationConfigSetSessionConfigNative =
    Void Function(Pointer<Opaque>, Pointer<Opaque>);
typedef _ConversationConfigSetJsonNative =
    Void Function(Pointer<Opaque>, Pointer<Utf8>);
typedef _ConversationConfigSetBoolNative = Void Function(Pointer<Opaque>, Bool);
typedef _ConversationCreateNative =
    Pointer<Opaque> Function(Pointer<Opaque>, Pointer<Opaque>);
typedef _ConversationSendMessageNative =
    Pointer<Opaque> Function(
      Pointer<Opaque>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Opaque>,
    );
typedef _StreamCallbackNative =
    Void Function(Pointer<Opaque>, Pointer<Utf8>, Bool, Pointer<Utf8>);
typedef _DartStreamCallbackNative =
    Void Function(Pointer<Utf8>, Bool, Pointer<Utf8>);
typedef _ConversationSendMessageStreamNative =
    Int Function(
      Pointer<Opaque>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Opaque>,
      Pointer<NativeFunction<_StreamCallbackNative>>,
      Pointer<Opaque>,
    );
typedef _ConversationRenderMessageToStringNative =
    Pointer<Utf8> Function(Pointer<Opaque>, Pointer<Utf8>);

final class _LiteRtLmSamplerParams extends Struct {
  @Int32()
  external int type;

  @Int32()
  external int topK;

  @Float()
  external double topP;

  @Float()
  external double temperature;

  @Int32()
  external int seed;
}

@Native<_EngineSettingsCreateNative>(
  symbol: 'litert_lm_engine_settings_create',
  assetId: _codeAssetName,
)
external Pointer<Opaque> _engineSettingsCreate(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> backend,
  Pointer<Utf8> visionBackend,
  Pointer<Utf8> audioBackend,
);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_engine_settings_delete',
  assetId: _codeAssetName,
)
external void _engineSettingsDelete(Pointer<Opaque> settings);

@Native<_EngineSettingsSetMaxNumTokensNative>(
  symbol: 'litert_lm_engine_settings_set_max_num_tokens',
  assetId: _codeAssetName,
)
external void _engineSettingsSetMaxNumTokens(
  Pointer<Opaque> settings,
  int maxNumTokens,
);

@Native<_EngineSettingsSetCacheDirNative>(
  symbol: 'litert_lm_engine_settings_set_cache_dir',
  assetId: _codeAssetName,
)
external void _engineSettingsSetCacheDir(
  Pointer<Opaque> settings,
  Pointer<Utf8> cacheDir,
);

@Native<_EngineSettingsSetLoraRankNative>(
  symbol: 'litert_lm_engine_settings_set_lora_rank',
  assetId: _codeAssetName,
)
external void _engineSettingsSetLoraRank(
  Pointer<Opaque> settings,
  int loraRank,
);

@Native<_EngineSettingsSetSupportedLoraRanksNative>(
  symbol: 'litert_lm_engine_settings_set_supported_lora_ranks',
  assetId: _codeAssetName,
)
external int _engineSettingsSetSupportedLoraRanks(
  Pointer<Opaque> settings,
  Pointer<Int> loraRanks,
  int numRanks,
);

@Native<_EngineSettingsSetLoraRankNative>(
  symbol: 'litert_lm_engine_settings_set_audio_lora_rank',
  assetId: _codeAssetName,
)
external void _engineSettingsSetAudioLoraRank(
  Pointer<Opaque> settings,
  int loraRank,
);

@Native<_EngineSettingsSetSupportedLoraRanksNative>(
  symbol: 'litert_lm_engine_settings_set_supported_audio_lora_ranks',
  assetId: _codeAssetName,
)
external int _engineSettingsSetSupportedAudioLoraRanks(
  Pointer<Opaque> settings,
  Pointer<Int> loraRanks,
  int numRanks,
);

@Native<_EngineCreateNative>(
  symbol: 'litert_lm_engine_create',
  assetId: _codeAssetName,
)
external Pointer<Opaque> _engineCreate(Pointer<Opaque> settings);

@Native<Pointer<Opaque> Function()>(
  symbol: 'litert_lm_session_config_create',
  assetId: _codeAssetName,
)
external Pointer<Opaque> _sessionConfigCreate();

@Native<_SessionConfigSetSamplerParamsNative>(
  symbol: 'litert_lm_session_config_set_sampler_params',
  assetId: _codeAssetName,
)
external void _sessionConfigSetSamplerParams(
  Pointer<Opaque> config,
  Pointer<_LiteRtLmSamplerParams> samplerParams,
);

@Native<_SessionConfigSetLoraPathNative>(
  symbol: 'litert_lm_session_config_set_lora_path',
  assetId: _codeAssetName,
)
external int _sessionConfigSetLoraPath(
  Pointer<Opaque> config,
  Pointer<Utf8> loraPath,
);

@Native<_SessionConfigSetLoraPathNative>(
  symbol: 'litert_lm_session_config_set_audio_lora_path',
  assetId: _codeAssetName,
)
external int _sessionConfigSetAudioLoraPath(
  Pointer<Opaque> config,
  Pointer<Utf8> audioLoraPath,
);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_session_config_delete',
  assetId: _codeAssetName,
)
external void _sessionConfigDelete(Pointer<Opaque> config);

@Native<Pointer<Opaque> Function()>(
  symbol: 'litert_lm_conversation_config_create',
  assetId: _codeAssetName,
)
external Pointer<Opaque> _conversationConfigCreate();

@Native<_ConversationConfigSetSessionConfigNative>(
  symbol: 'litert_lm_conversation_config_set_session_config',
  assetId: _codeAssetName,
)
external void _conversationConfigSetSessionConfig(
  Pointer<Opaque> config,
  Pointer<Opaque> sessionConfig,
);

@Native<_ConversationConfigSetJsonNative>(
  symbol: 'litert_lm_conversation_config_set_system_message',
  assetId: _codeAssetName,
)
external void _conversationConfigSetSystemMessage(
  Pointer<Opaque> config,
  Pointer<Utf8> systemMessageJson,
);

@Native<_ConversationConfigSetJsonNative>(
  symbol: 'litert_lm_conversation_config_set_messages',
  assetId: _codeAssetName,
)
external void _conversationConfigSetMessages(
  Pointer<Opaque> config,
  Pointer<Utf8> messagesJson,
);

@Native<_ConversationConfigSetJsonNative>(
  symbol: 'litert_lm_conversation_config_set_tools',
  assetId: _codeAssetName,
)
external void _conversationConfigSetTools(
  Pointer<Opaque> config,
  Pointer<Utf8> toolsJson,
);

@Native<_ConversationConfigSetJsonNative>(
  symbol: 'litert_lm_conversation_config_set_extra_context',
  assetId: _codeAssetName,
)
external void _conversationConfigSetExtraContext(
  Pointer<Opaque> config,
  Pointer<Utf8> extraContextJson,
);

@Native<_ConversationConfigSetBoolNative>(
  symbol: 'litert_lm_conversation_config_set_enable_constrained_decoding',
  assetId: _codeAssetName,
)
external void _conversationConfigSetEnableConstrainedDecoding(
  Pointer<Opaque> config,
  bool enableConstrainedDecoding,
);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_conversation_config_delete',
  assetId: _codeAssetName,
)
external void _conversationConfigDelete(Pointer<Opaque> config);

@Native<_ConversationCreateNative>(
  symbol: 'litert_lm_conversation_create',
  assetId: _codeAssetName,
)
external Pointer<Opaque> _conversationCreate(
  Pointer<Opaque> engine,
  Pointer<Opaque> config,
);

@Native<_ConversationSendMessageNative>(
  symbol: 'litert_lm_conversation_send_message',
  assetId: _codeAssetName,
)
external Pointer<Opaque> _conversationSendMessage(
  Pointer<Opaque> conversation,
  Pointer<Utf8> messageJson,
  Pointer<Utf8> extraContext,
  Pointer<Opaque> optionalArgs,
);

@Native<_ConversationSendMessageStreamNative>(
  symbol: 'litert_lm_conversation_send_message_stream',
  assetId: _codeAssetName,
)
external int _conversationSendMessageStream(
  Pointer<Opaque> conversation,
  Pointer<Utf8> messageJson,
  Pointer<Utf8> extraContext,
  Pointer<Opaque> optionalArgs,
  Pointer<NativeFunction<_StreamCallbackNative>> callback,
  Pointer<Opaque> callbackData,
);

@Native<_ConversationRenderMessageToStringNative>(
  symbol: 'litert_lm_conversation_render_message_to_string',
  assetId: _codeAssetName,
)
external Pointer<Utf8> _conversationRenderMessageToString(
  Pointer<Opaque> conversation,
  Pointer<Utf8> messageJson,
);

@Native<_StreamCallbackNative>(
  symbol: 'litertlm_stream_callback_bridge',
  assetId: _nativeFfiSupportAssetName,
)
external void _streamCallbackBridge(
  Pointer<Opaque> callbackData,
  Pointer<Utf8> chunk,
  bool isFinal,
  Pointer<Utf8> errorMessage,
);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'litertlm_free',
  assetId: _nativeFfiSupportAssetName,
)
external void _nativeFree(Pointer<Void> pointer);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_conversation_cancel_process',
  assetId: _codeAssetName,
)
external void _conversationCancelProcess(Pointer<Opaque> conversation);

@Native<Int Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_conversation_get_token_count',
  assetId: _codeAssetName,
)
external int _conversationGetTokenCount(Pointer<Opaque> conversation);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_conversation_delete',
  assetId: _codeAssetName,
)
external void _conversationDelete(Pointer<Opaque> conversation);

@Native<Pointer<Utf8> Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_json_response_get_string',
  assetId: _codeAssetName,
)
external Pointer<Utf8> _jsonResponseGetString(Pointer<Opaque> response);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_json_response_delete',
  assetId: _codeAssetName,
)
external void _jsonResponseDelete(Pointer<Opaque> response);

@Native<Void Function(Pointer<Opaque>)>(
  symbol: 'litert_lm_engine_delete',
  assetId: _codeAssetName,
)
external void _engineDelete(Pointer<Opaque> engine);

@Native<Void Function(Int)>(
  symbol: 'litert_lm_set_min_log_level',
  assetId: _codeAssetName,
)
external void _setMinimumLogLevel(int level);

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:litertlm/litertlm.dart';

import 'model/asset.dart';

const _systemPrompt = '''
You are a concise, helpful assistant. Answer the user's current request only.
Do not assume that earlier requests shown in the app are part of the current
conversation. Reply in the same language as the user unless asked otherwise.
''';

const _modelDirectoryChannel = MethodChannel(
  'org.rockstudio.litertlm_example/model_directory',
);

/// Demonstrates stateless requests backed by one fixed-preface KV checkpoint.
class CheckpointChatApp extends StatelessWidget {
  const CheckpointChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiteRT-LM Checkpoint Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

/// Model configuration and independent-request chat interface.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatEntry>[];

  List<String> _modelAssets = const [];
  String? _selectedModel;
  String? _selectedModelDirectory;
  Backend _backend = const Backend.cpu();
  Engine? _engine;
  Conversation? _conversation;
  bool _loadingModels = true;
  bool _initializing = false;
  bool _generating = false;
  String? _statusError;
  int? _prefaceTokenCount;

  bool get _isReady => _conversation?.isAlive ?? false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadModelAssets());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkpoint Chat'),
        actions: [
          IconButton(
            tooltip: 'Clear visible transcript',
            onPressed: _generating || _messages.isEmpty
                ? null
                : _clearTranscript,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ConfigurationCard(
              models: _modelAssets,
              selectedModel: _selectedModel,
              backend: _backend,
              loadingModels: _loadingModels,
              initializing: _initializing,
              ready: _isReady,
              prefaceTokenCount: _prefaceTokenCount,
              error: _statusError,
              modelDirectory: _selectedModelDirectory,
              onModelChanged: _isReady || _initializing
                  ? null
                  : (value) => setState(() => _selectedModel = value),
              onBackendChanged: _isReady || _initializing
                  ? null
                  : (value) => setState(() => _backend = value),
              onInitialize: _canInitialize ? _initializeModel : null,
              onUnload: _isReady && !_generating ? _unloadModel : null,
              onChooseFolder: _isReady || _initializing
                  ? null
                  : _chooseModelFolder,
            ),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _MessageBubble(entry: _messages[index]),
                    ),
            ),
            _Composer(
              controller: _messageController,
              enabled: _isReady && !_generating,
              generating: _generating,
              onSend: _sendMessage,
              onCancel: _generating ? _cancelGeneration : null,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canInitialize =>
      !_loadingModels && !_initializing && !_isReady && _selectedModel != null;

  Future<void> _loadModelAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final models =
          manifest
              .listAssets()
              .where((asset) => asset.endsWith('.litertlm'))
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _modelAssets = models;
        _selectedModel = models.isEmpty
            ? null
            : models.firstWhere(
                (asset) => asset.endsWith('/gemma-4-E2B-it.litertlm'),
                orElse: () => models.first,
              );
        _loadingModels = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _statusError = 'Could not inspect model assets: $error';
      });
    }
  }

  Future<void> _initializeModel() async {
    final modelAsset = _selectedModel;
    if (modelAsset == null) return;

    setState(() {
      _initializing = true;
      _statusError = null;
      _prefaceTokenCount = null;
    });

    Engine? engine;
    Conversation? conversation;
    try {
      final modelFile = File(modelAsset);
      final modelPath = modelFile.isAbsolute
          ? modelFile.path
          : await resolveModelAssetPath(modelAsset);
      engine = Engine(
        engineConfig: EngineConfig(
          modelPath: modelPath,
          backend: _backend,
          // Gemma 4 E2B's mobile reference benchmarks use a 2K context.
          // Keeping the sample at that size avoids unnecessary KV-cache memory.
          maxNumTokens: 2048,
        ),
      );
      await engine.initialize();
      conversation = await engine.createConversation(
        ConversationConfig(
          systemMessage: Message.system(_systemPrompt.trim()),
          prefillPrefaceOnInit: true,
        ),
      );
      final tokenCount = await conversation.getTokenCount();
      if (!mounted) {
        await conversation.dispose();
        await engine.dispose();
        return;
      }
      setState(() {
        _engine = engine;
        _conversation = conversation;
        _prefaceTokenCount = tokenCount;
      });
    } catch (error) {
      await conversation?.dispose();
      await engine?.dispose();
      if (mounted) {
        setState(() => _statusError = 'Initialization failed: $error');
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _chooseModelFolder() async {
    setState(() {
      _statusError = null;
      _loadingModels = true;
    });
    try {
      final directoryPath = await _modelDirectoryChannel.invokeMethod<String>(
        'pickModelDirectory',
      );
      if (directoryPath == null || !mounted) return;

      final models = await Directory(directoryPath)
          .list(followLinks: false)
          .where((entry) => entry is File)
          .map((entry) => entry.path)
          .where((path) => path.toLowerCase().endsWith('.litertlm'))
          .toList();
      models.sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _selectedModelDirectory = directoryPath;
        if (models.isEmpty) {
          _modelAssets = const [];
          _selectedModel = null;
          _statusError = 'No .litertlm model found directly in $directoryPath';
          return;
        }
        _modelAssets = models;
        _selectedModel = models.first;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusError = error.message ?? 'Could not open the model folder.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusError = 'Could not inspect model folder: $error');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _sendMessage() async {
    final conversation = _conversation;
    final input = _messageController.text.trim();
    final isSmokeTestModel =
        _selectedModel?.endsWith('/test_lm.litertlm') ?? true;
    if (conversation == null || input.isEmpty || _generating) return;

    _messageController.clear();
    final responseIndex = _messages.length + 1;
    setState(() {
      _statusError = null;
      _generating = true;
      _messages
        ..add(_ChatEntry.user(input))
        ..add(const _ChatEntry.assistant(''));
    });
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();
    try {
      // Restores the fixed-preface KV checkpoint before every request.
      // Earlier entries remain visible but are not sent to the model.
      final responseText = StringBuffer();
      await for (final chunk in conversation.sendMessageStatelessStream(
        Message.user(input),
        // The synthetic test model only verifies the integration path and can
        // produce invalid-looking text (or fail after a long decode). A real
        // chat model gets enough room to produce a useful response.
        maxOutputTokens: isSmokeTestModel ? 16 : 256,
      )) {
        if (chunk.isEmpty) continue;
        responseText.write(chunk.text);
        if (!mounted) return;
        setState(() {
          _messages[responseIndex] = _ChatEntry.assistant(
            responseText.toString(),
            elapsed: stopwatch.elapsed,
          );
        });
        _scrollToBottom();
      }
      stopwatch.stop();
      final tokenCount = await conversation.getTokenCount();
      if (!mounted) return;
      setState(() {
        _messages[responseIndex] = _ChatEntry.assistant(
          responseText.toString(),
          elapsed: stopwatch.elapsed,
          tokenCount: tokenCount,
        );
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _messages[responseIndex] = _ChatEntry.error('$error');
        _statusError = 'Generation failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _generating = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _cancelGeneration() async {
    await _conversation?.cancel();
  }

  Future<void> _clearTranscript() async {
    try {
      await _conversation?.resetToPreface();
      if (mounted) setState(_messages.clear);
    } catch (error) {
      if (mounted) {
        setState(() => _statusError = 'Checkpoint restore failed: $error');
      }
    }
  }

  Future<void> _unloadModel() async {
    final conversation = _conversation;
    final engine = _engine;
    setState(() {
      _conversation = null;
      _engine = null;
      _prefaceTokenCount = null;
      _messages.clear();
    });
    await conversation?.dispose();
    await engine?.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    unawaited(_disposeRuntime());
    super.dispose();
  }

  Future<void> _disposeRuntime() async {
    await _conversation?.dispose();
    await _engine?.dispose();
  }
}

class _ConfigurationCard extends StatelessWidget {
  const _ConfigurationCard({
    required this.models,
    required this.selectedModel,
    required this.backend,
    required this.loadingModels,
    required this.initializing,
    required this.ready,
    required this.prefaceTokenCount,
    required this.error,
    required this.modelDirectory,
    required this.onModelChanged,
    required this.onBackendChanged,
    required this.onInitialize,
    required this.onUnload,
    required this.onChooseFolder,
  });

  final List<String> models;
  final String? selectedModel;
  final Backend backend;
  final bool loadingModels;
  final bool initializing;
  final bool ready;
  final int? prefaceTokenCount;
  final String? error;
  final String? modelDirectory;
  final ValueChanged<String?>? onModelChanged;
  final ValueChanged<Backend>? onBackendChanged;
  final VoidCallback? onInitialize;
  final VoidCallback? onUnload;
  final VoidCallback? onChooseFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedModel,
              decoration: const InputDecoration(
                labelText: '.litertlm model',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final model in models)
                  DropdownMenuItem(
                    value: model,
                    child: Text(
                      _modelLabel(model),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onModelChanged,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onChooseFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose device folder (direct access)'),
            ),
            if (modelDirectory != null) ...[
              const SizedBox(height: 4),
              Text(
                modelDirectory!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            SegmentedButton<Backend>(
              segments: const [
                ButtonSegment(value: Backend.cpu(), label: Text('CPU')),
                ButtonSegment(value: Backend.gpu(), label: Text('GPU')),
              ],
              selected: {backend},
              onSelectionChanged: onBackendChanged == null
                  ? null
                  : (selection) => onBackendChanged!(selection.first),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onInitialize,
                    icon: initializing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.memory),
                    label: Text(ready ? 'Ready' : 'Load & prefill'),
                  ),
                ),
                if (ready) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onUnload,
                    child: const Text('Unload'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loadingModels
                  ? 'Searching for model assets...'
                  : models.isEmpty
                  ? 'No model selected. Choose its device folder.'
                  : ready
                  ? 'System-preface checkpoint ready'
                        '${prefaceTokenCount == null ? '' : ' ($prefaceTokenCount tokens)'}'
                  : 'The fixed system prompt is prefetched once at load time.',
              style: theme.textTheme.bodySmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

String _modelLabel(String model) {
  final normalized = model.replaceAll('\\', '/');
  final name = normalized.substring(normalized.lastIndexOf('/') + 1);
  return model.endsWith('/test_lm.litertlm') ? '$name (smoke test only)' : name;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Load a model, then send independent requests.\n\n'
          'The visible transcript is UI-only: every request restores the same '
          'system-prompt KV checkpoint.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.generating,
    required this.onSend,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Message (each request is independent)'
                      : 'Load a model first',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: generating ? 'Cancel' : 'Send',
              onPressed: generating ? onCancel : (enabled ? onSend : null),
              icon: Icon(generating ? Icons.stop : Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatRole { user, assistant, error }

class _ChatEntry {
  const _ChatEntry._(this.role, this.text, {this.elapsed, this.tokenCount});

  const _ChatEntry.user(String text) : this._(_ChatRole.user, text);

  const _ChatEntry.assistant(String text, {Duration? elapsed, int? tokenCount})
    : this._(
        _ChatRole.assistant,
        text,
        elapsed: elapsed,
        tokenCount: tokenCount,
      );

  const _ChatEntry.error(String text) : this._(_ChatRole.error, text);

  final _ChatRole role;
  final String text;
  final Duration? elapsed;
  final int? tokenCount;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.entry});

  final _ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = entry.role == _ChatRole.user;
    final isError = entry.role == _ChatRole.error;
    final background = isUser
        ? theme.colorScheme.primaryContainer
        : isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final metadata = [
      if (entry.elapsed != null) '${entry.elapsed!.inMilliseconds} ms',
      if (entry.tokenCount != null) '${entry.tokenCount} KV tokens',
    ].join(' · ');

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.text.isEmpty)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              SelectableText(entry.text),
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(metadata, style: theme.textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}

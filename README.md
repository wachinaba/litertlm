# litertlm
Native LiteRT-LM bindings for Flutter across mobile, desktop, and web.

Pub: https://pub.dev/packages/litertlm

## Overview
This package is a lightweight bridge to the official LiteRT-LM runtimes. It uses the official, platform-optimized distribution for each platform, such as the Swift package on iOS and macOS, the Gradle package on Android, and CLI packages on Windows.

## Platform Support
| Platform | Runtime artifact | Integration |
| --- | --- | --- |
| iOS | Official Swift package | FFI |
| Android | Official Gradle package | JNI |
| macOS | Official Swift package | FFI |
| Windows * | Official CLI package | FFI |
| Linux | Official CLI package | FFI |
| Web | Official NPM package | JS interop |

**Note:** Windows ARM64 is not currently supported because there is no official upstream package available.

## Usage

### Installation
```
$ flutter pub add litertlm
```

### Basic Inference
1. Create and initialize `Engine`.

```dart
final engine = Engine(
  engineConfig: const EngineConfig(
		modelPath: '/path/to/model.litertlm',
  ),
);

await engine.initialize();
```

2. Create a `Conversation`.

```dart
final conversation = await engine.createConversation(
  ConversationConfig(
    systemMessage: Message.system('You are concise and helpful.'),
  ),
);
```

3. Send a `Message` and read the response.

```dart
final response = await conversation.sendMessage(
  Message.user('Write one sentence about Flutter.'),
);

print(response.text);
```

4. Dispose native resources.

```dart
await conversation.dispose();
await engine.dispose();
```



### Multimodal
Use `Contents` with multiple `Content` values for text, image, and audio inputs. File paths are passed through to the native runtime.

```dart
final conversation = await engine.createConversation();

final response = await conversation.sendMessage(
	Message.userContents(
		Contents([
			Content.text('Describe this image.'),
			Content.imageFile('/path/to/photo.jpg'),
		]),
	),
);

print(response.text);
```

You can also pass in-memory bytes:

```dart
final response = await conversation.sendMessage(
	Message.userContents(
		Contents([
			Content.text('Transcribe this audio.'),
			Content.audioBytes(audioBytes),
		]),
	),
);
```

### Tool Use
Define tools by implementing `Tool`. Tool descriptions use the OpenAI-style function schema expected by LiteRT-LM.

```dart
class WeatherTool implements Tool {
	@override
	Map<String, Object?> getToolDescription() {
		return {
			'type': 'function',
			'function': {
				'name': 'get_weather',
				'description': 'Gets the current weather for a city.',
				'parameters': {
					'type': 'object',
					'properties': {
						'city': {'type': 'string'},
					},
					'required': ['city'],
				},
			},
		};
	}

	@override
	Future<Object?> execute(Map<String, Object?> arguments) async {
		final city = arguments['city'];
		return {'city': city, 'condition': 'sunny', 'temperature_c': 22};
	}
}
```

Pass tools when creating the conversation. Automatic tool calling is enabled by default, so the model can request a tool, Dart executes it, and the final model response is returned.

```dart
final conversation = await engine.createConversation(
	ConversationConfig(
		tools: [WeatherTool()],
	),
);

final response = await conversation.sendMessage(
	Message.user('What is the weather in Seattle?'),
);

print(response.text);
```

To handle tool calls yourself, disable automatic tool calling and inspect `response.toolCalls`.

## Troubleshooting

### LiteRtLmException
LiteRT-LM depends heavily on device hardware and model capabilities. Even when the APIs are used correctly, some actions may fail because of hardware or model compatibility.
Upstream LiteRT-LM tends to fail silently with `NULL` while logging the underlying issue in native logs. Since those logs are not practical to catch and handle directly, this package throws `LiteRtLmException` when LiteRT-LM clearly refuses to work. Developers can set `LogSeverity` to inspect detailed device logs. It is recommended to catch `LiteRtLmException` around the entire engine lifecycle and handle it accordingly.


### UnsupportedError

`UnsupportedError` means the selected platform runtime does not support the requested feature. This is different from `LiteRtLmException`: the call is rejected before LiteRT-LM runs because the underlying SDK has no matching capability.

Common cases:

* Web does not support per-message `extraContext`. Use `ConversationConfig.extraContext` instead.
* Web does not support `Backend.npu`, LoRA config, log-level configuration, or `renderMessageIntoString`.
* Android does not support `enableConstrainedDecoding` yet because the LiteRT-LM Android SDK does not expose that config field.

`UnsupportedError` is a Dart `Error`, not an `Exception`. If you need to catch it, use `catch (error)` rather than `on Exception`.


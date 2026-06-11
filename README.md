# litertlm
Native LiteRT-LM bindings for Flutter across mobile, desktop, and web.

Pub: https://pub.dev/packages/litertlm

API reference: https://pub.dev/documentation/litertlm/latest/

Matches upstream LiteRT-LM v0.13.1.

## Overview
This package is a lightweight bridge to the official LiteRT-LM runtimes. Powered by native LiteRT-LM distributions, it provides the same hardware acceleration and capabilities as each platform's optimized distribution, including the Swift package on iOS and macOS, the Gradle package on Android, and CLI packages on Windows.

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

### Prepare Model
You can download `.litertlm` models from [LiteRT Community on Hugging Face](https://huggingface.co/litert-community) or other distributors. Models such as Gemma 4 E2B/E4B are great starting points and run on most devices and platforms, including web.

**Note:** LiteRT-LM expects a valid file path or URL. Flutter asset identifiers are not directly supported.

### Basic Inference
1. Create and initialize `Engine`.

```dart
final engine = Engine(
  engineConfig: const EngineConfig(
    modelPath: '/path/to/model.litertlm',
    backend: Backend.gpu(),
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
Define tools by implementing `Tool`.

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

Create a `Conversation` with the tools. Automatic tool calling is enabled by default.

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
LiteRT-LM depends heavily on device hardware, runtime support, and model capabilities. Even when the APIs are used correctly, some actions may fail because of the user's hardware or model selection. Upstream LiteRT-LM may fail silently while logging the underlying issue in native logs. Since those logs are not practical to catch and handle internally, this package throws `LiteRtLmException` when LiteRT-LM clearly refuses to work. Developers can set `LogSeverity` to inspect detailed device logs. It is recommended to catch `LiteRtLmException` around the engine lifecycle and handle it as a recoverable runtime failure.

### UnsupportedError

LiteRT-LM is under fast development, and not all features are immediately available on every platform. This package throws `UnsupportedError` when the selected platform runtime does not support the requested feature.

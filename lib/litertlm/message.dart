import 'dart:convert';
import 'dart:typed_data';

class Message {
  const Message({
    required this.role,
    this.contents = Contents.empty,
    this.toolCalls = const [],
    this.channels = const {},
  });

  factory Message.system(String text) {
    return Message.systemContents(Contents.text(text));
  }

  factory Message.systemContents(Contents contents) {
    return Message(role: Role.system, contents: contents);
  }

  factory Message.user(String text) {
    return Message.userContents(Contents.text(text));
  }

  factory Message.userContents(Contents contents) {
    return Message(role: Role.user, contents: contents);
  }

  factory Message.model({
    Contents contents = Contents.empty,
    List<ToolCall> toolCalls = const [],
    Map<String, String> channels = const {},
  }) {
    return Message(
      role: Role.model,
      contents: contents,
      toolCalls: toolCalls,
      channels: channels,
    );
  }

  factory Message.modelText(String text) {
    return Message.model(contents: Contents.text(text));
  }

  factory Message.tool(Contents contents) {
    return Message(role: Role.tool, contents: contents);
  }

  factory Message.fromJsonString(String jsonString) {
    final value = jsonDecode(jsonString);
    if (value is! Map<String, Object?>) {
      throw FormatException('Expected a message JSON object.', jsonString);
    }
    return Message.fromJson(value);
  }

  factory Message.fromJson(Map<String, Object?> json) {
    final role = Role.fromJsonName(json['role']?.toString());
    final toolCalls = json['tool_calls'] is List<Object?>
        ? (json['tool_calls'] as List<Object?>)
              .whereType<Map<String, Object?>>()
              .map(ToolCall.fromJson)
              .toList(growable: false)
        : const <ToolCall>[];
    final channels = json['channels'] is Map<String, Object?>
        ? (json['channels'] as Map<String, Object?>).map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          )
        : const <String, String>{};
    return Message(
      role: role,
      contents: Contents.fromJson(json['content']),
      toolCalls: toolCalls,
      channels: channels,
    );
  }

  final Role role;
  final Contents contents;
  final List<ToolCall> toolCalls;
  final Map<String, String> channels;

  String get text => contents.text;

  Map<String, Object?> toJson() {
    return {
      'role': role.jsonName,
      if (!contents.isEmpty) 'content': contents.toJson(),
      if (toolCalls.isNotEmpty)
        'tool_calls': toolCalls.map((toolCall) => toolCall.toJson()).toList(),
      if (channels.isNotEmpty) 'channels': channels,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => text;
}

class Contents {
  const Contents(this.values);

  factory Contents.text(String text) => Contents([Content.text(text)]);

  factory Contents.single(Content content) => Contents([content]);

  factory Contents.fromJson(Object? json) {
    if (json == null) {
      return Contents.empty;
    }
    if (json is String) {
      return Contents.text(json);
    }
    if (json is Map<String, Object?>) {
      return Contents([Content.fromJson(json)]);
    }
    if (json is List<Object?>) {
      return Contents(
        json
            .whereType<Map<String, Object?>>()
            .map(Content.fromJson)
            .toList(growable: false),
      );
    }
    throw FormatException('Unsupported message content JSON: $json');
  }

  static const empty = Contents([]);

  final List<Content> values;

  bool get isEmpty => values.isEmpty;

  String get text =>
      values.whereType<TextContent>().map((c) => c.text).join(' ');

  Object toJson() => values.map((content) => content.toJson()).toList();

  String toJsonString() => jsonEncode(toJson());
}

class ToolCall {
  const ToolCall({required this.name, required this.arguments});

  factory ToolCall.fromJson(Map<String, Object?> json) {
    final function = json['function'];
    if (function is! Map<String, Object?>) {
      throw FormatException('Unsupported tool call JSON: $json');
    }
    final arguments = function['arguments'];
    return ToolCall(
      name: function['name']?.toString() ?? '',
      arguments: arguments is Map<String, Object?>
          ? arguments
          : const <String, Object?>{},
    );
  }

  final String name;
  final Map<String, Object?> arguments;

  Map<String, Object?> toJson() {
    return {
      'type': 'function',
      'function': {'name': name, 'arguments': arguments},
    };
  }
}

sealed class Content {
  const Content();

  factory Content.text(String text) = TextContent;
  factory Content.imageBytes(Uint8List bytes) = ImageBytesContent;
  factory Content.imageFile(String path) = ImageFileContent;
  factory Content.audioBytes(Uint8List bytes) = AudioBytesContent;
  factory Content.audioFile(String path) = AudioFileContent;
  factory Content.toolResponse({
    required String name,
    required Object? response,
  }) = ToolResponseContent;

  factory Content.fromJson(Map<String, Object?> json) {
    return switch (json['type']) {
      'text' => TextContent(json['text']?.toString() ?? ''),
      'image' when json['blob'] is String => ImageBytesContent(
        base64Decode(json['blob'] as String),
      ),
      'image' => ImageFileContent(json['path']?.toString() ?? ''),
      'audio' when json['blob'] is String => AudioBytesContent(
        base64Decode(json['blob'] as String),
      ),
      'audio' => AudioFileContent(json['path']?.toString() ?? ''),
      'tool_response' => ToolResponseContent(
        name: json['name']?.toString() ?? '',
        response: json['response'],
      ),
      final type => throw FormatException('Unsupported content type: $type'),
    };
  }

  Map<String, Object?> toJson();
}

class TextContent extends Content {
  const TextContent(this.text);

  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};
}

class ImageBytesContent extends Content {
  const ImageBytesContent(this.bytes);

  final Uint8List bytes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'image',
    'blob': base64Encode(bytes),
  };
}

class ImageFileContent extends Content {
  const ImageFileContent(this.path);

  final String path;

  @override
  Map<String, Object?> toJson() => {'type': 'image', 'path': path};
}

class AudioBytesContent extends Content {
  const AudioBytesContent(this.bytes);

  final Uint8List bytes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'audio',
    'blob': base64Encode(bytes),
  };
}

class AudioFileContent extends Content {
  const AudioFileContent(this.path);

  final String path;

  @override
  Map<String, Object?> toJson() => {'type': 'audio', 'path': path};
}

class ToolResponseContent extends Content {
  const ToolResponseContent({required this.name, required this.response});

  final String name;
  final Object? response;

  @override
  Map<String, Object?> toJson() => {
    'type': 'tool_response',
    'name': name,
    'response': response,
  };
}

enum Role {
  system('system'),
  user('user'),
  model('model'),
  tool('tool');

  const Role(this.jsonName);

  final String jsonName;

  static Role fromJsonName(String? name) {
    if (name == 'assistant') {
      return Role.model;
    }
    return Role.values.firstWhere(
      (role) => role.jsonName == name,
      orElse: () => Role.model,
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

/// Represents a message in the conversation.
class Message {
  /// Creates a message.
  const Message({
    required this.role,
    this.contents = Contents.empty,
    this.toolCalls = const [],
    this.channels = const {},
  });

  /// Creates a system message from the given text.
  factory Message.system(String text) {
    return Message.systemContents(Contents.text(text));
  }

  /// Creates a system message from the given contents.
  factory Message.systemContents(Contents contents) {
    return Message(role: Role.system, contents: contents);
  }

  /// Creates a user message from the given text.
  factory Message.user(String text) {
    return Message.userContents(Contents.text(text));
  }

  /// Creates a user message from the given contents.
  factory Message.userContents(Contents contents) {
    return Message(role: Role.user, contents: contents);
  }

  /// Creates a model message.
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

  /// Creates a model message from the given text.
  factory Message.modelText(String text) {
    return Message.model(contents: Contents.text(text));
  }

  /// Creates a tool message from the given contents.
  factory Message.tool(Contents contents) {
    return Message(role: Role.tool, contents: contents);
  }

  /// Creates a message from a JSON string.
  factory Message.fromJsonString(String jsonString) {
    final value = jsonDecode(jsonString);
    if (value is! Map<String, Object?>) {
      throw FormatException('Expected a message JSON object.', jsonString);
    }
    return Message.fromJson(value);
  }

  /// Creates a message from JSON-compatible values.
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

  /// The role of the message.
  final Role role;

  /// The contents of the message.
  final Contents contents;

  /// Tool calls returned by the model.
  final List<ToolCall> toolCalls;

  /// The channels of the message.
  final Map<String, String> channels;

  /// The text content of the message.
  String get text => contents.text;

  /// Converts this message to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {
      'role': role.jsonName,
      if (!contents.isEmpty) 'content': contents.toJson(),
      if (toolCalls.isNotEmpty)
        'tool_calls': toolCalls.map((toolCall) => toolCall.toJson()).toList(),
      if (channels.isNotEmpty) 'channels': channels,
    };
  }

  /// Converts this message to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => text;
}

/// Represents a collection of content items.
class Contents {
  /// Creates contents from a list of content items.
  const Contents(this.values);

  /// Creates contents from a text string.
  factory Contents.text(String text) => Contents([Content.text(text)]);

  /// Creates contents from a single content item.
  factory Contents.single(Content content) => Contents([content]);

  /// Creates contents from JSON-compatible values.
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

  /// Empty contents.
  static const empty = Contents([]);

  /// The list of content items.
  final List<Content> values;

  /// Whether the contents are empty.
  bool get isEmpty => values.isEmpty;

  /// The text content of the contents.
  String get text =>
      values.whereType<TextContent>().map((c) => c.text).join(' ');

  /// Converts this contents object to JSON-compatible values.
  Object toJson() => values.map((content) => content.toJson()).toList();

  /// Converts this contents object to a JSON string.
  String toJsonString() => jsonEncode(toJson());
}

/// Tool call returned by the model.
class ToolCall {
  /// Creates a tool call.
  const ToolCall({required this.name, required this.arguments});

  /// Creates a tool call from JSON-compatible values.
  factory ToolCall.fromJson(Map<String, Object?> json) {
    final function = json['function'];
    if (function is! Map<String, Object?>) {
      throw FormatException('Unsupported tool call JSON: $json');
    }
    final argumentsValue = function['arguments'];
    var arguments = const <String, Object?>{};
    if (argumentsValue is Map) {
      arguments = {
        for (final entry in argumentsValue.entries)
          entry.key.toString(): entry.value,
      };
    } else if (argumentsValue is String && argumentsValue.isNotEmpty) {
      final decoded = jsonDecode(argumentsValue);
      if (decoded is Map) {
        arguments = {
          for (final entry in decoded.entries)
            entry.key.toString(): entry.value,
        };
      }
    }
    return ToolCall(
      name: function['name']?.toString() ?? '',
      arguments: arguments,
    );
  }

  /// The name of the tool function to execute.
  final String name;

  /// The arguments for the tool function.
  final Map<String, Object?> arguments;

  /// Converts this tool call to JSON-compatible values.
  Map<String, Object?> toJson() {
    return {
      'type': 'function',
      'function': {'name': name, 'arguments': arguments},
    };
  }
}

/// Represents content in the message of the conversation.
sealed class Content {
  /// Creates content.
  const Content();

  /// Text.
  factory Content.text(String text) = TextContent;

  /// Image provided as raw bytes.
  factory Content.imageBytes(Uint8List bytes) = ImageBytesContent;

  /// Image provided by a file path.
  factory Content.imageFile(String path) = ImageFileContent;

  /// Audio provided as raw bytes.
  factory Content.audioBytes(Uint8List bytes) = AudioBytesContent;

  /// Audio provided by a file path.
  factory Content.audioFile(String path) = AudioFileContent;

  /// Tool response provided by the user.
  factory Content.toolResponse({
    required String name,
    required Object? response,
  }) = ToolResponseContent;

  /// Creates content from JSON-compatible values.
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

  /// Converts this content to JSON-compatible values.
  Map<String, Object?> toJson();
}

/// Text content.
class TextContent extends Content {
  /// Creates text content.
  const TextContent(this.text);

  /// The text value.
  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};
}

/// Image content provided as raw bytes.
class ImageBytesContent extends Content {
  /// Creates image content from raw bytes.
  const ImageBytesContent(this.bytes);

  /// The image bytes.
  final Uint8List bytes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'image',
    'blob': base64Encode(bytes),
  };
}

/// Image content provided by a file path.
class ImageFileContent extends Content {
  /// Creates image content from a file path.
  const ImageFileContent(this.path);

  /// The image file path.
  final String path;

  @override
  Map<String, Object?> toJson() => {'type': 'image', 'path': path};
}

/// Audio content provided as raw bytes.
class AudioBytesContent extends Content {
  /// Creates audio content from raw bytes.
  const AudioBytesContent(this.bytes);

  /// The audio bytes.
  final Uint8List bytes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'audio',
    'blob': base64Encode(bytes),
  };
}

/// Audio content provided by a file path.
class AudioFileContent extends Content {
  /// Creates audio content from a file path.
  const AudioFileContent(this.path);

  /// The audio file path.
  final String path;

  @override
  Map<String, Object?> toJson() => {'type': 'audio', 'path': path};
}

/// Tool response provided by the user.
class ToolResponseContent extends Content {
  /// Creates tool response content.
  const ToolResponseContent({required this.name, required this.response});

  /// The name of the tool.
  final String name;

  /// The tool response.
  final Object? response;

  @override
  Map<String, Object?> toJson() => {
    'type': 'tool_response',
    'name': name,
    'response': response,
  };
}

/// The role of the message in a conversation.
enum Role {
  /// Represents the system.
  system('system'),

  /// Represents the user.
  user('user'),

  /// Represents the model.
  model('model'),

  /// Represents a tool response.
  tool('tool');

  /// Creates a role.
  const Role(this.jsonName);

  /// The JSON role name.
  final String jsonName;

  /// Creates a role from a JSON role name.
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

import 'dart:async';
import 'dart:convert';

import 'exceptions.dart';

/// A tool that can be used by the LiteRT-LM model.
abstract interface class Tool {
  /// Gets the tool description in function schema format.
  Map<String, Object?> getToolDescription();

  /// Executes the tool with the given arguments.
  FutureOr<Object?> execute(Map<String, Object?> arguments);
}

/// Manages tools and provides methods to execute tools and get their specifications.
class ToolManager {
  /// Creates a tool manager with the given tools.
  ToolManager({List<Tool> tools = const []}) : _tools = {} {
    for (final tool in tools) {
      final description = tool.getToolDescription();
      final function = description['function'];
      if (function is! Map || function['name'] is! String) {
        throw const LiteRtLmException(
          'Tool description must contain ["function"]["name"].',
        );
      }
      _tools[function['name'] as String] = tool;
    }
  }

  final Map<String, Tool> _tools;

  /// The tools description for all tools.
  String get toolsJsonDescription => jsonEncode(
    _tools.values
        .map((tool) => tool.getToolDescription())
        .toList(growable: false),
  );

  /// Executes a tool function by its name with the given arguments.
  Future<Object?> execute({
    required String name,
    required Map<String, Object?> arguments,
  }) async {
    final tool = _tools[name];
    if (tool == null) {
      throw LiteRtLmException('Tool "$name" was not found.');
    }
    final result = await tool.execute(arguments);
    return _normalizeJsonValue(result);
  }

  Object? _normalizeJsonValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _normalizeJsonValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value.toString();
  }
}

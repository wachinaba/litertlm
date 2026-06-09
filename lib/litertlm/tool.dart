import 'dart:convert';

enum ToolParameterType {
  string('string'),
  integer('integer'),
  number('number'),
  boolean('boolean'),
  array('array');

  const ToolParameterType(this.jsonType);

  final String jsonType;
}

class ToolParameter {
  const ToolParameter({
    required this.name,
    required this.type,
    this.description = '',
    this.required = true,
    this.nullable = false,
    this.itemType,
  });

  final String name;
  final ToolParameterType type;
  final String description;
  final bool required;
  final bool nullable;
  final ToolParameterType? itemType;

  Map<String, Object?> toJson() {
    final schema = <String, Object?>{};
    if (type == ToolParameterType.array) {
      schema['type'] = ToolParameterType.array.jsonType;
      schema['items'] = {'type': (itemType ?? ToolParameterType.string).jsonType};
    } else {
      schema['type'] = type.jsonType;
    }
    if (nullable) {
      schema['nullable'] = true;
    }
    if (description.isNotEmpty) {
      schema['description'] = description;
    }
    return schema;
  }
}

class Tool {
  const Tool({
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  final String name;
  final String description;
  final List<ToolParameter> parameters;

  Map<String, Object?> toJson() {
    final properties = <String, Object?>{};
    final requiredFields = <String>[];
    for (final parameter in parameters) {
      properties[parameter.name] = parameter.toJson();
      if (parameter.required) {
        requiredFields.add(parameter.name);
      }
    }

    final function = <String, Object?>{
      'name': name,
      'description': description,
    };
    if (properties.isNotEmpty) {
      function['parameters'] = {
        'type': 'object',
        'properties': properties,
        if (requiredFields.isNotEmpty) 'required': requiredFields,
      };
    }

    return {'type': 'function', 'function': function};
  }

  String toJsonString() => jsonEncode(toJson());
}
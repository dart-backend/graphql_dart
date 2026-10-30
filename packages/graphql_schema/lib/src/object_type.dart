part of 'schema.dart';

/// A [GraphQLType] that specifies the shape of structured data, with multiple fields that can be resolved independently of one another.
class GraphQLObjectType
    extends GraphQLType<Map<String, dynamic>, Map<String, dynamic>>
    with _NonNullableMixin<Map<String, dynamic>, Map<String, dynamic>> {
  /// The name of this type.
  @override
  final String name;

  final String? polymorphicName;

  /// An optional description of this type; useful for tools like GraphiQL.
  @override
  final String? description;

  /// The list of fields that an object of this type is expected to have.
  final List<GraphQLObjectField> fields = [];

  /// `true` if this type should be treated as an *interface*, which child types can [inheritFrom].
  ///
  /// In GraphQL, the parent class is *aware* of all the [possibleTypes] that can implement it.
  final bool isInterface;

  final List<GraphQLObjectType> _interfaces = [];

  final List<GraphQLObjectType> _possibleTypes = [];

  /// A list of other types that this object type is known to implement.
  List<GraphQLObjectType> get interfaces =>
      List<GraphQLObjectType>.unmodifiable(_interfaces);

  /// A list of other types that implement this interface.
  List<GraphQLObjectType> get possibleTypes =>
      List<GraphQLObjectType>.unmodifiable(_possibleTypes);

  GraphQLObjectType(
    this.name,
    this.description, {
    this.isInterface = false,
    this.polymorphicName,
  });

  /// The input type [coerceToInputObject] built for this type, set before its
  /// fields are filled in, so a field that refers back to this type reuses it.
  GraphQLInputObjectType? _inputObject;

  /// The types whose input types are being built by the outermost running
  /// [coerceToInputObject] call, in the order they were started.
  static List<GraphQLObjectType>? _converting;

  /// Returns this type's input type, named `${name}Input`.
  ///
  /// It is built once and reused, so fields added to this type after the first
  /// call are not included. See [toInputObject] for which fields are kept.
  @override
  GraphQLType<Map<String, dynamic>, Map<String, dynamic>>
  coerceToInputObject() {
    var cached = _inputObject;
    if (cached != null) return cached;
    _checkCanBeInput();

    var outermost = _converting == null;
    var converting = _converting ??= [];
    var start = converting.length;
    var input = _inputObject = GraphQLInputObjectType(
      '${name}Input',
      description: description,
    );
    converting.add(this);

    try {
      input.inputFields.addAll(_inputFields());
      return input;
    } catch (_) {
      // Types started since this one may refer to its unfinished input type.
      for (var type in converting.sublist(start)) {
        type._inputObject = null;
      }
      converting.length = start;
      rethrow;
    } finally {
      if (outermost) _converting = null;
    }
  }

  /// Converts [this] into a [GraphQLInputObjectType] named [name].
  ///
  /// A nullable field whose type cannot be an input, such as a union or
  /// interface, is left out. A non-null one throws an [UnsupportedError], as
  /// does an interface, or an object left with no input fields. A field that
  /// refers to an object type uses that type's [coerceToInputObject].
  ///
  /// With the name `${this.name}Input`, it is the input type of
  /// [coerceToInputObject], shared with the fields that refer to this type; a
  /// different [description] throws an [ArgumentError], as two input types
  /// cannot have one name.
  GraphQLInputObjectType toInputObject(String name, {String? description}) {
    if (name == '${this.name}Input') {
      // Checked first, so a call that throws does not build the shared type.
      if (description != null && description != this.description) {
        throw ArgumentError.value(
          description,
          'description',
          'The input type "$name" is shared by the fields that refer to '
              '"${this.name}", so it keeps its own description; give another '
              'name for another description',
        );
      }
      return coerceToInputObject() as GraphQLInputObjectType;
    }

    _checkCanBeInput();
    return GraphQLInputObjectType(
      name,
      description: description ?? this.description,
      inputFields: _inputFields(),
    );
  }

  void _checkCanBeInput() {
    if (isInterface) {
      throw UnsupportedError(
        'The interface type "$name" cannot be used as an input type.',
      );
    }
  }

  List<GraphQLInputObjectField> _inputFields() {
    var out = <GraphQLInputObjectField>[];

    for (var f in fields) {
      GraphQLType type;
      try {
        type = f.type.coerceToInputObject();
      } on UnsupportedError catch (e) {
        if (f.type is! GraphQLNonNullableType) continue;
        throw UnsupportedError(
          'Cannot convert "$name" to an input type: its non-null field '
          '"${f.name}", of type ${f.type}, cannot be an input. ${e.message}',
        );
      }
      out.add(
        GraphQLInputObjectField(f.name, type, description: f.description),
      );
    }

    if (out.isEmpty) {
      throw UnsupportedError(
        'Cannot convert "$name" to an input type: none of its fields can be an '
        'input.',
      );
    }
    return out;
  }

  /// Declares that this type inherits from another parent type.
  ///
  /// This also has the side effect of notifying the parent that this type is its descendant.
  void inheritFrom(GraphQLObjectType other) {
    if (!_interfaces.contains(other)) {
      _interfaces.add(other);
      other._possibleTypes.add(this);
      other._interfaces.forEach(inheritFrom);
    }
  }

  @override
  ValidationResult<Map<String, dynamic>> validate(String key, input) {
    if (input is! Map) {
      return ValidationResult._failure(['Expected "$key" to be an object.']);
    }

    if (isInterface) {
      var errors = <String>[];

      for (var type in possibleTypes) {
        var result = type.validate(key, input);

        if (result.successful) {
          return result;
        } else {
          errors.addAll(result.errors);
        }
      }

      return ValidationResult<Map<String, dynamic>>._failure(errors);
    }

    var out = {};
    var errors = <String>[];

    for (var field in fields) {
      if (field.type is GraphQLNonNullableType) {
        if (!input.containsKey(field.name) || input[field.name] == null) {
          errors.add(
            'Field "${field.name}", of type ${field.type}, cannot be null.',
          );
        }
      }
    }

    for (var k in input.keys) {
      var field = fields.firstWhereOrNull((f) => f.name == k);

      if (field == null) {
        errors.add(
          'Unexpected field "$k" encountered in $key. Accepted values on type $name: ${fields.map((f) => f.name).toList()}',
        );
      } else {
        var v = input[k];

        // Null for a non-null field was already reported above.
        if (v == null) {
          if (field.type is! GraphQLNonNullableType) out[k] = v;
          continue;
        }

        // Only resolver output is validated against an object type, so a value
        // may be a Dart value (such as an enum's) to convert first.
        var result = field.type.validate(
          k.toString(),
          _convertOutput(field.type, v),
        );

        if (!result.successful) {
          errors.addAll(result.errors.map((s) => '$key: $s'));
        } else {
          out[k] = result.value;
        }
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult._failure(errors);
    } else {
      return ValidationResult._ok(_foldToStringDynamic(out));
    }
  }

  @override
  Map<String, dynamic> serialize(Map value) {
    return value.keys.fold<Map<String, dynamic>>({}, (out, k) {
      var field = fields.firstWhereOrNull((f) => f.name == k);
      if (field == null) {
        throw UnsupportedError(
          'Cannot serialize field "$k", which was not defined in the schema.',
        );
      }
      var v = value[k];
      return out..[k.toString()] = v == null ? null : field.serialize(v);
    });
  }

  @override
  Map<String, dynamic> deserialize(Map serialized) {
    return serialized.keys.fold<Map<String, dynamic>>({}, (out, k) {
      var field = fields.firstWhereOrNull((f) => f.name == k);
      if (field == null) {
        throw UnsupportedError('Unexpected field "$k" encountered in map.');
      }
      var v = serialized[k];
      return out..[k.toString()] = v == null ? null : field.deserialize(v);
    });
  }

  /// Returns `true` if this type, or any of its parents, is a direct descendant of another given [type].
  bool isImplementationOf(GraphQLObjectType type) {
    if (type == this) {
      return true;
    } else if (interfaces.contains(type)) {
      return true;
    } else if (interfaces.isNotEmpty) {
      return interfaces.any((t) => t.isImplementationOf(type));
    } else {
      return false;
    }
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    return other is GraphQLObjectType &&
        other.name == name &&
        other.description == description &&
        other.isInterface == isInterface &&
        _compareOnce(
          this,
          other,
          () =>
              const ListEquality<GraphQLObjectField>().equals(
                other.fields,
                fields,
              ) &&
              //        const ListEquality<GraphQLObjectType>() Removed, as it causes a stack overflow :(
              //            .equals(other.interfaces, interfaces) &&
              const ListEquality<GraphQLObjectType>().equals(
                other.possibleTypes,
                possibleTypes,
              ),
        );
  }

  @override
  // Fields are left out: hashing them would recurse forever on self-referencing
  // types. Equal objects still share these values, so they hash equally.
  int get hashCode => hash3(name, description, isInterface);
}

/// The types whose fields are being compared, each to the types it is being
/// compared with, by identity, as comparing them by `==` would recurse.
final _comparing = Map<Object, Set<Object>>.identity();

/// Runs [compare] on the fields of [a] and [b], or returns `true` if they are
/// already being compared further up, in either order: types that refer to
/// themselves, or to each other, are equal when all else about them is.
bool _compareOnce(Object a, Object b, bool Function() compare) {
  if ((_comparing[a]?.contains(b) ?? false) ||
      (_comparing[b]?.contains(a) ?? false)) {
    return true;
  }
  var others = _comparing[a] ??= Set.identity();
  others.add(b);
  try {
    return compare();
  } finally {
    others.remove(b);
    if (others.isEmpty) _comparing.remove(a);
  }
}

/// Converts resolver output [value] for validation against [type]. Lists are
/// converted item by item, so one item that cannot be converted is reported on
/// its own instead of leaving the whole list unconverted.
dynamic _convertOutput(GraphQLType type, dynamic value) => switch (type) {
  GraphQLNonNullableType(:var ofType) => _convertOutput(ofType, value),
  GraphQLListType(:var ofType) when value is Iterable => [
    for (var v in value) v == null ? null : _convertOutput(ofType, v),
  ],
  _ => type.convert(value) ?? value,
};

Map<String, dynamic> _foldToStringDynamic(Map map) {
  return map.keys.fold<Map<String, dynamic>>(
    <String, dynamic>{},
    (out, k) => out..[k.toString()] = map[k],
  );
}

enum DirectiveLocation {
  query,
  mutation,
  subscription,
  field,
  fragmentDefinition,
  fragmentSpread,
  inlineFragment,
  variableDefinition,
}

class GraphQLDirectiveType extends GraphQLInputObjectType {
  GraphQLDirectiveType(
    super.name, {
    super.description,
    required this.locations,
    super.inputFields,
  });

  final Set<DirectiveLocation> locations;
}

/// A special [GraphQLType] that specifies the shape of an object that can only be used as an input to a [GraphQLField].
///
/// GraphQL input object types are different from regular [GraphQLObjectType]s in that they do not support resolution,
/// and are overall more limiter in utility, because their only purpose is to reduce the number of parameters to a given field,
/// and to potentially reuse an input structure across multiple fields in the hierarchy.
class GraphQLInputObjectType
    extends GraphQLType<Map<String, dynamic>, Map<String, dynamic>>
    with _NonNullableMixin<Map<String, dynamic>, Map<String, dynamic>> {
  /// The name of this type.
  @override
  final String name;

  /// An optional type of this type, which is useful for tools like GraphiQL.
  @override
  final String? description;

  /// A list of the fields that an input object of this type is expected to have.
  final List<GraphQLInputObjectField> inputFields = [];

  GraphQLInputObjectType(
    this.name, {
    this.description,
    Iterable<GraphQLInputObjectField> inputFields = const [],
  }) {
    this.inputFields.addAll(inputFields);
  }

  @override
  ValidationResult<Map<String, dynamic>> validate(String key, input) {
    if (input is! Map) {
      return ValidationResult._failure(['Expected "$key" to be an object.']);
    }

    var out = {};
    var errors = <String>[];

    for (var field in inputFields) {
      if (field.type is GraphQLNonNullableType) {
        if (!input.containsKey(field.name) || input[field.name] == null) {
          errors.add(
            'Field "${field.name}", of type ${field.type}, cannot be null.',
          );
        }
      }
    }

    for (var k in input.keys) {
      var field = inputFields.firstWhereOrNull((f) => f.name == k);

      if (field == null) {
        errors.add(
          'Unexpected field "$k" encountered in $key. Accepted values on type $name: ${inputFields.map((f) => f.name).toList()}',
        );
      } else {
        var v = input[k];

        // Null for a non-null field was already reported above.
        if (v == null) {
          if (field.type is! GraphQLNonNullableType) out[k] = v;
          continue;
        }

        var result = field.type.validate(k.toString(), v);

        if (!result.successful) {
          errors.addAll(result.errors.map((s) => '$key: $s'));
        } else {
          out[k] = result.value;
        }
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult._failure(errors);
    } else {
      return ValidationResult._ok(_foldToStringDynamic(out));
    }
  }

  @override
  Map<String, dynamic> serialize(Map value) {
    return value.keys.fold<Map<String, dynamic>>({}, (out, k) {
      var field = inputFields.firstWhereOrNull((f) => f.name == k);
      if (field == null) {
        throw UnsupportedError(
          'Cannot serialize field "$k", which was not defined in the schema.',
        );
      }
      var v = value[k];
      return out..[k.toString()] = v == null ? null : field.type.serialize(v);
    });
  }

  @override
  Map<String, dynamic> deserialize(Map serialized) {
    return serialized.keys.fold<Map<String, dynamic>>({}, (out, k) {
      var field = inputFields.firstWhereOrNull((f) => f.name == k);
      if (field == null) {
        throw UnsupportedError('Unexpected field "$k" encountered in map.');
      }
      var v = serialized[k];
      return out..[k.toString()] = v == null ? null : field.type.deserialize(v);
    });
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    return other is GraphQLInputObjectType &&
        other.name == name &&
        other.description == description &&
        _compareOnce(
          this,
          other,
          () => const ListEquality<GraphQLInputObjectField>().equals(
            other.inputFields,
            inputFields,
          ),
        );
  }

  @override
  // Input fields are left out, as in [GraphQLObjectType.hashCode].
  int get hashCode => hash2(name, description);

  @override
  GraphQLType<Map<String, dynamic>, Map<String, dynamic>>
  coerceToInputObject() => this;
}

/// A field expected within a [GraphQLInputObjectType].
class GraphQLInputObjectField<Value, Serialized> {
  /// The name of this field.
  final String name;

  /// The type that a value for this field is validated against.
  final GraphQLType<Value, Serialized> type;

  /// A description of this field, which is useful for tools like GraphiQL.
  final String? description;

  /// An optional default value for this field in an input object.
  final Value? defaultValue;

  GraphQLInputObjectField(
    this.name,
    this.type, {
    this.description,
    this.defaultValue,
  });

  @override
  bool operator ==(other) =>
      other is GraphQLInputObjectField &&
      other.name == name &&
      other.type == type &&
      other.description == description &&
      other.defaultValue == defaultValue;

  @override
  int get hashCode => hash4(name, type, description, defaultValue);
}

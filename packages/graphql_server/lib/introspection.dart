import 'package:collection/collection.dart' show IterableExtension;
import 'package:recase/recase.dart';
import 'package:graphql_schema2/graphql_schema2.dart';

/// Performs introspection over a GraphQL [schema], and returns a one, containing
/// introspective information.
///
/// [allTypes] should contain all types, not directly defined in the schema, that you
/// would like to have introspection available for.
GraphQLSchema reflectSchema(GraphQLSchema schema, List<GraphQLType?> allTypes) {
  var typeType = _reflectSchemaTypes()!;
  var directiveType = _reflectDirectiveType();

  Set<GraphQLType?>? allTypeSet;

  var schemaType = objectType('__Schema', fields: [
    field(
      'types',
      listOf(typeType),
      resolve: (_, __) => allTypeSet ??= allTypes.toSet(),
    ),
    field(
      'queryType',
      typeType,
      resolve: (_, __) => schema.queryType,
    ),
    field(
      'mutationType',
      typeType,
      resolve: (_, __) => schema.mutationType,
    ),
    field(
      'subscriptionType',
      typeType,
      resolve: (_, __) => schema.subscriptionType,
    ),
    field(
      'directives',
      listOf(directiveType),
      resolve: (_, __) =>
          schema.directiveTypes, // TODO: Actually fetch directives
    ),
  ]);

  allTypes.addAll([
    graphQLBoolean,
    graphQLString,
    graphQLId,
    graphQLDate,
    graphQLFloat,
    graphQLInt,
    directiveType,
    typeType,
    schemaType,
    _typeKindType,
    _directiveLocationType,
    _reflectFields(),
    _reflectInputValueType(),
    _reflectEnumValueType(),
  ]);

  var fields = <GraphQLObjectField>[
    field(
      '__schema',
      schemaType,
      resolve: (_, __) => schemaType,
    ),
    field(
      '__type',
      typeType,
      inputs: [GraphQLFieldInput('name', graphQLString.nonNullable())],
      resolve: (_, args) {
        var name = args['name'] as String?;
        return allTypes.firstWhere((t) => t!.name == name,
            orElse: () => throw GraphQLException.fromMessage(
                'No type named "$name" exists.'));
      },
    ),
  ];

  fields.addAll(schema.queryType!.fields);

  return GraphQLSchema(
    queryType: objectType(schema.queryType!.name, fields: fields),
    mutationType: schema.mutationType,
    subscriptionType: schema.subscriptionType,
  );
}

GraphQLObjectType? _typeType;

GraphQLObjectType? _reflectSchemaTypes() {
  if (_typeType == null) {
    _typeType = _createTypeType();
    _typeType!.fields.add(
      field(
        'ofType',
        _reflectSchemaTypes()!,
        resolve: (type, _) {
          if (type is GraphQLListType) {
            return type.ofType;
          } else if (type is GraphQLNonNullableType) {
            return type.ofType;
          }
          return null;
        },
      ),
    );

    _typeType!.fields.add(
      field(
        'interfaces',
        listOf(_reflectSchemaTypes()!.nonNullable()),
        resolve: (type, _) {
          if (type is GraphQLObjectType) {
            return type.interfaces;
          } else {
            return <GraphQLType>[];
          }
        },
      ),
    );

    _typeType!.fields.add(
      field(
        'possibleTypes',
        listOf(_reflectSchemaTypes()!.nonNullable()),
        resolve: (type, _) {
          if (type is GraphQLObjectType && type.isInterface) {
            return type.possibleTypes;
          } else if (type is GraphQLUnionType) {
            return type.possibleTypes;
          } else {
            return null;
          }
        },
      ),
    );

    var fieldType = _reflectFields()!;
    var inputValueType = _reflectInputValueType();
    var typeField = fieldType.fields.firstWhereOrNull((f) => f.name == 'type');

    if (typeField == null) {
      fieldType.fields.add(
        field(
          'type',
          _reflectSchemaTypes()!,
          resolve: (f, _) => (f as GraphQLObjectField).type,
        ),
      );
    }

    typeField = inputValueType.fields.firstWhereOrNull((f) => f.name == 'type');

    if (typeField == null) {
      inputValueType.fields.add(
        field(
          'type',
          _reflectSchemaTypes()!,
          resolve: (f, _) =>
              _fetchFromInputValue(f, (f) => f.type, (f) => f.type),
        ),
      );
    }
  }

  return _typeType;
}

final GraphQLEnumType<String> _typeKindType =
    enumTypeFromStrings('__TypeKind', [
  'SCALAR',
  'OBJECT',
  'INTERFACE',
  'UNION',
  'ENUM',
  'INPUT_OBJECT',
  'LIST',
  'NON_NULL'
]);

GraphQLObjectType _createTypeType() {
  var enumValueType = _reflectEnumValueType();
  var fieldType = _reflectFields()!;
  var inputValueType = _reflectInputValueType();

  return objectType('__Type', fields: [
    field(
      'name',
      graphQLString,
      resolve: (type, _) => (type as GraphQLType).name,
    ),
    field(
      'description',
      graphQLString,
      resolve: (type, _) => (type as GraphQLType).description,
    ),
    field(
      'kind',
      _typeKindType,
      resolve: (type, _) {
        var t = type as GraphQLType;

        if (t is GraphQLEnumType) {
          return 'ENUM';
        } else if (t is GraphQLScalarType) {
          return 'SCALAR';
        } else if (t is GraphQLInputObjectType) {
          return 'INPUT_OBJECT';
        } else if (t is GraphQLObjectType) {
          return t.isInterface ? 'INTERFACE' : 'OBJECT';
        } else if (t is GraphQLListType) {
          return 'LIST';
        } else if (t is GraphQLNonNullableType) {
          return 'NON_NULL';
        } else if (t is GraphQLUnionType) {
          return 'UNION';
        } else {
          throw UnsupportedError('Cannot get the kind of $t.');
        }
      },
    ),
    field(
      'fields',
      listOf(fieldType),
      inputs: [
        GraphQLFieldInput(
          'includeDeprecated',
          graphQLBoolean,
          defaultValue: false,
        ),
      ],
      resolve: (type, args) => type is GraphQLObjectType
          ? type.fields
              .where(
                  (f) => !f.isDeprecated || args['includeDeprecated'] == true)
              .toList()
          : null,
    ),
    field(
      'enumValues',
      listOf(enumValueType.nonNullable()),
      inputs: [
        GraphQLFieldInput(
          'includeDeprecated',
          graphQLBoolean,
          defaultValue: false,
        ),
      ],
      resolve: (obj, args) {
        if (obj is GraphQLEnumType) {
          return obj.values
              .where(
                  (f) => !f.isDeprecated || args['includeDeprecated'] == true)
              .toList();
        } else {
          return null;
        }
      },
    ),
    field(
      'inputFields',
      listOf(inputValueType.nonNullable()),
      resolve: (obj, _) {
        if (obj is GraphQLInputObjectType) {
          return obj.inputFields;
        }

        return null;
      },
    ),
  ]);
}

GraphQLObjectType? _fieldType;

GraphQLObjectType? _reflectFields() {
  _fieldType ??= _createFieldType();

  return _fieldType;
}

GraphQLObjectType _createFieldType() {
  var inputValueType = _reflectInputValueType();

  return objectType('__Field', fields: [
    field(
      'name',
      graphQLString,
      resolve: (f, _) => (f as GraphQLObjectField).name,
    ),
    field(
      'description',
      graphQLString,
      resolve: (f, _) => (f as GraphQLObjectField).description,
    ),
    field(
      'isDeprecated',
      graphQLBoolean,
      resolve: (f, _) => (f as GraphQLObjectField).isDeprecated,
    ),
    field(
      'deprecationReason',
      graphQLString,
      resolve: (f, _) => (f as GraphQLObjectField).deprecationReason,
    ),
    field(
      'args',
      listOf(inputValueType.nonNullable()).nonNullable(),
      resolve: (f, _) => (f as GraphQLObjectField).inputs,
    ),
  ]);
}

GraphQLObjectType? _inputValueType;

T? _fetchFromInputValue<T>(x, T Function(GraphQLFieldInput) ifInput,
    T Function(GraphQLInputObjectField) ifObjectField) {
  if (x is GraphQLFieldInput) {
    return ifInput(x);
  } else if (x is GraphQLInputObjectField) {
    return ifObjectField(x);
  } else {
    return null;
  }
}

dynamic _def(dynamic f, dynamic Function(dynamic) serializer) {
  final val = f.defaultValue;

  if (val != null) {
    return serializer(val)?.toString();
  }

  return null;
}

GraphQLObjectType _reflectInputValueType() {
  return _inputValueType ??= objectType('__InputValue', fields: [
    field(
      'name',
      graphQLString.nonNullable(),
      resolve: (obj, _) =>
          _fetchFromInputValue(obj, (f) => f.name, (f) => f.name),
    ),
    field(
      'description',
      graphQLString,
      resolve: (obj, _) =>
          _fetchFromInputValue(obj, (f) => f.description, (f) => f.description),
    ),
    field(
      'defaultValue',
      graphQLString,
      resolve: (obj, _) => _fetchFromInputValue(obj,
          (f) => _def(f, f.type.serialize), (f) => _def(f, f.type.serialize)),
    ),
  ]);
}

GraphQLObjectType? _directiveType;

final GraphQLEnumType<String> _directiveLocationType = enumTypeFromStrings(
    '__DirectiveLocation',
    DirectiveLocation.values
        .map((v) => v.name.snakeCase.toUpperCase())
        .toList());

GraphQLObjectType _reflectDirectiveType() {
  var inputValueType = _reflectInputValueType();

  return _directiveType ??= objectType('__Directive', fields: [
    field(
      'name',
      graphQLString.nonNullable(),
      resolve: (obj, _) => (obj as GraphQLDirectiveType).name,
    ),
    field(
      'description',
      graphQLString,
      resolve: (obj, _) => (obj as GraphQLDirectiveType).description,
    ),
    field(
      'locations',
      listOf(_directiveLocationType.nonNullable()).nonNullable(),
      resolve: (obj, _) => (obj as GraphQLDirectiveType)
          .locations
          .map((v) => v.name.snakeCase.toUpperCase())
          .toList(),
    ),
    field(
      'args',
      listOf(inputValueType.nonNullable()).nonNullable(),
      resolve: (obj, _) => (obj as GraphQLDirectiveType).inputFields,
    ),
  ]);
}

GraphQLObjectType? _enumValueType;

GraphQLObjectType _reflectEnumValueType() {
  return _enumValueType ??= objectType(
    '__EnumValue',
    fields: [
      field(
        'name',
        graphQLString.nonNullable(),
        resolve: (obj, _) => (obj as GraphQLEnumValue).name,
      ),
      field(
        'description',
        graphQLString,
        resolve: (obj, _) => (obj as GraphQLEnumValue).description,
      ),
      field(
        'isDeprecated',
        graphQLBoolean.nonNullable(),
        resolve: (obj, _) => (obj as GraphQLEnumValue).isDeprecated,
      ),
      field(
        'deprecationReason',
        graphQLString,
        resolve: (obj, _) => (obj as GraphQLEnumValue).deprecationReason,
      ),
    ],
  );
}

List<GraphQLType?> fetchAllTypes(
    GraphQLSchema schema, List<GraphQLType?> specifiedTypes) {
  var data = <GraphQLType?>{}
    ..add(schema.queryType)
    ..addAll(specifiedTypes);

  if (schema.mutationType != null) {
    data.add(schema.mutationType);
  }

  if (schema.subscriptionType != null) {
    data.add(schema.subscriptionType);
  }

  return CollectTypes(data).types.toList();
}

class CollectTypes {
  Set<GraphQLType?> traversedTypes = {};

  Set<GraphQLType?> get types => traversedTypes;

  CollectTypes(Iterable<GraphQLType?> types) {
    types.forEach(_fetchAllTypesFromType);
  }

  CollectTypes.fromRootObject(GraphQLObjectType type) {
    _fetchAllTypesFromObject(type);
  }

  void _fetchAllTypesFromObject(GraphQLObjectType objectType) {
    if (traversedTypes.contains(objectType)) {
      return;
    }

    traversedTypes.add(objectType);

    for (var field in objectType.fields) {
      if (field.type is GraphQLObjectType) {
        _fetchAllTypesFromObject(field.type as GraphQLObjectType);
      } else if (field.type is GraphQLInputObjectType) {
        for (var v in (field.type as GraphQLInputObjectType).inputFields) {
          _fetchAllTypesFromType(v.type);
        }
      } else {
        _fetchAllTypesFromType(field.type);
      }

      for (var input in field.inputs) {
        _fetchAllTypesFromType(input.type);
      }
    }

    for (var i in objectType.interfaces) {
      _fetchAllTypesFromObject(i);
    }

    for (var i in objectType.possibleTypes) {
      _fetchAllTypesFromObject(i);
    }
  }

  void _fetchAllTypesFromType(GraphQLType? type) {
    if (traversedTypes.contains(type)) {
      return;
    }

    /*
     * Unwrap generics
     */
    if (type is GraphQLNonNullableType) {
      return _fetchAllTypesFromType(type.ofType);
    }
    if (type is GraphQLListType) {
      return _fetchAllTypesFromType(type.ofType);
    }

    /*
     * Handle simple types
     */
    if (type is GraphQLEnumType) {
      traversedTypes.add(type);
      return;
    }
    if (type is GraphQLUnionType) {
      traversedTypes.add(type);
      for (var t in type.possibleTypes) {
        _fetchAllTypesFromType(t);
      }
      return;
    }
    if (type is GraphQLInputObjectType) {
      traversedTypes.add(type);
      for (var v in type.inputFields) {
        _fetchAllTypesFromType(v.type);
      }
      return;
    }

    /*
     * defer to object type traverser
     */
    if (type is GraphQLObjectType) {
      return _fetchAllTypesFromObject(type);
    }

    return;
  }
}

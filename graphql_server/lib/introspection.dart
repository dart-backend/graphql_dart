import 'package:graphql_parser/graphql_parser.dart';
import 'package:graphql_schema/graphql_schema.dart';

// TODO: How to handle custom types???
GraphQLSchema reflectSchema(GraphQLSchema schema, List<GraphQLType> allTypes) {
  var objectTypes = fetchAllTypes(schema);
  var typeType = _reflectSchemaTypes();
  var directiveType = _reflectDirectiveType();
  allTypes.addAll(objectTypes);

  var schemaType = objectType('__Schema', fields: [
    field(
      'types',
      type: listType(typeType),
      resolve: (_, __) => objectTypes,
    ),
    field(
      'queryType',
      type: typeType,
      resolve: (_, __) => schema.query,
    ),
    field(
      'mutationType',
      type: typeType,
      resolve: (_, __) => schema.mutation,
    ),
    field(
      'directives',
      type: listType(directiveType).nonNullable(),
      resolve: (_, __) => [], // TODO: Actually fetch directives
    ),
  ]);

  allTypes.addAll([
    directiveType,
    typeType,
    schemaType,
    _reflectFields(),
    _reflectDirectiveType(),
    _reflectInputValueType(),
  ]);

  var fields = <GraphQLField>[
    field(
      '__schema',
      type: schemaType,
      resolve: (_, __) => schemaType,
    ),
    field(
      '__type',
      type: typeType,
      arguments: [
        new GraphQLFieldArgument('name', graphQLString.nonNullable())
      ],
      resolve: (_, args) {
        var name = args['name'] as String;
        return objectTypes.firstWhere((t) => t.name == name,
            orElse: () =>
                throw new GraphQLException('No type named "$name" exists.'));
      },
    ),
  ];

  fields.addAll(schema.query.fields);

  return new GraphQLSchema(
    query: objectType(schema.query.name, fields: fields),
    mutation: schema.mutation,
  );
}

GraphQLObjectType _typeType;

GraphQLObjectType _reflectSchemaTypes() {
  if (_typeType == null) {
    _typeType = _createTypeType();
    _typeType.fields.add(
      field(
        'ofType',
        type: _reflectSchemaTypes(),
        resolve: (type, _) {
          if (type is GraphQLListType)
            return type.innerType;
          else if (type is GraphQLNonNullableType) return type.innerType;
          return null;
        },
      ),
    );

    var fieldType = _reflectFields();
    var inputValueType = _reflectInputValueType();
    var typeField = fieldType.fields
        .firstWhere((f) => f.name == 'type', orElse: () => null);

    if (typeField == null) {
      fieldType.fields.add(
        field(
          'type',
          type: _reflectSchemaTypes(),
          resolve: (f, _) => (f as GraphQLField).type,
        ),
      );
    }

    typeField = fieldType.fields
        .firstWhere((f) => f.name == 'type', orElse: () => null);

    if (typeField == null) {
      inputValueType.fields.add(
        field(
          'type',
          type: _reflectSchemaTypes(),
          resolve: (f, _) => (f as GraphQLFieldArgument).type,
        ),
      );
    }
  }

  return _typeType;
}

GraphQLObjectType _createTypeType() {
  var fieldType = _reflectFields();

  return objectType('__Type', fields: [
    field(
      'name',
      type: graphQLString,
      resolve: (type, _) => (type as GraphQLType).name,
    ),
    field(
      'description',
      type: graphQLString,
      resolve: (type, _) => (type as GraphQLType).description,
    ),
    field(
      'kind',
      type: graphQLString,
      resolve: (type, _) {
        var t = type as GraphQLType;

        if (t is GraphQLScalarType)
          return 'SCALAR';
        else if (t is GraphQLObjectType)
          return 'OBJECT';
        else if (t is GraphQLListType)
          return 'LIST';
        else if (t is GraphQLNonNullableType)
          return 'NON_NULL';
        else
          throw new UnsupportedError(
              'Cannot get the kind of $t.'); // TODO: Interface + union
      },
    ),
    field(
      'fields',
      type: listType(fieldType),
      arguments: [
        new GraphQLFieldArgument(
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
          : [],
    ),
  ]);
}

GraphQLObjectType _fieldType;

GraphQLObjectType _reflectFields() {
  if (_fieldType == null) {
    _fieldType = _createFieldType();
  }

  return _fieldType;
}

GraphQLObjectType _createFieldType() {
  var inputValueType = _reflectInputValueType();

  return objectType('__Field', fields: [
    field(
      'name',
      type: graphQLString,
      resolve: (f, _) => (f as GraphQLField).name,
    ),
    field(
      'isDeprecated',
      type: graphQLBoolean,
      resolve: (f, _) => (f as GraphQLField).isDeprecated,
    ),
    field(
      'deprecationReason',
      type: graphQLString,
      resolve: (f, _) => (f as GraphQLField).deprecationReason,
    ),
    field(
      'args',
      type: listType(inputValueType.nonNullable()).nonNullable(),
      resolve: (f, _) => (f as GraphQLField).arguments,
    ),
  ]);
}

GraphQLObjectType _inputValueType;

GraphQLObjectType _reflectInputValueType() {
  return _inputValueType ??= objectType('__InputValue', fields: [
    field(
      'name',
      type: graphQLString,
      resolve: (obj, _) => (obj as GraphQLFieldArgument).name,
    ),
    field(
      'description',
      type: graphQLString,
      resolve: (obj, _) => (obj as GraphQLFieldArgument).description,
    ),
    field(
      'defaultValue',
      type: graphQLString,
      resolve: (obj, _) =>
          (obj as GraphQLFieldArgument).defaultValue?.toString(),
    ),
  ]);
}

GraphQLObjectType _reflectDirectiveType() {
  var inputValueType = _reflectInputValueType();

  // TODO: What actually is this???
  return objectType('__Directive', fields: [
    field(
      'name',
      type: graphQLString.nonNullable(),
      resolve: (obj, _) => (obj as DirectiveContext).NAME.span.text,
    ),
    field(
      'description',
      type: graphQLString,
      resolve: (obj, _) => null,
    ),
    field(
      'locations',
      type: listType(graphQLString.nonNullable()).nonNullable(),
      // TODO: Enum directiveLocation
      resolve: (obj, _) => [],
    ),
    field(
      'args',
      type: listType(inputValueType.nonNullable()).nonNullable(),
      resolve: (obj, _) => [],
    ),
  ]);
}

List<GraphQLObjectType> fetchAllTypes(GraphQLSchema schema) {
  var typess = <GraphQLType>[];
  typess.addAll(_fetchAllTypesFromObject(schema.query));

  if (schema.mutation != null) {
    typess.addAll(_fetchAllTypesFromObject(schema.mutation)
        .where((t) => t is GraphQLObjectType));
  }

  var types = <GraphQLObjectType>[];

  for (var type in typess) {
    if (type is GraphQLObjectType) types.add(type);
  }

  return types.toSet().toList();
}

List<GraphQLType> _fetchAllTypesFromObject(GraphQLObjectType objectType) {
  var types = <GraphQLType>[objectType];

  for (var field in objectType.fields) {
    if (field.type is GraphQLObjectType) {
      types.addAll(_fetchAllTypesFromObject(field.type as GraphQLObjectType));
    } else {
      types.addAll(_fetchAllTypesFromType(field.type));
    }
  }

  return types;
}

Iterable<GraphQLType> _fetchAllTypesFromType(GraphQLType type) {
  var types = <GraphQLType>[];

  if (type is GraphQLNonNullableType) {
    types.addAll(_fetchAllTypesFromType(type.innerType));
  } else if (type is GraphQLListType) {
    types.addAll(_fetchAllTypesFromType(type.innerType));
  } else if (type is GraphQLObjectType) {
    types.addAll(_fetchAllTypesFromObject(type));
  }

  // TODO: Enum, interface, union
  return types;
}
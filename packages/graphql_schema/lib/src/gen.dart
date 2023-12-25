part of 'schema.dart';

/// Shorthand for generating a [GraphQLObjectType].
GraphQLObjectType objectType(String name,
    {String? description,
    bool isInterface = false,
    Iterable<GraphQLObjectField> fields = const [],
    Iterable<GraphQLObjectType> interfaces = const [],
    Iterable<GraphQLObjectType> subs = const [],
    String? polymorphicName}) {
  var obj = GraphQLObjectType(name, description,
      isInterface: isInterface, polymorphicName: polymorphicName)
    ..fields.addAll(fields);

  if (interfaces.isNotEmpty == true) {
    for (var i in interfaces) {
      obj.inheritFrom(i);
    }
  }

  if (subs.isNotEmpty) {
    for (final sub in subs) {
      sub.inheritFrom(obj);
    }
  }

  return obj;
}

/// Shorthand for generating a [GraphQLObjectField].
GraphQLObjectField<T, Serialized> field<T, Serialized>(
    String name, GraphQLType<T, Serialized> type,
    {Iterable<GraphQLFieldInput<T, Serialized>> inputs = const [],
    GraphQLFieldResolver<T, Serialized>? resolve,
    String? deprecationReason,
    String? description}) {
  return GraphQLObjectField<T, Serialized>(name, type,
      arguments: inputs,
      resolve: resolve,
      description: description,
      deprecationReason: deprecationReason);
}

/// Shorthand for generating a [GraphQLInputObjectType].
GraphQLInputObjectType inputObjectType(String name,
    {String? description,
    Iterable<GraphQLInputObjectField> inputFields = const []}) {
  return GraphQLInputObjectType(name,
      description: description, inputFields: inputFields);
}

/// Shorthand for generating a [GraphQLInputObjectField].
GraphQLInputObjectField<T, Serialized> inputField<T, Serialized>(
    String name, GraphQLType<T, Serialized> type,
    {String? description, T? defaultValue}) {
  return GraphQLInputObjectField(name, type,
      description: description, defaultValue: defaultValue);
}

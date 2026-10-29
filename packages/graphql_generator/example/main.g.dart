// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// _GraphQLGenerator
// **************************************************************************

/// Auto-generated from [TodoItem].
final GraphQLObjectType todoItemGraphQLType = objectType(
  'TodoItem',
  isInterface: false,
  interfaces: [],
  fields: [
    field<dynamic, dynamic>(
      'id',
      graphQLId,
      resolve: (obj, _) => (obj as TodoItem).id,
    ),
    field<dynamic, dynamic>(
      'text',
      graphQLString,
      resolve: (obj, _) => (obj as TodoItem).text,
    ),
    field<dynamic, dynamic>(
      'isComplete',
      graphQLBoolean,
      description: 'Whether this item is complete.',
      resolve: (obj, _) => (obj as TodoItem).isComplete,
    ),
  ],
);

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
      resolve: (obj, _) => obj is TodoItem
          ? obj.id
          : obj == null
          ? null
          : throw GraphQLException.fromMessage(
              'Cannot resolve field "id" of "TodoItem" from a value of type ${obj.runtimeType}: expected a Map or an instance of TodoItem.',
            ),
    ),
    field<dynamic, dynamic>(
      'text',
      graphQLString,
      resolve: (obj, _) => obj is TodoItem
          ? obj.text
          : obj == null
          ? null
          : throw GraphQLException.fromMessage(
              'Cannot resolve field "text" of "TodoItem" from a value of type ${obj.runtimeType}: expected a Map or an instance of TodoItem.',
            ),
    ),
    field<dynamic, dynamic>(
      'isComplete',
      graphQLBoolean,
      description: 'Whether this item is complete.',
      resolve: (obj, _) => obj is TodoItem
          ? obj.isComplete
          : obj == null
          ? null
          : throw GraphQLException.fromMessage(
              'Cannot resolve field "isComplete" of "TodoItem" from a value of type ${obj.runtimeType}: expected a Map or an instance of TodoItem.',
            ),
    ),
  ],
);

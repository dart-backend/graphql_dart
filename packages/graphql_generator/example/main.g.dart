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
    field('id', graphQLId),
    field('text', graphQLString),
    field(
      'isComplete',
      graphQLBoolean,
      description: 'Whether this item is complete.',
    ),
  ],
);

# Graphql Generator 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_generator2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_generator/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Generates `package:graphql_schema2` schemas for annotated class.

Replaces `convertDartType` from `package:graphql_server2`.

## Usage

Usage is very simple. You just need a `@graphQLClass` or `@GraphQLClass()` annotation on any class you want to generate an object type for.

Individual fields can have a `@GraphQLDocumentation()` annotation, to provide information like descriptions, deprecation reasons, etc.

```dart
@graphQLClass
@GraphQLDocumentation(description: 'Todo object type')
class Todo {
  String text;

  /// Whether this item is complete
  bool isComplete;
}

void main() {
  print(todoGraphQLType.fields.map((f) => f.name));
}
```

The following is generated (as of April 18th, 2019):

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// _GraphQLGenerator
// **************************************************************************

/// Auto-generated from [Todo].
final GraphQLObjectType todoGraphQLType = objectType('Todo',
    isInterface: false,
    description: 'Todo object type',
    interfaces: [],
    fields: [
      field('text', graphQLString),
      field('isComplete', graphQLBoolean, description: 'Whether this item is complete')
    ]);
```

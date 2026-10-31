# Graphql Generator 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_generator2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_generator/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

A `build_runner` builder that generates [`package:graphql_schema2`](https://pub.dev/packages/graphql_schema2) types from annotated Dart classes and enums, with resolvers that read fields from instances of the classes. It works with the models of [`package:angel3_serialize`](https://pub.dev/packages/angel3_serialize).

It replaces `convertDartType`, which was removed from `package:graphql_server2` in 9.0.0, and needs no `dart:mirrors`.

## Installation

```yaml
dependencies:
  graphql_schema2: ^8.0.0

dev_dependencies:
  build_runner: ^2.7.0
  graphql_generator2: ^8.0.0
```

## Usage

Annotate a class or an enum with `@graphQLClass` (or `@GraphQLClass()`), add a `part` for the generated code, and run `dart run build_runner build`:

```dart
import 'package:graphql_schema2/graphql_schema2.dart';

part 'main.g.dart';

@graphQLClass
class TodoItem {
  @GraphQLDocumentation(typeName: #graphQLId)
  String? id;

  String? text;

  @GraphQLDocumentation(description: 'Whether this item is complete.')
  bool? isComplete;
}

void main() {
  print(todoItemGraphQLType.fields.map((f) => f.name)); // (id, text, isComplete)
}
```

This generates `todoItemGraphQLType`, a `GraphQLObjectType` with a field for each of the class's fields. Each field has a resolver that reads it from a `TodoItem`:

```dart
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
    // ... the fields text and isComplete, alike.
  ],
);
```

So a resolver can return either a `TodoItem` or a `Map` with the same fields. A `Map` is read by key before the resolver runs, so a type's resolvers apply only to objects; any other value is a GraphQL error naming the field.

Complete example: [`example/main.dart`](https://github.com/dart-backend/graphql_dart/tree/master/packages/graphql_generator/example/main.dart)

## Types of fields

The type of a field is inferred from its Dart type:

* `String`, `int`, `double`, `bool` and `DateTime` are `String`, `Int`, `Float`, `Boolean` and `Date`;
* a class or enum annotated with `@graphQLClass` is its generated type, such as `todoGraphQLType` of `Todo`;
* a `List` or other `Iterable` is a list of its item type;
* the `id` of a [`Model`](https://pub.dev/packages/angel3_model) is an `ID`.

To set the type of a field yourself, give the name of a top-level `GraphQLType` with `@GraphQLDocumentation(typeName: #myType)`. An enum field resolves to its Dart value, which its GraphQL enum type outputs as its name, so `typeName` can point to an `enumType` whose names differ from the Dart names.

## Documentation and deprecation

A field's description comes from its doc comment, or from `@GraphQLDocumentation(description: ...)`, and a class's likewise. `@Deprecated('...')` marks a field deprecated, with its message as the reason.

## Fields left out

These are not generated:

* static and private fields;
* computed getters inherited from a parent class, such as `Model.idAsInt`;
* fields the serializer excludes, with `@SerializableField(exclude: true)` or `@exclude` (unless `canSerialize: true`), so a field such as a password hash is not part of the schema.

## With `angel3_serialize` models

On a `@serializable` model, the generated type is named after the generated class, and fields are named as the serializer names them (snake case by default):

```dart
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:graphql_schema2/graphql_schema2.dart';

part 'todo.g.dart';

@serializable
@graphQLClass
abstract class TodoEntity extends Model {
  String? get text;

  @GraphQLDocumentation(description: 'Whether this item is complete.')
  bool? get isComplete;
}
```

Run the builder of `angel3_serialize_generator` too: it generates the `Todo` class, and this builder `todoGraphQLType`, with the fields `id`, `created_at`, `updated_at`, `text` and `is_complete`. Resolvers can return `Todo` models or the maps of `toJson()`.

See the [change log](https://pub.dev/packages/graphql_generator2/changelog) for what changed in 8.0.0.

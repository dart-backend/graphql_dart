# GraphQL Schema 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_schema2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_schema/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

An implementation of GraphQL's type system in Dart. It runs on any platform Dart runs on, and does not use `dart:mirrors`. It is designed to be close to the JavaScript reference implementation, [graphql-js](https://graphql.org/graphql-js/type/), and many names are the same.

It builds every GraphQL type:

* the scalars `String`, `Int`, `Float`, `Boolean` and `ID`, and `Date`, an ISO 8601 string that deserializes to a Dart `DateTime`;
* object types and interfaces (`GraphQLObjectType`);
* input object types (`GraphQLInputObjectType`);
* enum types (`GraphQLEnumType`);
* union types (`GraphQLUnionType`);
* list and non-null types.

For the full description of GraphQL's type system, see the [GraphQL specification](https://spec.graphql.org/).

To execute queries against a schema, use [`package:graphql_server2`](https://pub.dev/packages/graphql_server2). To generate types from Dart classes, use [`package:graphql_generator2`](https://pub.dev/packages/graphql_generator2).

## Installation

```yaml
dependencies:
  graphql_schema2: ^8.0.0
```

## Usage

Define a schema with the [helper functions](#helpers):

```dart
import 'package:graphql_schema2/graphql_schema2.dart';

final todoType = objectType(
  'Todo',
  fields: [
    field('text', graphQLString.nonNullable()),
    field('created_at', graphQLDate),
  ],
);

final todoSchema = graphQLSchema(
  queryType: objectType(
    'Query',
    fields: [
      field(
        'todos',
        listOf(todoType.nonNullable()),
        resolve: (_, _) => [
          {'text': 'Clean your room!', 'created_at': DateTime.now()},
        ],
      ),
    ],
  ),
);
```

All GraphQL types are generic, `GraphQLType<Value, Serialized>`: `Value` is the Dart value, and `Serialized` its form in a request or response.

## Helpers

* `graphQLSchema` creates a `GraphQLSchema`.
* `objectType` creates a `GraphQLObjectType` with fields, and with `isInterface: true` an interface.
* `field` creates a field of an object type, with its type, arguments (`inputs`) and `resolve` callback.
* `listOf` creates a list of another type.
* `inputObjectType` and `inputField` create an input object type and its fields.
* `enumType` and `enumTypeFromStrings` create an enum type.

The scalar types are `graphQLString`, `graphQLId`, `graphQLBoolean`, `graphQLInt`, `graphQLFloat` and `graphQLDate`.

## Non-null and list types

Call `nonNullable()` on a type to make it non-null, and use `listOf` for lists:

```dart
/// [Int!]!: a non-null list of non-null integers.
final scores = listOf(graphQLInt.nonNullable()).nonNullable();
```

A list item may be `null` only if the item type is nullable, and the Dart list type can hold `null`: `listOf(graphQLString)` is a list of non-nullable Dart `String`s, while `listOf<dynamic, dynamic>(graphQLString)` accepts `null` items.

## Arguments and resolvers

Take this query:

```graphql
{
  characters(title: "Hunter x Hunter") {
    name
    age
  }
}
```

and its schema:

```graphql
type Query {
  characters(title: String!): [Character!]
}

type Character {
  name: String
  age: Int
}
```

Give a field its arguments with `GraphQLFieldInput`, and a `resolve` callback that loads its value. The callback gets the parent value, the object the field belongs to, and a map of the arguments:

```dart
final characterType = objectType(
  'Character',
  fields: [field('name', graphQLString), field('age', graphQLInt)],
);

final queryType = objectType(
  'Query',
  fields: [
    field(
      'characters',
      listOf(characterType.nonNullable()),
      inputs: [GraphQLFieldInput('title', graphQLString.nonNullable())],
      resolve: (_, args) async => findCharacters(args['title'] as String),
    ),
  ],
);

Future<List<Map<String, dynamic>>> findCharacters(String title) async => [
  {'name': 'Gon', 'age': 12},
];
```

A field without a `resolve` callback is read from its parent by name when the parent is a `Map`. To resolve fields of other objects, such as model classes, give the fields resolvers, or generate them with `package:graphql_generator2`:

```dart
class Character {
  final String name;
  Character(this.name);
}

final characterNameType = objectType(
  'CharacterName',
  fields: [
    field(
      'name',
      graphQLString,
      resolve: (character, _) => (character as Character).name,
    ),
  ],
);
```

## Enums

`enumType` maps the names of an enum to Dart values, and `enumTypeFromStrings` to strings of the same names:

```dart
enum Color { red, green }

final colorType = enumType('Color', {'RED': Color.red, 'GREEN': Color.green});
final sizeType = enumTypeFromStrings('Size', ['SMALL', 'LARGE']);
```

A resolver can return the Dart value, such as `Color.red`, which is output as its name, `RED`. A Dart enum value named like one of the type's names, such as a `Size.SMALL`, is output as that name too, so a model serialized to a map, which keeps its enum values, can be returned.

## Input objects

Arguments of object shape use input object types:

```dart
final todoInput = inputObjectType(
  'TodoInput',
  inputFields: [
    inputField('text', graphQLString.nonNullable()),
    inputField('done', graphQLBoolean),
  ],
);
```

`coerceToInputObject()` builds the input type of an object type, named `${name}Input`. It is built once, and shared by every field that refers to the object type, so a type that refers to itself works. A field whose type cannot be an input is left out if it is nullable, such as a union or an interface; a non-null one, an interface itself, or an object with no input fields left, throws an `UnsupportedError`.

## Serialization and validation

A type can `serialize` a Dart value, `deserialize` it back, and `validate` input:

```dart
void main() {
  var iso8601String = graphQLDate.serialize(DateTime.now());
  var date = graphQLDate.deserialize(iso8601String);
  print(date.millisecondsSinceEpoch);

  var validation = todoType.validate('@root', {'text': 'Clean your room!'});
  if (validation.successful) {
    print(validation.value);
  } else {
    print(validation.errors);
  }
}
```

`validate` returns a failed `ValidationResult` for input of the wrong type, rather than throwing. An `Int` is accepted, and converted, where a `Float` is expected.

See the [change log](https://pub.dev/packages/graphql_schema2/changelog) for what changed in 8.0.0.

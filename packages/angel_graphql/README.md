# Angel3 Graphql

![Logo](../img/angel3_logo.png)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_graphql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/angel_graphql/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

- [Angel3 Graphql](#angel3-graphql)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Subscriptions](#subscriptions)
  - [Using Services](#using-services)
  - [Generating Types](#generating-types)

GraphQL for the [Angel3 framework](https://pub.dev/packages/angel3_framework): request handlers that serve a GraphQL API over HTTP and WebSockets, GraphiQL, and resolvers backed by Angel services. It builds on [`package:graphql_server2`](https://pub.dev/packages/graphql_server2), which implements the [GraphQL specification](https://spec.graphql.org/), so you can build a GraphQL backend with Dart and virtually any database.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.0.0
  angel3_graphql: ^10.0.0
  angel3_serialize: ^10.0.0
  graphql_schema2: ^8.0.0
  graphql_server2: ^9.0.0

dev_dependencies:
  angel3_serialize_generator: ^10.0.0
  build_runner: ^2.7.0
  graphql_generator2: ^8.0.0
```

The generators are needed only to generate GraphQL types from your models, as below.

## Usage

Using this package is much like GraphQL.js: define a schema, and mount `graphQLHttp` in your router to serve it. Introspection is supported, so you can explore the API with GraphiQL.

A schema has a *query* type, of the operations that read data, and optionally a *mutation* type, of those that change it, and a *subscription* type, of real-time events (see [Subscriptions](#subscriptions)).

Here, `todoGraphQLType` is generated from the `TodoEntity` model by `package:graphql_generator2` (see [Generating Types](#generating-types)), so GraphQL knows the model without duplicated effort. Run `dart run build_runner build` to generate it:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';

part 'main.g.dart';

@serializable
@graphQLClass
abstract class TodoEntity extends Model {
  String? get text;

  @GraphQLDocumentation(description: 'Whether this item is complete.')
  bool? get isComplete;
}

void main() async {
  var app = Angel();
  var http = AngelHttp(app);
  var todoService = app.use('api/todos', MapService());

  var queryType = objectType(
    'Query',
    description: 'A simple API that manages your to-do list.',
    fields: [
      field(
        'todos',
        listOf(todoGraphQLType.nonNullable()),
        resolve: resolveViaServiceIndex(todoService),
      ),
      field(
        'todo',
        todoGraphQLType,
        resolve: resolveViaServiceRead(todoService),
        inputs: [GraphQLFieldInput('id', graphQLId.nonNullable())],
      ),
    ],
  );

  var mutationType = objectType(
    'Mutation',
    description: 'Modify the to-do list.',
    fields: [
      field(
        'createTodo',
        todoGraphQLType,
        inputs: [
          GraphQLFieldInput('data', todoGraphQLType.coerceToInputObject()),
        ],
        resolve: resolveViaServiceCreate(todoService),
      ),
    ],
  );

  var schema = graphQLSchema(queryType: queryType, mutationType: mutationType);

  // Serve GraphQL, and GraphiQL to explore it in development.
  app.all('/graphql', graphQLHttp(GraphQL(schema)));
  app.get('/graphiql', graphiQL());

  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
  print('Access GraphiQL at http://${server.address.address}:${server.port}/graphiql');
}
```

Visit `/graphiql`, and you'll see the GraphiQL UI, ready to go:

![GraphiQL screenshot](../img/angel_graphql.png)

Complete example: [`example/main.dart`](https://github.com/dart-backend/graphql_dart/tree/master/packages/angel_graphql/example/main.dart)

## Subscriptions

Example: [`example/subscription.dart`](https://github.com/dart-backend/graphql_dart/tree/master/packages/angel_graphql/example/subscription.dart)

Clients can subscribe to streams of events from the server. In your schema, return a `Stream` from a `resolve` callback, rather than a plain object:

```dart
var postAdded = postService.afterCreated
    .asStream()
    .map((e) => {'postAdded': e.result})
    .asBroadcastStream();

var schema = graphQLSchema(
  queryType: queryType,
  subscriptionType: objectType(
    'Subscription',
    fields: [field('postAdded', postType, resolve: (_, _) => postAdded)],
  ),
);
```

HTTP requests are not suited to pushing data continuously, so `graphQLHttp` does not serve subscriptions unless you handle their streams yourself:

```dart
graphQLHttp(graphQL, onSubscription: (req, res, stream) {
  // Do something with the stream here. It's up to you.
});
```

`graphQLWS` serves them over WebSockets, so you can use existing JavaScript clients:

```dart
app.get('/subscriptions', graphQLWS(GraphQL(schema)));
```

It speaks both WebSocket protocols for GraphQL, chosen by the subprotocol the client asks for:

* `graphql-transport-ws`, of the [`graphql-ws`](https://github.com/enisdenjo/graphql-ws) library, which current clients use, such as Apollo Client 3, urql and GraphiQL 2;
* `graphql-ws`, of Apollo's older `subscriptions-transport-ws`, also for a client that asks for none.

Queries and mutations can be sent over the socket too. To authenticate connections, check the payload of their `connection_init`:

```dart
app.get(
  '/subscriptions',
  graphQLWS(
    GraphQL(schema),
    onConnect: (req, payload) => payload?['token'] == 'secret',
  ),
);
```

A rejected connection is closed (with code 4403 for `graphql-transport-ws`). `keepAliveInterval` sets how often to send keep-alive messages, and `connectionInitWaitTimeout` how long to wait for a `connection_init`.

GraphiQL can use subscriptions too: give `graphiQL` the endpoint, and it adds the `subscriptions-transport-ws` client to its page:

```dart
app.get(
  '/graphiql',
  graphiQL(subscriptionsEndpoint: 'ws://localhost:3000/subscriptions'),
);
```

The bundled GraphiQL page uses the older protocol. **NOTE: Apollo's specification of that protocol is out of date with what its client expects. See <https://github.com/apollographql/subscriptions-transport-ws/issues/551>.**

WebSockets are served over HTTP/1.1.

## Using Services

In Angel, a `Service` implements CRUD operations, and is the database interface of an application. `package:angel3_graphql` resolves fields with services: in the example above, `resolveViaServiceIndex`, `resolveViaServiceRead` and `resolveViaServiceCreate`. In all, there are:

- `resolveViaServiceIndex`
- `resolveViaServiceFindOne`
- `resolveViaServiceRead` (with an `id` argument)
- `resolveViaServiceCreate` (with a `data` argument)
- `resolveViaServiceModify` (with `id` and `data`)
- `resolveViaServiceUpdate` (with `id` and `data`)
- `resolveViaServiceRemove` (with an `id`)

Arguments are passed to the service as its query, with the request's context, and `Providers.graphQL` as the provider, so hooks can tell GraphQL requests apart.

## Generating Types

[`package:graphql_generator2`](https://pub.dev/packages/graphql_generator2) generates a GraphQL type for each `@graphQLClass` model, as `todoGraphQLType` for `TodoEntity` above. With [`package:angel3_serialize_generator`](https://pub.dev/packages/angel3_serialize_generator), `dart run build_runner build` generates both the `Todo` model and `todoGraphQLType`.

Its fields have resolvers, so a resolver can return `Todo` models, the maps of `toJson()`, or the records of a service:

```dart
field(
  'todos',
  listOf(todoGraphQLType),
  resolve: (_, _) => [Todo(text: 'Clean your room!')],
);
```

Fields the serializer excludes, such as `@SerializableField(exclude: true)`, are not part of the GraphQL type. You can also give descriptions to types, fields and arguments, with doc comments, `@GraphQLDocumentation`, or the `description` parameter of most helpers.

See [`package:graphql_generator2`](https://pub.dev/packages/graphql_generator2) and [`package:graphql_schema2`](https://pub.dev/packages/graphql_schema2) for more.

## Migrating from 9.x

`convertDartType` and the other mirrors helpers are removed from `package:graphql_server2`: generate types with `package:graphql_generator2` instead, as above. See the [change log](https://pub.dev/packages/angel3_graphql/changelog) for what changed in 10.0.0.

# Graphql Server 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_server2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_server/LICENSE)

Executes GraphQL queries, mutations and subscriptions against a schema of [`package:graphql_schema2`](https://pub.dev/packages/graphql_schema2), with introspection. It does not depend on any framework, and does not use `dart:mirrors`, so it can be used in any Dart project, including AOT-compiled executables. [Angel3](https://pub.dev/packages/angel3_framework) users might prefer [`package:angel3_graphql`](https://pub.dev/packages/angel3_graphql), the fastest way to build a GraphQL backend in Dart.

## Installation

```yaml
dependencies:
  graphql_schema2: ^8.0.0
  graphql_server2: ^9.0.0
```

## Usage

The `GraphQL` class executes requests against a schema. `parseAndExecute` takes the text of a request and its variables, and returns the data of a query or mutation, or a `Stream` for a subscription. Errors are thrown as a `GraphQLException`, which is JSON-serializable:

```dart
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';

void main() async {
  var schema = graphQLSchema(
    queryType: objectType(
      'Query',
      fields: [
        field(
          'greet',
          graphQLString,
          inputs: [GraphQLFieldInput('name', graphQLString.nonNullable())],
          resolve: (_, args) => 'Hello, ${args['name']}!',
        ),
      ],
    ),
  );
  var graphQL = GraphQL(schema);

  try {
    var data = await graphQL.parseAndExecute(
      r'query Greet($name: String!) { greet(name: $name) }',
      variableValues: {'name': 'Dart'},
    );
    print({'data': data}); // {data: {greet: Hello, Dart!}}
  } on GraphQLException catch (e) {
    print(e.toJson()); // {errors: [...]}
  }
}
```

See the [API reference](https://pub.dev/documentation/graphql_server2/latest/graphql_server2/GraphQL/parseAndExecute.html) for more.

HTTP handling, like `graphQLHttp` in `graphql-js`, is not included, as it depends on the framework you use. The `graphQLHttp` of `package:angel3_graphql` is an example: [`graphql_http.dart`](https://github.com/dart-backend/graphql_dart/tree/master/packages/angel_graphql/lib/src/graphql_http.dart)

## Resolving fields

A field's `resolve` callback gets its parent value and its arguments. A field without one is read from its parent by name, when the parent is a `Map`. For other parents, such as model objects:

* give the fields resolvers, or generate types whose fields have them with [`package:graphql_generator2`](https://pub.dev/packages/graphql_generator2); or
* pass a `defaultFieldResolver` to `GraphQL`, which resolves the fields that have no resolver.

A field that can be resolved neither way is an error that names the field, rather than `null`.

Values are converted to their GraphQL type when they are output: a `DateTime`, or an ISO 8601 string such as those a `MapService` stores, for a `Date`; a Dart enum value for an enum. Arguments and variables are validated against their types, and an `Int` is accepted where a `Float` is expected.

## Subscriptions

A subscription's resolver returns a `Stream`. How events are sent to clients is not part of the GraphQL specification, so it is up to you.

In a schema like this:

```graphql
type Subscription {
  onTodo: TodoAdded!
}

type TodoAdded {
  id: ID!
  text: String!
  isComplete: Boolean
}
```

the resolver of `onTodo` returns a stream of `Map`s, each *with an `onTodo` key*:

```dart
field(
  'onTodo',
  todoAddedType,
  resolve: (_, _) => someStreamOfTodos().map((todo) => {'onTodo': todo}),
);
```

To work with existing tools, such as JavaScript clients, `package:graphql_server2` implements Apollo's [`subscriptions-transport-ws`](https://github.com/apollographql/subscriptions-transport-ws) protocol (`package:graphql_server2/subscriptions_transport_ws.dart`).

**NOTE: Apollo's specification of the protocol is out of date with what its client expects. See <https://github.com/apollographql/subscriptions-transport-ws/issues/551>.**

The implementation is built on `package:stream_channel`, so it can run over any two-way transport: WebSockets, TCP sockets, isolates or others. Extend the `Server` class: it handles the transport and the protocol, and emitting subscription events is up to your implementation.

This is how `graphQLWS` in `package:angel3_graphql` serves one WebSocket:

```dart
var channel = IOWebSocketChannel(socket);
var client = stw.RemoteClient(channel.cast<String>());
var server = _GraphQLWSServer(client, graphQL, req, res, keepAliveInterval);
await server.done;
```

See its source: [`graphql_ws.dart`](https://github.com/dart-backend/graphql_dart/tree/master/packages/angel_graphql/lib/src/graphql_ws.dart)

## Introspection

Clients can query the schema itself through introspection, which the `GraphQL` class handles; pass `introspect: false` to turn it off. To reflect a schema yourself, call `reflectSchema` of `package:graphql_server2/introspection.dart`: [API reference](https://pub.dev/documentation/graphql_server2/latest/introspection/reflectSchema.html)

## Migrating from 8.x

`package:graphql_server2/mirrors.dart`, with `convertDartType` and `mirrorsFieldResolver`, is removed. Generate types with `package:graphql_generator2`, or define them with the helpers of `package:graphql_schema2`. See the [change log](https://pub.dev/packages/graphql_server2/changelog) for the other changes in 9.0.0.

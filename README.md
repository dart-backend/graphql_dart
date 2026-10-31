# GraphQL for Dart

[![Logo](./img/angel3_logo.png)](https://github.com/dart-backend/graphql_dart)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_graphql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

An implementation of the [GraphQL specification](https://spec.graphql.org/June2018/) in Dart: a parser, a type system, an execution engine with subscriptions over WebSockets, a code generator, a DataLoader, and an integration with the [Angel3](https://github.com/dart-backend/angel) framework. It does not use `dart:mirrors`, so servers can be compiled ahead of time with `dart compile exe`.

The goal of this project is to provide an alternative to REST APIs for server-side development in Dart, with GraphQL and virtually any database.

## Packages

This monorepo holds several packages, each with its own documentation and examples:

| Package | Version | Description |
|---|---|---|
| [`graphql_parser2`](packages/graphql_parser) | 8.0.0 | A recursive descent parser of the GraphQL language. |
| [`graphql_schema2`](packages/graphql_schema) | 8.0.0 | GraphQL's type system: scalars, objects, interfaces, unions, enums, input objects, and custom scalars. |
| [`graphql_server2`](packages/graphql_server) | 9.0.0 | Executes queries, mutations and subscriptions, with introspection. Serves subscriptions over WebSockets with both the `graphql-transport-ws` protocol of current clients and Apollo's older `subscriptions-transport-ws`. Depends on no framework. |
| [`graphql_generator2`](packages/graphql_generator) | 8.0.0 | Generates `graphql_schema2` types, with resolvers, from Dart classes and `angel3_serialize` models. |
| [`graphql_data_loader2`](packages/graphql_data_loader) | 8.0.0 | Batches and caches lookups: a Dart port of [`graphql/dataloader`](https://github.com/graphql/dataloader). |
| [`angel3_graphql`](packages/angel_graphql) | 10.0.0 | Serves GraphQL with Angel3 over HTTP (including file uploads) and WebSockets, with GraphiQL, and resolvers backed by Angel services. |

## Quick start

With Angel3, mount `graphQLHttp` for queries and mutations, `graphQLWS` for subscriptions, and `graphiQL` to explore the API:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
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
          inputs: [GraphQLFieldInput('name', graphQLString)],
          resolve: (_, args) => 'Hello, ${args['name'] ?? 'world'}!',
        ),
      ],
    ),
  );
  var graphQL = GraphQL(schema);

  var app = Angel();
  app.all('/graphql', graphQLHttp(graphQL));
  app.get('/subscriptions', graphQLWS(graphQL));
  app.get('/graphiql', graphiQL(subscriptionsEndpoint: '/subscriptions'));

  var server = await AngelHttp(app).startServer('127.0.0.1', 3000);
  print('GraphiQL at http://${server.address.address}:${server.port}/graphiql');
}
```

Without Angel3, `graphql_server2`'s `GraphQL.parseAndExecute` runs a request in any Dart program; see its [README](packages/graphql_server/README.md). To generate types from your models rather than define them by hand, see [`graphql_generator2`](packages/graphql_generator/README.md).

## Upgrading

This release changes the major version of every package. The main changes:

* `graphql_server2` no longer has `dart:mirrors` helpers such as `convertDartType`: generate types with `graphql_generator2`, whose fields now have resolvers, so resolvers can return model objects as well as maps.
* `graphql_server2` and `angel3_graphql` serve subscriptions with the `graphql-transport-ws` protocol of current clients, such as Apollo Client 3, urql and GraphiQL 2, as well as the older protocol, and `angel3_graphql` serves GraphiQL 4.
* Many fixes to the parser, the type system, execution and the HTTP handler, such as running the operation of `operationName`, GET requests and multipart file uploads.

Each package's change log lists its changes, the breaking ones first.

## Development

1. Fork the `graphql_dart` repository, clone your fork, and create a branch:

   ```bash
   git clone https://github.com/<your_account>/graphql_dart.git
   cd graphql_dart
   git checkout -b feature/<your_branch_name>
   ```

2. Install [Dart](https://dart.dev/get-dart) 3.13 or later.

3. Get the dependencies at the root: the repository is a [pub workspace](https://dart.dev/tools/pub/workspaces), so this resolves every package together.

   ```bash
   dart pub get
   ```

   [Melos](https://pub.dev/packages/melos) runs a command in every package, for example `melos exec -- "dart test"`; install it with `dart pub global activate melos`.

4. Make your changes. After changing `graphql_generator2`, regenerate its example with `dart run build_runner build --delete-conflicting-outputs` in `packages/graphql_generator`.

5. In each package you changed, check formatting, analyze, and run the tests:

   ```bash
   dart format --output=none --set-exit-if-changed .
   dart analyze
   dart test
   ```

   CI runs these for every package except `angel3_graphql`, so run that package's checks yourself.

Pull requests target the `master` branch.

## Donation & Support

If you like this project and are interested in supporting its development, you can make a donation via [PayPal](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US).

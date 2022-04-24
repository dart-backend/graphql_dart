# Angel3 Graphql

![Logo](https://github.com/angel-dart/graphql/raw/master/img/angel_logo.png)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_graphql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/graphql_dart)](https://github.com/dukefirehawk/graphql_dart/blob/master/angel_graphql/LICENSE)

- [Angel3 Graphql](#angel3-graphql)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Subscriptions](#subscriptions)
  - [Using Services](#using-services)
  - [Documentation](#documentation)
  - [Mirrors](#mirrors)

A complete implementation of the official [GraphQL specification](https://facebook.github.io/graphql/October2016/#sec-Language) - these are the [Angel3 framework](https://pub.dev/packages/angel3_framework)-specific bindings.

The goal of this project is to provide to server-side users of Dart an alternative to REST API's. `package:angel3_graphql`, which, when combined with the allows server-side Dart users to build backends with GraphQL and virtually any database imaginable.

## Installation

To install `package:angel3_graphql`, add the following to your `pubspec.yaml`:

```yaml
dependencies:
    angel3_framework: ^6.0.0
    angel3_graphql: ^6.0.0
```

## Usage

Using this package is very similar to GraphQL.js - you define a schema, and then mount `graphQLHttp` in your router to start serving. This implementation supports GraphQL features like introspection, so you can play around with `graphiql` as well!

Firstly, define your schema. A GraphQL schema contains an *object type* that defines all querying operations that can be applied to the backend.

A GraphQL schema may also have a *mutation* object type, which defines operations that change the backend's state, and optionally a *subscription* type, which defines real-time interactions (coming soon!).

You can use the `convertDartType` helper to wrap your existing `Model`/PODO classes, and make GraphQL aware of them without duplicated effort.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:graphql_server2/mirrors.dart';

Future configureServer(Angel app) async {
    var queryType = objectType(
        'Query',
        description: 'A simple API that manages your to-do list.',
        fields: [
            field(
                'todos',
                listOf(convertDartType(Todo).nonNullable()),
                resolve: resolveViaServiceIndex(todoService),
            ),
            field(
                'todo',
                convertDartType(Todo),
                resolve: resolveViaServiceRead(todoService),
                inputs: [
                    GraphQLFieldInput('id', graphQLId.nonNullable()),
                ],
            ),
        ],
    );

    var mutationType = objectType(
        'Mutation',
        description: 'Modify the to-do list.',
        fields: [
            field(
                'create',
                graphQLString,
            ),
        ],
    );

    var schema = graphQLSchema(
        queryType: queryType,
        mutationType: mutationType,
    );
}
```

After you've created your `GraphQLSchema`, you just need to wrap in a call to `graphQLHttp`, a request handler that responds to GraphQL.

In *development*, it's also highly recommended to mount the `graphiQL` handler, which serves GraphQL's official visual interface, for easy querying and feedback.

```dart
app.all('/graphql', graphQLHttp(GraphQL(schema)));
app.get('/graphiql', graphiQL());
```

All that's left now is just to start the server!

```dart
var server = await http.startServer('127.0.0.1', 3000);
var uri =
    Uri(scheme: 'http', host: server.address.address, port: server.port);
var graphiqlUri = uri.replace(path: 'graphiql');
print('Listening at $uri');
print('Access graphiql at $graphiqlUri');
```

Visit your `/graphiql` endpoint, and you'll see the `graphiql` UI, ready-to-go!

![Graphiql screenshot](./img/angel_graphql.png)

Now you're ready to build a GraphQL API!

## Subscriptions

Example: [`Source code`](https://github.com/dukefirehawk/graphql_dart/tree/master/angel_graphql/example/subscription.dart)

In GraphQL, as of the June 2018 spec, clients can subscribe to streams of events from the server. In your schema, all you need to do is return a `Stream` from a `resolve` callback, rather than a plain object:

```dart
var postAdded = postService.afterCreated
      .asStream()
      .map((e) => {'postAdded': e.result})
      .asBroadcastStream();

var schema = graphQLSchema(
  // ...
  subscriptionType: objectType(
    'Subscription',
    fields: [
      field('postAdded', postType, resolve: (_, __) => postAdded),
    ],
  ),
);
```

By default, `graphQLHttp` has no support for subscriptions, because regular HTTP requests are stateless, and are not ideal for continuous data pushing. You can add your own handler:

```dart
graphQLHttp(graphQL, onSubscription: (req, res, stream) {
  // Do something with the stream here. It's up to you.
});
```

There is, however, `graphQLWS`, which implements Apollo's `subscriptions-transport-ws` protocol:

```dart
app.get('/subscriptions', graphQLWS(GraphQL(schema)));
```

You can then use existing JavaScript clients to handle subscriptions.

The `graphiQL` handler also supports using subscriptions. In the following snippet, the necessary scripts will be added to the rendered page, so that the `subscriptions-transport-ws` client can be used by GraphiQL:

```dart
app.get('/graphiql',
    graphiQL(subscriptionsEndpoint: 'ws://localhost:3000/subscriptions'));
```

**NOTE: Apollo's spec for the aforementioned protocol is very far outdated, and completely inaccurate,**
**See this issue for more:**
**<https://github.com/apollographql/subscriptions-transport-ws/issues/551>**

## Using Services

What would Angel be without services? For those unfamiliar - in Angel, `Service` is a base class that implements CRUD functionality, and serves as the database interface within an Angel application. They are well-suited for NoSQL or other databases without a schema (they can be used with SQL, but that's not their primary focus).

`package:angel3_graphql` has functionality to resolve fields by interacting with services.

Consider our previous example, and note the calls to `resolveViaServiceIndex` and `resolveViaServiceRead`:

```dart
var queryType = objectType(
    'Query',
    description: 'A simple API that manages your to-do list.',
    fields: [
      field(
        'todos',
        listOf(convertDartType(Todo).nonNullable()),
        resolve: resolveViaServiceIndex(todoService),
      ),
      field(
        'todo',
        convertDartType(Todo),
        resolve: resolveViaServiceRead(todoService),
        inputs: [
          GraphQLFieldInput('id', graphQLId.nonNullable()),
        ],
      ),
    ],
  );
```

In all, there are:

- `resolveViaServiceIndex`
- `resolveViaServiceFindOne`
- `resolveViaServiceRead`
- `resolveViaServiceCreate`
- `resolveViaServiceModify`
- `resolveViaServiceUpdate`
- `resolveViaServiceRemove`

As one might imagine, using these convenience helpers makes it much quicker to implement CRUD functionality in a GraphQL API.

## Documentation

Using `package:graphql_generator2`, you can generate GraphQL schemas for concrete Dart types:

```dart
configureServer(Angel app) async {
  var schema = graphQLSchema(
    queryType: objectType('Query', fields: [
      field('todos', listOf(todoGraphQLType), resolve: (_, __) => ...)
    ]);
  );
}

@graphQLClass
class Todo {
  String text;

  @GraphQLDocumentation(description: 'Whether this item is complete.')
  bool isComplete;
}
```

For more documentation, see: [`package:graphql_generator2`](https://pub.dev/packages/graphql_generator2)

## Mirrors

**NOTE: Mirrors support is deprecated, and will not be updated further.**

The `convertDartType` function can automatically read the documentation from a type like the following:

```dart
@GraphQLDocumentation(description: 'Any object with a .text (String) property.')
abstract class HasText {
  String get text;
}

@serializable
@GraphQLDocumentation(
    description: 'A task that might not be completed yet. **Yay! Markdown!**')
class Todo extends Model implements HasText {
  String text;

  @GraphQLDocumentation(deprecationReason: 'Use `completion_status` instead.')
  bool completed;

  CompletionStatus completionStatus;

  Todo({this.text, this.completed, this.completionStatus});
}

@GraphQLDocumentation(description: 'The completion status of a to-do item.')
enum CompletionStatus { COMPLETE, INCOMPLETE }
```

You can also manually provide documentation for parameters and endpoints, via a `description` parameter on almost all related functions.

See [`package:graphql_schema2`](https://pub.dev/packages/graphql_schema2) for more documentation.

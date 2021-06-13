![Logo](./img/angel_logo.png)

<div style="text-align: center">
    <hr>
</div>
[![version](https://img.shields.io/badge/pub-v2.0.0-brightgreen)](https://pub.dartlang.org/packages/graphql_server2)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/graphql_dart)](https://github.com/dukefirehawk/graphql_dart/LICENSE)


A complete implementation of the official
[GraphQL specification](https://graphql.github.io/graphql-spec/June2018/),
in the Dart programming language.

The goal of this project is to provide to server-side
users of Dart an alternative to REST API's.

Included is also
`package:angel3_graphql`, which, when combined with the
[Angel3](https://github.com/dukefirehawk/angel) framework, allows
server-side Dart users to build backends with GraphQL and
virtually any database imaginable.

## Tutorial Demo (click to watch)
[![Youtube thumbnail](video.png)](https://youtu.be/5x6S4kDODa8)

## Projects
This mono repo is split into several sub-projects,
each with its own detailed documentation and examples:
* `angel3_graphql` - Support for handling GraphQL via HTTP and
WebSockets in the [Angel3](https://github.com/dukefirehawk/angel) framework. Also serves as the `package:graphql_server2` reference implementation.
* `graphql_data_loader2` - A Dart port of [`graphql/dataloader`](https://github.com/graphql/dataloader).
* `example_star_wars`: An example GraphQL API built using
`package:angel_graphql2`.
* `graphql_generator2`: Generates `package:graphql_schema2` object types from concrete Dart classes.
* `graphql_parser2`: A recursive descent parser for the GraphQL language.
* `graphql_schema2`: An implementation of GraphQL's type system. This, combined with `package:graphql_parser2`, powers `package:graphql_server2`.
* `graphql_server2`: Base functionality for implementing GraphQL servers in Dart. Has no dependency on any framework.
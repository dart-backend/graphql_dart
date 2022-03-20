# GraphQL for Dart

[![Logo](./img/angel_logo.png)](https://github.com/dukefirehawk/graphql_dart)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_graphql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/graphql_dart)](https://github.com/dukefirehawk/graphql_dart/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

A complete implementation of the official [GraphQL specification](https://graphql.github.io/graphql-spec/June2018/), in the Dart programming language.

The goal of this project is to provide to an alternative to REST API's for server-side development in Dart.

Included is `angel3_graphql`, a plugin which integrates with [Angel3](https://github.com/dukefirehawk/angel) framework to allow developers to build backend services with GraphQL and virtually any supported database in Dart.

## Projects

This mono repo is split into several sub-projects, each with its own detailed documentation and examples:

* `graphql_parser2`: A recursive descent parser for the GraphQL language.
* `graphql_schema2`: An implementation of GraphQL's type system.
* `graphql_generator2`: Generates `graphql_schema2` object types from concrete Dart classes.
* `graphql_data_loader2` - A Dart port of [`graphql/dataloader`](https://github.com/graphql/dataloader).
* `graphql_server2`: Base functionality for implementing GraphQL servers in Dart. Has no dependency on any framework except `graphql_parser2` and `graphql_schema2` packages.
* `angel3_graphql` - An implementation of `graphql_server2` in handling GraphQL via HTTP and WebSockets for [Angel3](https://github.com/dukefirehawk/angel) framework.

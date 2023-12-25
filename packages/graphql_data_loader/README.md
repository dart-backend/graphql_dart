# GraphQL Data Loader 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_data_loader2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_data_loader/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Batch and cache database lookups. Works well with GraphQL. Ported from the original JS version: [`Graphql`](https://github.com/graphql/dataloader)

## Installation

In your pubspec.yaml:

```yaml
dependencies:
  graphql_data_loader2: ^6.0.0
```

## Usage

Complete example: [`Source code`](https://github.com/dart-backend/graphql_dart/tree/master/graphql_data_loader/example/main.dart)

```dart
var userLoader = DataLoader((key) => myBatchGetUsers(keys));
var invitedBy = await userLoader.load(1)then(user => userLoader.load(user.invitedByID))
print('User 1 was invited by $invitedBy'));
```

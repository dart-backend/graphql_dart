# GraphQL Data Loader 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_data_loader2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_data_loader/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Batch and cache database lookups. Works well with GraphQL. A port of the JavaScript [`DataLoader`](https://github.com/graphql/dataloader).

Resolving a list of items often loads each item's related data one at a time, which is the "N+1 queries" problem. A `DataLoader` collects the keys requested during one tick of the event loop, and loads them with a single call.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  graphql_data_loader2: ^8.0.0
```

## Usage

Create a `DataLoader` with a function that loads many keys at once. It must return one value per key, in the order of the keys:

```dart
import 'package:graphql_data_loader2/graphql_data_loader2.dart';

class User {
  final int id;
  final int? invitedById;
  User(this.id, this.invitedById);
}

/// Loads all the users of [ids] with one query, in the order of [ids].
Future<List<User>> fetchUsers(Iterable<int> ids) async =>
    [for (var id in ids) User(id, id == 1 ? 2 : null)];

void main() async {
  var userLoader = DataLoader<int, User>(fetchUsers);

  // Loaded together, with one call to fetchUsers([1, 2]).
  var users = await Future.wait([userLoader.load(1), userLoader.load(2)]);
  print(users.map((u) => u.id));

  // Served from the cache, without calling fetchUsers.
  var user = await userLoader.load(1);
  var invitedBy = await userLoader.load(user.invitedById!);
  print('User 1 was invited by user ${invitedBy.id}');

  userLoader.close();
}
```

Complete GraphQL example: [`example/main.dart`](https://github.com/dart-backend/graphql_dart/tree/master/packages/graphql_data_loader/example/main.dart)

### Batching

* Keys requested in the same tick are loaded together; a key requested twice is loaded once.
* A key requested while its batch is loading gets the same `Future`, and is not loaded again.
* A load made while a batch is running is sent in the next batch.

### Caching

By default, loaded values are cached. Pass `cache: false` to load every time, and manage the cache with:

* `clear(key)` and `clearAll()`, to load a key, or all keys, again;
* `prime(key, value)`, to put a value into the cache without loading it (it does nothing when `cache` is `false`).

### Errors

If the load function throws, or returns more or fewer values than keys, every load of that batch fails with the error. Failed lookups are not cached, so loading the key again retries it.

### Closing

`close()` fails the loads that are waiting with a `StateError`, and clears the cache. A batch already passed to the load function still completes. Calling `load` after `close` throws a `StateError`.

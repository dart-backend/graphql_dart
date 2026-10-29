# Change Log

## 8.0.0

### Breaking changes in 8.0.0

* **Breaking:** `load` throws a `StateError` after `close`, and `close` also clears the cache.
* **Breaking:** If `loadMany` throws, or returns a different number of values than keys, every load in that batch fails with the error. Before, those loads never completed and the loader stopped working.
* **Breaking:** Loading a key again while it is being loaded returns the same `Future` instead of fetching it a second time.

### Fixes in 8.0.0

* **Batching:** A `load` made while a batch is running is sent in the next batch. Before, it never completed unless another load came later.
* **Errors:** A failed lookup is not cached, so loading the key again retries it.
* **Cache:** `prime` does nothing when `cache` is `false`, instead of keeping values that are never read.
* **Performance:** A batch's results are read once and matched to their keys directly, instead of scanning the queue for each key.
* **Example:** The `todo` field returns a single `Todo`, matching its resolver.

## 7.0.0

* Require Dart >= 3.13
* Updated `graphql_schema2` to `7.0.0`

## 6.5.0

* Require Dart >= 3.9

## 6.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 6.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0

## 6.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 6.1.0

* Updated `lints` to 3.0.0
* Fixed linter warnings
* Updated repository link

## 6.0.0

* Require dart >=  3.0.x

## 5.0.0

* Require dart >=  2.17.x

## 4.0.0

* Require dart >= 2.16.x

## 3.0.0

* Updated to SDK 2.15.x

## 2.1.0

* Upgraded from `pendantic` to `lints` linter

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD
* Rename `data_loader` to `graphql_data_loader2`

## 1.0.0

* Initial version.

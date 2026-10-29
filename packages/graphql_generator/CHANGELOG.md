# Change Log

## 8.0.0

### Breaking changes in 8.0.0

* **Breaking:** Requires `angel3_model` and `angel3_serialize_generator` 10.0.0, and `graphql_schema2` 8.0.0.
* **Breaking:** The `id` field of a `Model` is generated as `graphQLId` instead of `graphQLString`.
* **Breaking:** Computed getters inherited from a parent class, such as `Model.idAsInt` and `idAsString`, are no longer generated as fields.
* **Breaking:** `@GraphQLDocumentation` and `@Deprecated` on a field declared as a field (not as a getter) are applied, so its description, deprecation reason and `typeName` now appear in the generated type.

### New in 8.0.0

* The generator no longer imports `dart:mirrors`; `typeName` symbols are read through the analyzer.

### Fixes in 8.0.0

* **Types:** A reference to another generated type is named after the class the serializer generates, so a field of type `TodoEntity` refers to `todoGraphQLType`, as `_Todo` already did.
* **Types:** A nullable field of a generated class or enum type, such as `CompletionStatus?`, generates valid code instead of `completionStatus?GraphQLType`.
* **Deprecation:** The `@Deprecated` message is used as the deprecation reason instead of "Expires: next release.".

## 7.0.0

* Require Dart >= 3.13
* Updated `analyzer` to `14.0.0`
* Updated `angel3_model` to `9.0.0`
* Updated `angel3_serialize_generator` to `9.0.0`
* Updated `graphql_schema2` to `7.0.0`

## 6.5.0

* Require Dart >= 3.9
* Updated `analyzer` to 8.4.x
* Updated `build` to 4.0.x
* Updated `source_gen` to 4.0.x

## 6.4.1

* Fix analyzer warnings

## 6.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release
* Updated `analyzer` to 7.7.x

## 6.3.1

* Fixed `angel3_serialize_generator` import issue

## 6.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Upgraded to `analyzer` 7.0.0

## 6.2.1

* Upgraded to `analyzer` 6.5.x

## 6.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 6.1.0

* Upgraded to `analyzer` 6.3.x
* Updated `lints` to 3.0.0
* Fixed linter warnings
* Updated repository link

## 6.0.0

* Require dart >= 3.0.x

## 5.1.0

* Require dart >= 2.18.x
* Upgraded to `analyzer` 5.x.x
* Replaced deprecated `element2` with `element`

## 5.0.0

* Require dart >= 2.17.x

## 4.1.0

* Updated to `analyzer` 4.x.x

## 4.0.0

* Require dart >= 2.16.x
* Updated `angel3_model` to 6.x.x
* Updated `angel3_serialize_generator` to 6.x.x

## 3.0.0

* Updated to min SDK 2.15.x

## 2.2.0

* Upgraded from `pendantic` to `lints` linter

## 2.1.1

* Updated `build.xml` to use the correct packages

## 2.1.0

* Updated `build.xml` to use `angel3` packages
* Upgraded to support major `analyzer` 2.0.0 release

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD
* Rename `graphql_generator` to `graphql_generator2`

## 1.0.0+1

* Replace `snakeCase` with `camelCase`.

## 1.0.0

* Apply `package:pedantic`.

## 1.0.0-rc.1

* Add `CHANGELOG.md`, `example/main.dart`.
* Add documentation to `README.md`.

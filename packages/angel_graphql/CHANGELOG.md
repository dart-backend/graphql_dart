# Change log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Requires Angel3 10: `angel3_framework`, `angel3_container`, `angel3_file_service`, `angel3_websocket` and `angel3_validate` 10.0.0.
* **Breaking:** Requires `graphql_parser2` 8.0.0, `graphql_schema2` 8.0.0 and `graphql_server2` 9.0.0. See their change logs for the breaking changes in parsing, validation and execution.
* **Breaking:** `graphql_server2` 9.0.0 removes `package:graphql_server2/mirrors.dart`, so `convertDartType` is gone. Generate GraphQL types with `graphql_generator2` instead, as the README and example now do.

### New in 10.0.0

* `graphQLWS` serves the `graphql-transport-ws` protocol of the `graphql-ws` library, which current clients use, such as Apollo Client 3, urql and GraphiQL 2, as well as Apollo's older `subscriptions-transport-ws`, on the same endpoint: the client's WebSocket subprotocol chooses (`graphql-transport-ws`, or `graphql-ws` for the older one, also when it asks for none).
* `graphiQL` serves GraphiQL 4, with React 18, where it served GraphiQL 0.11 from 2018. Its scripts are pinned to exact versions and checked by their integrity hashes. With a `subscriptionsEndpoint`, which may now be a path of the page's host, it runs subscriptions over `graphql-transport-ws`, where it used the `subscriptions-transport-ws` client. The endpoints are written into the page as JSON, so a quote no longer breaks its script.
* `graphQLWS(onConnect: ...)` accepts or rejects a connection, given its request and the payload of its `connection_init`, such as credentials, and `connectionInitWaitTimeout` how long to wait for it.

### Fixes in 10.0.0

* **Uploads:** `graphQLUpload` rejects a value that is not an uploaded file with a validation error, where a string failed with a `TypeError`, and no longer needs to be given to `GraphQL(customTypes: ...)` to be the type of a variable ([#26](https://github.com/dart-backend/graphql_dart/issues/26)). The README tells how to upload files.
* **HTTP:** `graphQLHttp` runs the operation of `operationName`, as GraphiQL and other clients name it, where it read only `operation_name`, so a document of several operations failed with "This document does not define any operations" ([#17](https://github.com/dart-backend/graphql_dart/issues/17)). `operation_name` is still accepted.
* **HTTP:** A GET request reads its `query`, `operationName` and `variables` from its query parameters, where it failed with a `TypeError`. A POST of `application/graphql` reads its body as the query, where it failed with a `TypeError`.
* **HTTP:** A `multipart/form-data` request follows the GraphQL multipart request specification: its `operations` are decoded, with their `query`, `operationName` and `variables`, where they were parsed as the query, and its files are put in the variables at the paths of `map`, also in lists and nested objects, where only paths of one name worked.
* **WebSockets:** `graphQLWS` serves subscriptions, where every connection failed with a `TypeError`, and an operation without variables, where it threw. A subscription stops when the client stops it or disconnects.

* **Docs:** The README's `graphql_generator2` example compiles, and uses a `@serializable` model like the package's example.

## 9.0.0

* Require Dart >= 3.13
* Updated `angel3_file_service` to `9.0.0`
* Updated `angel3_framework` to `9.0.0`
* Updated `angel3_container` to `9.0.0`
* Updated `angel3_websocket` to `9.0.0`
* Updated `angel3_validate` to `9.0.0`
* Updated `graphql_parser2` to `7.0.0`
* Updated `graphql_schema2` to `7.0.0`
* Updated `graphql_server2` to `7.0.0`

## 8.5.0

* Require Dart >= 3.9

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.0

* Updated `lints` to 3.0.0
* Fixed linter warnings
* Updated repository link

## 8.0.1

* Fixed reflector error in the examples

## 8.0.0

* Require dart >= 3.0.x
* Updated `angel3_framework` to 8.x.x

## 7.0.0

* Require dart >= 2.17.x
* Updated `angel3_framework` to 7.x.x

## 6.0.1

* Fixed null warning for logger

## 6.0.0

* Require dart >= 2.16.x
* Updated `angel3_framework` to 6.x.x

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0

* Skipped release

## 2.1.0

* Upgraded from `pendantic` to `lints` linter

## 2.0.2

* Fixed NNBD issues

## 2.0.1

* Updated README

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD
* Rename `angel_graphql` to `angel3_graphql`

## 1.1.0

* Support the GraphQL multipart spec: <https://github.com/jaydenseric/graphql-multipart-request-spec>

## 1.0.0

* Apply `package:pedantic`.

## 1.0.0-rc.0

* Finish `graphQLWS`.

## 1.0.0-beta.1

* Add `graphQLWS` handler, and support subscriptions.

## 1.0.0-beta

* Angel RC updates.

## 1.0.0-alpha

* First official release.

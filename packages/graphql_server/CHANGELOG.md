# Change Log

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

* Require dart >= 3.0.x

## 5.0.0

* Require dart >= 2.17.x

## 4.0.0

* Require dart >= 2.16.x
* Updated `angel3_serialise` to 6.x.x

## 3.0.0

* Fixed enum conversion
* Implemented directives
* Implemented jsonpath directive, example:

  ```graphql
  // you add the directive at the variable definition:
  mutation myQuery($createdId: Int! @jsonpath(path: "$.C0.create.id")) {
    // this mutation will create some object and return the new id
    C0: SomeNamespace {
        create(name: "Some object") {
          id
        }
    }
    // this mutation uses the generated $createdId from the json path directive
    C1: OtherNamespace {
        update(id: 123, relationshipId: $createdId) {
          id
        }
    }
  }
  // you can optionally declare the variable
  {
    createdId: 0 // if the jsonpath directive can't resolve a value, 
    // it will use this (0) instead
  }
  ```

* Added polymorphic names: you can add an alias to a type to use with `on` fragments. This is nice when you have a `__typename` that must be unique like `MyNestedType123` but you would like to use a better name when on fragments: `...on MyType`  
* Updated to SDK 2.15.x

## 2.1.1

* Fixed bug in enums

## 2.1.0

* Upgraded from `pendantic` to `lints` linter

## 2.0.1

* Fixed NNBD issues

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD
* Rename `graphql_server` to `graphql_server2`

## 1.1.0

* Updates for `package:graphql_parser@1.2.0`.
* Now that variables are `InputValueContext` descendants, handle them the
same way as other values in `coerceArgumentValues`. TLDR - Removed
now-obsolete, variable-specific logic in `coerceArgumentValues`.
* Pass `argumentName`, not `fieldName`, to type validations.

## 1.0.3

* Make field resolution asynchronous.
* Make introspection cycle-safe.
* Thanks @deep-guarav and @micimize!

## 1.0.2

* <https://github.com/angel-dart/graphql/pull/32>

## 1.0.1

* Fix a bug where `globalVariables` were not being properly passed
to field resolvers.

## 1.0.0

* Finish testing.
* Add `package:pedantic` fixes.

## 1.0.0-rc.0

* Get the Apollo support working with the latest version of `subscriptions-transport-ws`.

## 1.0.0-beta.4

For some reason, Pub was not including `subscriptions_transport_ws.dart`.

## 1.0.0-beta.3

* Introspection on subscription types (if any).

## 1.0.0-beta.2

* Fix bug where field aliases would not be resolved.

## 1.0.0-beta.1

* Add (currently untested) subscription support.

## 1.0.0-beta

* First release.

# Change Log

## 9.0.0

### Breaking changes in 9.0.0

* **Breaking:** The `package:graphql_server2/mirrors.dart` library is removed, so the package no longer uses `dart:mirrors`. `convertDartType`, `convertDartClass`, `objectTypeFromClassMirror`, `enumTypeFromClassMirror`, `fieldFromGetter` and `mirrorsFieldResolver` are gone. Generate types with `graphql_generator2` or define them with the `graphql_schema2` helpers, and return `Map`s from resolvers or give fields their own `resolve` callbacks.
* **Breaking:** A field that has no resolver, on a parent value that is not a `Map`, such as a model object, is reported as an error naming the field, instead of resolving to `null`. Pass a `defaultFieldResolver` to resolve such fields.
* **Breaking:** No longer depends on `angel3_serialize`, `meta` or `tuple`. Add them to your own `pubspec.yaml` if you used them through this package.

To keep resolving fields from model objects instead of `mirrorsFieldResolver`, pass a `defaultFieldResolver` that reads them, for example from `toJson()`:

```dart
var graphQL = GraphQL(
  schema,
  defaultFieldResolver: <T>(T obj, String? name, Map<String, dynamic> _) =>
      (obj as dynamic).toJson()[name] as T,
);
```

### Fixes in 9.0.0

* **Scalars:** A scalar field whose value is already in its serialized form, and valid, is output as it is, so a `Date` field accepts an ISO 8601 string, as a `MapService` stores dates, instead of failing with "must be DateTime".
* **Arguments:** Arguments and variables are deserialized from their validated value, so an `Int` given for `Float!`, `[Float]` or a `Float!` input field is coerced instead of throwing a `TypeError`.

## 8.0.0

### Breaking changes in 8.0.0

* **Breaking:** Requires `graphql_parser2` 8.0.0, whose inline fragments may have no type condition.
* **Breaking:** Requires `graphql_schema2` 8.0.0, whose `validate` returns a failed `ValidationResult` for wrongly typed input instead of throwing. Wrongly typed variables are reported as GraphQL errors.
* **Breaking:** An argument given as a variable takes the variable's coerced value as is, instead of being validated and deserialized again.
* **Breaking:** An omitted or `null` variable for an argument with a default value takes that default, instead of failing.

### Fixes in 8.0.0

* **Unions:** A field of a union type no longer throws a `TypeError` when its value is completed.
* **Variables:** Enum variables are accepted; they failed because their Dart value was validated again as a name.
* **Variables:** A `null` variable for a non-null argument is reported as an error naming the argument.
* **Directives:** `@skip` and `@include` apply to fragment spreads and inline fragments, not only fields.
* **Directives:** `@skip` and `@include` find their `if` argument among several arguments.
* **Fragments:** An inline fragment without a type condition applies to any type.

## 7.0.0

* Require Dart >= 3.13
* Updated `angel3_serialize` to `9.0.0`
* Updated `graphql_schema2` to `7.0.0`
* Updated `graphql_parser2` to `7.0.0`

## 6.5.0

* Require Dart >= 3.9

## 6.4.1

* Fix analyzer warnings

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

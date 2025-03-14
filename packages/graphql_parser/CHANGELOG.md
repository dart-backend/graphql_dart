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

## 3.0.0

* Implemented directives
* Updated to SDK 2.15.x

## 2.1.0

* Upgraded from `pendantic` to `lints` linter

## 2.0.2

* Fixed NNBD issues

## 2.0.1

* Updated array_value.dart
* Updated string_value.dart

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD
* Rename `graphql_parser` to `graphql_parser2`

## 1.2.0

* Combine `ValueContext` and `VariableContext` into a single `InputValueContext` supertype.
  * Add `T computeValue(Map<String, dynamic> variables);`
  * Resolve [##23](https://github.com/angel-dart/graphql/issues/23).
* Deprecate old `ValueOrVariable` class, and parser/AST methods related to it.

## 1.1.4

* Fix broken int variable parsing - <https://github.com/angel-dart/graphql/pull/32>

## 1.1.3

* Add `Parser.nextName`, and remove all formerly-reserved words from the lexer.
Resolves [##19](https://github.com/angel-dart/graphql/issues/19).

## 1.1.2

* Parse the `subscription` keyword.

## 1.1.1

* Pubspec updates for Dart 2.

## 1.1.0

* Removed `GraphQLVisitor`.
* Enable parsing operations without an explicit
name.
* Parse `null`.
* Completely ignore commas.
* Ignore Unicode BOM, as per the spec.
* Parse object values.
* Parse enum values.

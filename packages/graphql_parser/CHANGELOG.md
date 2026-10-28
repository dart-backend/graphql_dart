# Change Log

## 8.0.0

### Breaking changes in 8.0.0

* **Breaking:** `InlineFragmentContext.typeCondition` and `onToken` are nullable, as an inline fragment's type condition is optional.
* **Breaking:** `InlineFragmentContext` and `FragmentSpreadContext` use the `Directives` mixin, so code can read their directives the same way as a field's.
* **Breaking:** Leftover tokens after the last definition are reported as a syntax error.
* **Breaking:** Integers with leading zeros, such as `007`, and numbers followed directly by a digit, `.` or letter are rejected.
* **Breaking:** Block strings keep backslashes and are not trimmed. Their value is computed as in the GraphQL spec: common indentation and leading and trailing blank lines are removed.

### New in 8.0.0

* `DirectiveContext.arguments` lists all of a directive's arguments; `argument` is the first of them.

### Fixes in 8.0.0

* **Directives:** A directive with several arguments, such as `@dir(x: 1, y: 2)`, is parsed.
* **Fragments:** An inline fragment without a type condition, such as `... @include(if: $x) { a }`, is parsed.
* **Numbers:** Exponents with an uppercase `E` or a sign, such as `1E10` and `1E+5`, are parsed.
* **Strings:** A block string may contain `"` characters.
* **Errors:** An operation without a selection set reports "Missing selection set in operation definition." instead of naming a fragment definition.
* **Parser:** `parseFragmentSpread` restores `current` when it backtracks.
* **Parser:** `eatCommas` is deprecated: the lexer skips commas, so it never did anything.

## 7.0.0

* Require Dart >= 3.13

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

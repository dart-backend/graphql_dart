# Change Log

## 8.0.0

### Breaking changes in 8.0.0

* **Breaking:** `validate` returns a failed `ValidationResult` for wrongly typed input instead of throwing a `TypeError`. This applies to lists, objects, input objects, unions, non-null types and the min/max/range string and number types.
* **Breaking:** Number types reject `null`, like the other scalar types. Objects, input objects and lists still accept `null` for nullable fields and items.
* **Breaking:** An enum's `validate` accepts only value names. Dart values are converted with `convert`, which `GraphQLObjectType.validate` applies to resolver output.
* **Breaking:** `GraphQLType.convert` returns `null` for a value it cannot convert, instead of throwing.
* **Breaking:** `GraphQLUnionType.coerceToInputObject` throws an `UnsupportedError`, as a union cannot be an input type.
* **Breaking:** `toInputObject` and `coerceToInputObject` on an object type leave out a nullable field whose type cannot be an input, such as a union, an interface or an object with no input fields. They throw an `UnsupportedError` for such a field that is non-null, for an interface, and for an object left with no input fields.
* **Breaking:** `coerceToInputObject` on an object type builds its `${name}Input` type once and returns the same instance after that, so fields added to the object type later are not included. `toInputObject` with that name returns it too.
* **Breaking:** A `GraphQLFieldResolver`'s first parameter is the parent value the field is resolved on, typed `dynamic`, instead of the field's own `Serialized` type, which it never received. A resolver can read a model object with `(todo, _) => todo.text` or `(todo, _) => (todo as Todo).text`. One that declares a type for that parameter, such as `(Todo todo, _) => ...`, no longer compiles.
* **Breaking:** Type hash codes no longer include fields, so equal types have equal hash codes and self-referencing types can be hashed.

### New in 8.0.0

* `field()` accepts arguments of any type, not only the field's own type.

### Fixes in 8.0.0

* **Validation:** A `null` value for a nullable field is accepted, and a `null` value for a non-null field is reported once.
* **Validation:** A `null` list item is accepted when the list's Dart type can hold it, as in `listOf<dynamic, dynamic>(...)`, and otherwise rejected with an error.
* **Validation:** The values returned by nested validators are kept, so nested input objects have `String` keys.
* **Serialization:** `null` field values serialize and deserialize as `null`.
* **Numbers:** `Float` accepts and converts `Int` input.
* **Unions:** Resolving a union or interface member handles enum, list-of-enum and `Date` fields holding Dart values.
* **Equality:** `GraphQLFieldInput` equality compares `defaultValue`.
* **Enums:** A Dart `Enum` value named after one of an enum type's values is serialized and converted to that name, so a model serialized to a map, which keeps its enum values, can be output.
* **Input objects:** `toInputObject` and `coerceToInputObject` handle object types that refer to themselves or to each other, instead of overflowing the stack. A failed conversion leaves no partly built input types behind.
* **Lists:** Resolver output for a list of enum or `Date` values is converted item by item, so a `null` item is reported on its own instead of failing every other item too.
* **Lists:** `serialize` and `deserialize` keep a `null` item the list can hold, and throw an `ArgumentError` for one it cannot, such as a `null` item for a non-null item type, instead of passing it to the item type.
* **Equality:** Comparing object or input object types that refer to themselves no longer overflows the stack.

## 7.0.0

* Require Dart >= 3.13

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

## 3.0.0

* Implemented directives
* Added polymorphic type names (basically type alias for polymorphism)
* Updated to SDK 2.15.x
  
## 2.1.1

* Fixed bug in enums

## 2.1.0

* Upgraded from `pendantic` to `lints` linter

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD
* Rename `graphql_schema` to `graphql_schema2`

## 1.0.4

* Add `convert` method to types, to avoid some annoying generics bugs.

## 1.0.3

* `enumTypeFromStrings` now returns `GraphQLEnumType<String>`.

## 1.0.2

* Added `GraphQLClass()`.
* Added `typeName`.

## 1.0.1

* Dart 2 updates.

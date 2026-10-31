part of 'schema.dart';

/// Strictly dictates the structure of some input data in a GraphQL query.
///
/// GraphQL's rigid type system is primarily implemented in Dart using classes that extend from [GraphQLType].
///
/// A [GraphQLType] represents values of type [Value] as values of type [Serialized]; for example, a
/// [GraphQLType] that serializes objects into `String`s.
abstract class GraphQLType<Value, Serialized> {
  /// The name of this type.
  String? get name;

  /// A description of this type, which, while optional, can be very useful in tools like GraphiQL.
  String? get description;

  /// Serializes an arbitrary input value.
  Serialized serialize(Value value);

  /// Deserializes a serialized value.
  Value deserialize(Serialized serialized);

  /// Attempts to convert a dynamic [value], such as a resolver's output, into a
  /// [Serialized] instance. Returns `null` if it cannot.
  Serialized? convert(dynamic value) => value is Serialized ? value : null;

  /// Performs type coercion against an [input] value, and returns a list of errors if the validation was unsuccessful.
  ValidationResult<Serialized> validate(String key, covariant dynamic input);

  /// Creates a non-nullable type that represents this type, and enforces that a field of this type is present in input data.
  GraphQLType<Value, Serialized> nonNullable();

  /// Turns this type into one suitable for being provided as an input to a [GraphQLObjectField].
  GraphQLType<Value, Serialized> coerceToInputObject();

  @override
  String toString() => name!;

  GraphQLListType<Value, Serialized> list() =>
      GraphQLListType<Value, Serialized>(this);
}

/// Shorthand to create a [GraphQLListType].
GraphQLListType<Value, Serialized> listOf<Value, Serialized>(
  GraphQLType<Value, Serialized> innerType,
) => GraphQLListType<Value, Serialized>(innerType);

/// A special [GraphQLType] that indicates that input vales should be a list of another type, [ofType].
class GraphQLListType<Value, Serialized>
    extends GraphQLType<List<Value>, List<Serialized>>
    with _NonNullableMixin<List<Value>, List<Serialized>> {
  final GraphQLType<Value, Serialized> ofType;

  GraphQLListType(this.ofType);

  /// Whether a null item is allowed, and a list of [T] can hold it.
  ///
  /// `listOf(graphQLString)` (a list of non-nullable Dart `String`s) cannot,
  /// unlike `listOf<dynamic, dynamic>(graphQLString)`.
  bool _holdsNull<T>() => ofType is! GraphQLNonNullableType && null is T;

  @override
  List<Serialized>? convert(value) {
    if (value is! Iterable) return super.convert(value);

    var out = <Serialized>[];
    for (var v in value) {
      if (v == null) {
        if (!_holdsNull<Serialized>()) return null;
        out.add(null as Serialized);
        continue;
      }
      var converted = ofType.convert(v);
      if (converted == null) return null;
      out.add(converted);
    }
    return out;
  }

  @override
  String? get name => null;

  @override
  String get description =>
      'A list of items of type ${ofType.name ?? '(${ofType.description}).'}';

  @override
  ValidationResult<List<Serialized>> validate(String key, input) {
    if (input is! Iterable) {
      return ValidationResult._failure(['Expected "$key" to be a list.']);
    }

    var out = <Serialized>[];
    var errors = <String>[];
    var i = 0;

    for (var v in input) {
      var k = '"$key" at index ${i++}';

      if (v == null) {
        if (_holdsNull<Serialized>()) {
          out.add(null as Serialized);
        } else {
          errors.add('Expected $k to be a non-null value.');
        }
        continue;
      }

      var result = ofType.validate(k, v);
      if (!result.successful) {
        errors.addAll(result.errors);
      } else {
        out.add(result.value as Serialized);
      }
    }

    if (errors.isNotEmpty) return ValidationResult._failure(errors);
    return ValidationResult._ok(out);
  }

  @override
  List<Value> deserialize(List serialized) {
    return serialized
        .map<Value>(
          (v) => v == null
              ? _nullItem<Value>()
              : ofType.deserialize(v as Serialized),
        )
        .toList();
  }

  @override
  List<Serialized> serialize(List<Value> value) {
    return value
        .map<Serialized>(
          (v) => v == null ? _nullItem<Serialized>() : ofType.serialize(v),
        )
        .toList();
  }

  T _nullItem<T>() {
    if (_holdsNull<T>()) return null as T;
    throw ArgumentError('A list of type $this cannot hold a null item.');
  }

  @override
  String toString() => '[$ofType]';

  @override
  bool operator ==(other) => other is GraphQLListType && other.ofType == ofType;

  @override
  int get hashCode => ofType.hashCode;

  @override
  GraphQLType<List<Value>, List<Serialized>> coerceToInputObject() =>
      GraphQLListType<Value, Serialized>(ofType.coerceToInputObject());
}

abstract mixin class _NonNullableMixin<Value, Serialized>
    implements GraphQLType<Value, Serialized> {
  GraphQLType<Value, Serialized>? _nonNullableCache;

  @override
  GraphQLType<Value, Serialized> nonNullable() =>
      _nonNullableCache ??= GraphQLNonNullableType<Value, Serialized>._(this);
}

/// A special [GraphQLType] that indicates that input values should both be non-null, and be valid when asserted against another type, named [ofType].
class GraphQLNonNullableType<Value, Serialized>
    extends GraphQLType<Value, Serialized> {
  final GraphQLType<Value, Serialized> ofType;

  GraphQLNonNullableType._(this.ofType);

  @override
  String? get name => null; //innerType.name;

  @override
  String get description =>
      'A non-nullable binding to ${ofType.name ?? '(${ofType.description}).'}';

  @override
  GraphQLType<Value, Serialized> nonNullable() {
    throw UnsupportedError('Cannot call nonNullable() on a non-nullable type.');
  }

  @override
  Serialized? convert(value) => ofType.convert(value);

  @override
  ValidationResult<Serialized> validate(String key, input) {
    if (input == null) {
      return ValidationResult._failure([
        'Expected "$key" to be a non-null value.',
      ]);
    }
    return ofType.validate(key, input);
  }

  @override
  Value deserialize(Serialized serialized) {
    return ofType.deserialize(serialized);
  }

  @override
  Serialized serialize(Value value) {
    return ofType.serialize(value);
  }

  @override
  String toString() {
    return '$ofType!';
  }

  @override
  bool operator ==(other) =>
      other is GraphQLNonNullableType && other.ofType == ofType;

  @override
  int get hashCode => ofType.hashCode;

  @override
  GraphQLType<Value, Serialized> coerceToInputObject() {
    return ofType.coerceToInputObject().nonNullable();
  }
}

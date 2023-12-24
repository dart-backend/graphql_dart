part of 'schema.dart';

/// `true` or `false`.
final GraphQLScalarType<bool, bool> graphQLBoolean = GraphQLBoolType();

/// A UTF‐8 character sequence.
final GraphQLScalarType<String, String> graphQLString = GraphQLStringType();

/// The ID scalar type represents a unique identifier, often used to re-fetch an object or as the key for a cache.
///
/// The ID type is serialized in the same way as a String; however, defining it as an ID signifies that it is not intended to be human‐readable.
final GraphQLScalarType<String, String> graphQLId =
    GraphQLStringType(name: 'ID');

final graphQLNonEmptyString =
    GraphQLStringMinType(1, description: 'Non empty String');

GraphQLStringType graphQLStringMin(int min) => GraphQLStringMinType(min);

GraphQLStringType graphQLStringMax(int max) => GraphQLStringMaxType(max);

GraphQLStringType graphQLStringRange(int min, int max) =>
    GraphQLStringRangeType(min, max);

/// A [DateTime], serialized as an ISO-8601 string..
final GraphQLScalarType<DateTime, String> graphQLDate = _GraphQLDateType._();

/// A signed 32‐bit integer.
final graphQLInt = GraphQLNumType<int>('Int');

final graphQLPositiveInt =
    GraphQLNumMinType<int>('Int', 1, description: 'Positive integer (>= 1)');

final graphQLNonPositiveInt = GraphQLNumMaxType<int>('Int', 0,
    description: 'Non positive integer (<= 0)');

final graphQLNegativeInt =
    GraphQLNumMaxType<int>('Int', -1, description: 'Negative integer (<= -1)');

final graphQLNonNegativeInt = GraphQLNumMinType<int>('Int', 0,
    description: 'Non negative integer (>= 0)');

GraphQLNumMinType<int> graphQLIntMin(int min) => GraphQLNumMinType('Int', min);

GraphQLNumMaxType<int> graphQLIntMax(int max) => GraphQLNumMaxType('Int', max);

GraphQLNumRangedType<int> graphQLIntRange(int min, int max) =>
    GraphQLNumRangedType('Int', min, max);

/// A signed double-precision floating-point value.
final graphQLFloat = GraphQLNumType<double>(
  'Float',
  //'A signed double-precision floating-point value.'
);

abstract class GraphQLScalarType<Value, Serialized>
    extends GraphQLType<Value, Serialized>
    with _NonNullableMixin<Value, Serialized> {
  Type get valueType => Value;
}

class GraphQLBoolType extends GraphQLScalarType<bool, bool> {
  @override
  bool serialize(bool value) {
    return value;
  }

  @override
  String get name => 'Boolean';

  @override
  String get description => 'A boolean value; can be either true or false.';

  @override
  ValidationResult<bool> validate(String key, input) {
    if (input is! bool) {
      return ValidationResult._failure(['Expected "$key" to be a boolean.']);
    }
    return ValidationResult._ok(input);
  }

  @override
  bool deserialize(bool serialized) {
    return serialized;
  }

  @override
  GraphQLType<bool, bool> coerceToInputObject() => this;
}

class GraphQLNumType<T extends num> extends GraphQLScalarType<T, T> {
  GraphQLNumType(this.name, {this.description = ''});

  @override
  final String name;
  @override
  String description;

  @override
  ValidationResult<T> validate(String key, input) {
    if (input is! T?) {
      return ValidationResult._failure(['Expected "$key" to be $name.']);
    }

    return ValidationResult._ok(input);
  }

  @override
  T deserialize(T serialized) {
    return serialized;
  }

  @override
  T serialize(T value) {
    return value;
  }

  @override
  GraphQLType<T, T> coerceToInputObject() => this;
}

class GraphQLNumMinType<T extends num> extends GraphQLNumType<T> {
  GraphQLNumMinType(super.name, this.min, {String? description})
      : super(description: description ?? '$name with minimum of $min');

  final T min;

  @override
  ValidationResult<T> validate(String key, T input) {
    var ret = super.validate(key, input);

    if (ret.successful && input < min) {
      ret = ValidationResult._failure(
          ['Value ($input) can not be lower than $min']);
    }

    return ret;
  }
}

class GraphQLNumMaxType<T extends num> extends GraphQLNumType<T> {
  GraphQLNumMaxType(super.name, this.max, {String? description})
      : super(description: description ?? '$name with maximum of $max');

  final T max;

  @override
  ValidationResult<T> validate(String key, T input) {
    var ret = super.validate(key, input);

    if (ret.successful && input > max) {
      ret = ValidationResult._failure(
          ['Value ($input) can not be greater than $max']);
    }

    return ret;
  }
}

class GraphQLNumRangedType<T extends num> extends GraphQLNumType<T> {
  GraphQLNumRangedType(super.name, this.min, this.max, {String? description})
      : super(
            description: description ??
                '$name between $min and $max. (>= $min && <= $max)');

  final T min;
  final T max;

  @override
  ValidationResult<T> validate(String key, T input) {
    var ret = super.validate(key, input);

    if (ret.successful && (input < min || input > max)) {
      ret = ValidationResult._failure([
        'Value ($input) must be between $min and $max. (>= $min && <= $max)'
      ]);
    }

    return ret;
  }
}

class GraphQLStringType extends GraphQLScalarType<String, String> {
  GraphQLStringType(
      {this.name = 'String', this.description = 'A character sequence.'});

  @override
  final String name;

  @override
  final String description;

  @override
  String serialize(String value) => value;

  @override
  String deserialize(String serialized) => serialized;

  @override
  ValidationResult<String> validate(String key, input) => input is String
      ? ValidationResult<String>._ok(input)
      : ValidationResult._failure(['Expected "$key" to be a string.']);

  @override
  GraphQLType<String, String> coerceToInputObject() => this;
}

class GraphQLStringMinType extends GraphQLStringType {
  GraphQLStringMinType(this.min, {String? description, super.name})
      : super(
            description:
                description ?? '$name with minimum of $min characters');

  final int min;

  @override
  ValidationResult<String> validate(String key, String input) {
    var ret = super.validate(key, input);

    if (ret.successful && input.length < min) {
      ret = ValidationResult._failure(
          ['Value (${input.length} chars) can not be lower than $min']);
    }

    return ret;
  }
}

class GraphQLStringMaxType extends GraphQLStringType {
  GraphQLStringMaxType(this.max, {String? description, super.name})
      : super(description: description ?? '$name with max of $max characters');

  final int max;

  @override
  ValidationResult<String> validate(String key, String input) {
    var ret = super.validate(key, input);

    if (ret.successful && input.length > max) {
      ret = ValidationResult._failure(
          ['Value (${input.length} chars) can not be greater than $max']);
    }

    return ret;
  }
}

class GraphQLStringRangeType extends GraphQLStringType {
  GraphQLStringRangeType(this.min, this.max, {String? description, super.name})
      : super(
            description:
                description ?? '$name with characters between $min and $max');

  final int min;
  final int max;

  @override
  ValidationResult<String> validate(String key, String input) {
    var ret = super.validate(key, input);

    if (ret.successful && (input.length < min || input.length > max)) {
      ret = ValidationResult._failure([
        'Value (${input.length} chars) must have between $min and $max chars'
      ]);
    }

    return ret;
  }
}

class _GraphQLDateType extends GraphQLScalarType<DateTime, String>
    with _NonNullableMixin<DateTime, String> {
  _GraphQLDateType._();

  @override
  String get name => 'Date';

  @override
  String get description => 'An ISO-8601 Date.';

  @override
  String serialize(DateTime value) => value.toIso8601String();

  @override
  DateTime deserialize(String serialized) => DateTime.parse(serialized);

  @override
  ValidationResult<String> validate(String key, input) {
    if (input is! String) {
      return ValidationResult<String>._failure(
          ['$key must be an ISO 8601-formatted date string.']);
    }
    // else if (input == null) return ValidationResult<String>._ok(input);

    try {
      DateTime.parse(input);
      return ValidationResult<String>._ok(input);
    } on FormatException {
      return ValidationResult<String>._failure(
          ['$key must be an ISO 8601-formatted date string.']);
    }
  }

  @override
  GraphQLType<DateTime, String> coerceToInputObject() => this;
}

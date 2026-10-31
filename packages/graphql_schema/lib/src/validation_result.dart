part of 'schema.dart';

/// Represents the result of asserting an input [value] against a [GraphQLType].

class ValidationResult<Value> {
  /// `true` if there were no errors during validation.
  final bool successful;

  /// The input value passed to whatever caller invoked validation.
  final Value? value;

  /// A list of errors that caused validation to fail.
  final List<String> errors;

  /// A successful validation, of the validated [value], for the `validate`
  /// of a custom [GraphQLType], such as a scalar.
  ValidationResult.ok(Value value) : this._ok(value);

  /// A failed validation, of its [errors].
  ValidationResult.failure(List<String> errors) : this._failure(errors);

  ValidationResult._ok(this.value) : errors = [], successful = true;

  ValidationResult._failure(this.errors) : value = null, successful = false;

  //  ValidationResult<T> _asFailure() {
  //    return new ValidationResult<T>._(false, value, errors);
  //  }
}

import 'input_value.dart';

/// Use [ConstantContext] instead. This class remains solely for backwards compatibility.
@Deprecated("Use [ConstantContext]")
abstract class ValueContext<T> extends InputValueContext<T> {
  /// Return a constant value.
  T get value;

  @override
  T computeValue(Map<String, dynamic> variables) => value;
}

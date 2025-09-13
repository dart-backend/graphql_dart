import 'package:code_builder/code_builder.dart';

/// Create a custom literal expression from a string [value].
///
/// **NOTE**: The string is always formatted `'<value>'`.
///
Expression literalString2(String? value) {
  return literalString(value ?? '');
}

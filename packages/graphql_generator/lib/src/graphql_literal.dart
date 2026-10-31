import 'package:code_builder/code_builder.dart';

/// Create a custom literal expression from a string [value].
///
/// **NOTE**: The string is always formatted `'<value>'`. Its `$`s are
/// escaped, as a name or a doc comment may hold one, which [literalString]
/// would leave to interpolate.
///
Expression literalString2(String? value) {
  return literalString((value ?? '').replaceAll(r'$', r'\$'));
}

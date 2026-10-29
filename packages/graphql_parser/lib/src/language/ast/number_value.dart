import 'package:source_span/source_span.dart';

import '../token.dart';
import 'input_value.dart';

/// A GraphQL number literal.
class NumberValueContext extends InputValueContext<num> {
  /// The source token.
  final Token numberToken;

  NumberValueContext(this.numberToken);

  /// The [num] value of the [numberToken].
  ///
  /// A fractional part or exponent makes the literal a Float, so it is a
  /// [double]; otherwise it is an [int].
  num get numberValue {
    var text = numberToken.text;
    return text.contains(RegExp('[.eE]'))
        ? double.parse(text)
        : int.parse(text);
  }

  // Use [numberToken] instead.
  //  @deprecated
  //  Token get NUMBER => numberToken;

  @override
  FileSpan? get span => numberToken.span;

  @override
  num computeValue(Map<String, dynamic> variables) => numberValue;
}

import 'package:source_span/source_span.dart';

import '../token.dart';
import 'input_value.dart';

/// A fractional part or an exponent, which makes a literal a Float.
final _floatPart = RegExp('[.eE]');

/// A GraphQL number literal.
class NumberValueContext extends InputValueContext<num> {
  /// The source token.
  final Token numberToken;

  NumberValueContext(this.numberToken);

  /// The [num] value of the [numberToken].
  ///
  /// A fractional part or exponent makes the literal a Float, so it is a
  /// [double]; otherwise it is an [int], or a [double] if it is too large
  /// for one, for an `Int` argument to reject and a `Float` to accept.
  num get numberValue {
    var text = numberToken.text;
    return text.contains(_floatPart)
        ? double.parse(text)
        : int.tryParse(text) ?? double.parse(text);
  }

  // Use [numberToken] instead.
  //  @deprecated
  //  Token get NUMBER => numberToken;

  @override
  FileSpan? get span => numberToken.span;

  @override
  num computeValue(Map<String, dynamic> variables) => numberValue;
}

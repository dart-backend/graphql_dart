import 'package:source_span/source_span.dart';
import 'input_value.dart';
import '../token.dart';

/// A GraphQL boolean value literal.
class BooleanValueContext extends InputValueContext<bool> {
  bool localValueCache = false;

  /// The source token.
  final Token booleanToken;

  BooleanValueContext(this.booleanToken) {
    assert(booleanToken.text == 'true' || booleanToken.text == 'false');
  }

  /// The [bool] value of this literal.
  bool get booleanValue => localValueCache = booleanToken.text == 'true';

  /// Use [booleanToken] instead.
  @Deprecated("Use [boolenToken]")
  Token get BOOLEAN => booleanToken;

  @override
  FileSpan? get span => booleanToken.span;

  @override
  bool computeValue(Map<String, dynamic> variables) => booleanValue;
}

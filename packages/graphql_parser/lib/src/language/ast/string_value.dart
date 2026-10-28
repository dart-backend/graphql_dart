import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../syntax_error.dart';
import '../token.dart';
import 'input_value.dart';

/// A GraphQL string value literal.
class StringValueContext extends InputValueContext<String> {
  /// The source token.
  final Token stringToken;

  /// Whether this is a block string.
  final bool isBlockString;

  StringValueContext(this.stringToken, {this.isBlockString = false});

  @override
  FileSpan? get span => stringToken.span;

  /// The [String] value of the [stringToken].
  String get stringValue {
    if (isBlockString) return _blockStringValue;

    var text = stringToken.text.substring(1, stringToken.text.length - 1);

    var codeUnits = text.codeUnits;
    var buf = StringBuffer();

    for (var i = 0; i < codeUnits.length; i++) {
      var ch = codeUnits[i];

      if (ch == $backslash) {
        if (i < codeUnits.length - 5 && codeUnits[i + 1] == $u) {
          var c1 = codeUnits[i += 2],
              c2 = codeUnits[++i],
              c3 = codeUnits[++i],
              c4 = codeUnits[++i];
          var hexString = String.fromCharCodes([c1, c2, c3, c4]);
          var hexNumber = int.parse(hexString, radix: 16);
          buf.write(String.fromCharCode(hexNumber));
          continue;
        }

        if (i < codeUnits.length - 1) {
          var next = codeUnits[++i];

          switch (next) {
            case $b:
              buf.write('\b');
              break;
            case $f:
              buf.write('\f');
              break;
            case $n:
              buf.writeCharCode($lf);
              break;
            case $r:
              buf.writeCharCode($cr);
              break;
            case $t:
              buf.writeCharCode($tab);
              break;
            default:
              buf.writeCharCode(next);
          }
        } else {
          throw SyntaxError('Unexpected "\\" in string literal.', span);
        }
      } else {
        buf.writeCharCode(ch);
      }
    }

    return buf.toString();
  }

  /// The value of a block string, per the spec's `BlockStringValue`: the raw
  /// text with `\"""` unescaped, the common indentation removed, and leading
  /// and trailing blank lines dropped. Other escapes are not processed.
  String get _blockStringValue {
    var raw = stringToken.text
        .substring(3, stringToken.text.length - 3)
        .replaceAll(r'\"""', '"""');
    var lines = raw.split(RegExp('\r\n|[\n\r]'));

    int? commonIndent;
    for (var line in lines.skip(1)) {
      var indent = line.length - line.trimLeft().length;
      if (indent < line.length &&
          (commonIndent == null || indent < commonIndent)) {
        commonIndent = indent;
      }
    }

    if (commonIndent != null && commonIndent > 0) {
      for (var i = 1; i < lines.length; i++) {
        var line = lines[i];
        lines[i] = line.length < commonIndent
            ? ''
            : line.substring(commonIndent);
      }
    }

    bool isBlank(String line) => line.trim().isEmpty;
    while (lines.isNotEmpty && isBlank(lines.first)) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && isBlank(lines.last)) {
      lines.removeLast();
    }

    return lines.join('\n');
  }

  @override
  String computeValue(Map<String, dynamic> variables) => stringValue;
}

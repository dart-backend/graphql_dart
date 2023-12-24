import 'package:source_span/source_span.dart';
import 'argument.dart';
import 'field_name.dart';
import 'node.dart';
import 'selection_set.dart';

/// A field in a GraphQL [SelectionSet].
class FieldContext extends Node with Directives {
  /// The name of this field.
  final FieldNameContext fieldName;

  /// Any arguments this field expects.
  final List<ArgumentContext> arguments = [];

  /// The list of selections to resolve on an object.
  final SelectionSetContext? selectionSet;

  FieldContext(this.fieldName, [this.selectionSet]);

  @override
  FileSpan? get span {
    if (selectionSet != null) {
      var otherSpan = selectionSet?.span;
      if (otherSpan == null) {
        return fieldName.span;
      }
      return fieldName.span?.expand(otherSpan);
    } else if (directives.isNotEmpty) {
      return directives.fold<FileSpan?>(
          fieldName.span, (out, d) => out?.expand(d.span));
    }
    if (arguments.isNotEmpty) {
      return arguments.fold<FileSpan?>(
          fieldName.span, (out, a) => out?.expand(a.span));
    } else {
      return fieldName.span;
    }
  }
}

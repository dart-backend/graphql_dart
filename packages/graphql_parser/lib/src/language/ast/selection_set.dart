import 'package:source_span/source_span.dart';

import '../token.dart';
import 'node.dart';
import 'selection.dart';

/// A set of GraphQL selections - fields, fragments, or inline fragments.
class SelectionSetContext extends Node {
  /// The source tokens.
  final Token? lBraceToken, rBraceToken;

  /// The selections to be applied.
  List<SelectionContext> selections = [];

  SelectionSetContext(this.lBraceToken, this.rBraceToken);

  /// A synthetic [SelectionSetContext] produced from a set of [selections].
  factory SelectionSetContext.merged(List<SelectionContext> selections) =
      _MergedSelectionSetContext;

  @override
  FileSpan? get span {
    var out = selections.fold<FileSpan?>(
        lBraceToken!.span, (out, s) => out!.expand(s.span!))!;
    return out.expand(rBraceToken!.span!);
  }
}

class _MergedSelectionSetContext extends SelectionSetContext {
  //@override
  //final List<SelectionContext> selections;

  _MergedSelectionSetContext(List<SelectionContext> selections)
      : super(null, null) {
    super.selections = selections;
  }

  @override
  FileSpan? get span =>
      selections.map((s) => s.span).reduce((a, b) => a!.expand(b!));
}

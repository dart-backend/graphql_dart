import '../token.dart';
import 'node.dart';

import 'package:source_span/source_span.dart';

import 'selection_set.dart';
import 'type_condition.dart';

/// An inline fragment, which typically appears in a [SelectionSetContext].
class InlineFragmentContext extends Node with Directives {
  /// The source tokens.
  final Token ellipsisToken;

  /// The `on` token; `null` if there is no [typeCondition].
  final Token? onToken;

  /// The type which this fragment matches; `null` if it applies to any type.
  final TypeConditionContext? typeCondition;

  /// The selections applied when the [typeCondition], if any, is met.
  final SelectionSetContext selectionSet;

  InlineFragmentContext(
    this.ellipsisToken,
    this.onToken,
    this.typeCondition,
    this.selectionSet,
  );

  @override
  FileSpan get span {
    var out = ellipsisToken.span!;
    if (onToken != null) out = out.expand(onToken!.span!);
    if (typeCondition != null) out = out.expand(typeCondition!.span!);
    out = directives.fold<FileSpan>(out, (o, d) => o.expand(d.span));

    return out.expand(selectionSet.span!);
  }
}

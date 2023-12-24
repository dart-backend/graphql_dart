import 'package:source_span/source_span.dart';

import '../../../graphql_parser2.dart';

abstract class Node {
  FileSpan? get span;
}

mixin Directives {
  /// Any directives affixed to this field.
  final List<DirectiveContext> directives = [];
}

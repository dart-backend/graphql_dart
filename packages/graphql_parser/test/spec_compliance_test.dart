import 'package:graphql_parser2/graphql_parser2.dart';
import 'package:test/test.dart';

import 'common.dart';

Object? argumentValue(String source) {
  var parser = parse(source);
  var doc = parser.parseDocument();
  expect(parser.errors, isEmpty);
  var op = doc.definitions.single as OperationDefinitionContext;
  return op.selectionSet.selections.single.field!.arguments.single.value
      .computeValue({});
}

List<String> errorsOf(String source) {
  var parser = parse(source);
  parser.parseDocument();
  return parser.errors.map((e) => e.message).toList();
}

void main() {
  group('document', () {
    test('rejects trailing tokens', () {
      expect(errorsOf('{ a } }}} garbage'), ['Unexpected "}".']);
    });

    test('operation without selection set names the operation', () {
      expect(errorsOf(r'query Q($a: Int)'), [
        'Missing selection set in operation definition.',
      ]);
    });
  });

  group('numbers', () {
    test('uppercase and signed exponents', () {
      expect(argumentValue('{ a(x: 1E2) }'), 100);
      expect(argumentValue('{ a(x: 1e+2) }'), 100);
      expect(argumentValue('{ a(x: 15E-1) }'), 1.5);
      expect(argumentValue('{ a(x: -0.5) }'), -0.5);
    });

    test('rejects leading zeros and incomplete numbers', () {
      for (var bad in ['007', '1E', '1.', '1.5.5', '1x']) {
        expect(
          () => parse('{ a(x: $bad) }').parseDocument(),
          throwsA(isA<SyntaxError>()),
          reason: bad,
        );
      }
    });
  });

  group('block strings', () {
    test('may contain quotes and escaped triple quotes', () {
      expect(argumentValue('{ a(x: """say "hi" """) }'), 'say "hi" ');
      expect(argumentValue(r'{ a(x: """a \""" b""") }'), 'a """ b');
    });

    test('keep backslashes and remove common indentation', () {
      expect(argumentValue(r'{ a(x: """C:\new""") }'), r'C:\new');
      expect(
        argumentValue(
          '{ a(x: """\n    Hello,\n      World!\n\n    Yours\n  """) }',
        ),
        'Hello,\n  World!\n\nYours',
      );
    });
  });

  test('directive with several arguments', () {
    var parser = parse('{ a @dir(x: 1, y: 2) }');
    var doc = parser.parseDocument();
    expect(parser.errors, isEmpty);
    var op = doc.definitions.single as OperationDefinitionContext;
    var directive = op.selectionSet.selections.single.field!.directives.single;
    expect(directive.arguments.map((a) => a.name), ['x', 'y']);
    expect(directive.argument!.name, 'x');
  });

  test('inline fragment without type condition', () {
    var parser = parse('{ ... @include(if: true) { a } ... { b } }');
    var doc = parser.parseDocument();
    expect(parser.errors, isEmpty);
    var op = doc.definitions.single as OperationDefinitionContext;
    var fragments = op.selectionSet.selections.map((s) => s.inlineFragment!);
    expect(fragments.map((f) => f.typeCondition), [null, null]);
    expect(fragments.first.directives.single.nameToken!.text, 'include');
  });

  test('fragment spread backtracking restores current token', () {
    var parser = parse('{ ... on A { a } }');
    parser.next(TokenType.LBRACE);
    var before = parser.current;
    expect(parser.parseFragmentSpread(), isNull);
    expect(parser.current, same(before));
  });
}

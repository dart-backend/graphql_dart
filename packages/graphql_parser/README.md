# Graphql Parser 2

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/graphql_parser2?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/graphql_dart)](https://github.com/dart-backend/graphql_dart/blob/master/packages/graphql_parser/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Parses GraphQL documents: queries, mutations, subscriptions and fragments, following the [GraphQL specification (June 2018)](https://spec.graphql.org/June2018/).

*This library is only a parser*: it turns text into an AST (abstract syntax tree). Executing queries is done by [`package:graphql_server2`](https://pub.dev/packages/graphql_server2), and [Angel3](https://pub.dev/packages/angel3_framework) users should consider [`package:angel3_graphql`](https://pub.dev/packages/angel3_graphql), the simplest way to add GraphQL to a server.

## Installation

Add `graphql_parser2` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  graphql_parser2: ^8.0.0
```

## Usage

`scan` turns text into tokens, and a `Parser` reads a `DocumentContext` from them by recursive descent. `scan` throws a `SyntaxError` on text it cannot read, such as an unterminated string; the parser collects its errors in `parser.errors`, so check them after parsing:

```dart
import 'package:graphql_parser2/graphql_parser2.dart';

void main() {
  const text = r'query Todos($done: Boolean = false) { todos(done: $done) { text } }';

  try {
    var parser = Parser(scan(text));
    var document = parser.parseDocument();

    if (parser.errors.isNotEmpty) {
      for (var error in parser.errors) {
        print('${error.message} at ${error.span?.start.toolString}');
      }
      return;
    }

    var query = document.definitions.single as OperationDefinitionContext;
    print(query.name); // Todos
    for (var selection in query.selectionSet.selections) {
      print(selection.field?.fieldName.name); // todos
    }
  } on SyntaxError catch (e) {
    print(e);
  }
}
```

Each AST node has a `span`, its location in the source, for error messages. A value node's `computeValue(variables)` gives its Dart value, with variables taken from the map given:

* A number with a fractional part or an exponent, such as `1.5` or `1e3`, is a `double`; any other number is an `int`, or a `double` if it is too large for one.
* A block string (`"""..."""`) has its common indentation and leading and trailing blank lines removed, as the specification describes.

The parser follows the specification, and rejects what it forbids, for example:

* integers with leading zeros, such as `007`;
* a line break in a `"..."` string;
* a variable in a default value, such as `$a: Int = $b`;
* a fragment named `on`.

See the [change log](https://pub.dev/packages/graphql_parser2/changelog) for what changed in 8.0.0.

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

void main() {
  var graphql = GraphQL(
    graphQLSchema(
      queryType: objectType(
        'Query',
        fields: [
          field('a', graphQLString, resolve: (_, _) => 'a'),
          field('b', graphQLString, resolve: (_, _) => 'b'),
        ],
      ),
    ),
  );

  test('inline fragment without a type condition', () async {
    expect(await graphql.parseAndExecute('{ a ... { b } }'), {
      'a': 'a',
      'b': 'b',
    });
  });

  test('@include and @skip on inline fragments', () async {
    expect(
      await graphql.parseAndExecute(
        r'query($on: Boolean) { a ... @include(if: $on) { b } }',
        variableValues: {'on': false},
      ),
      {'a': 'a'},
    );
    expect(await graphql.parseAndExecute('{ a ... @skip(if: false) { b } }'), {
      'a': 'a',
      'b': 'b',
    });
  });
}

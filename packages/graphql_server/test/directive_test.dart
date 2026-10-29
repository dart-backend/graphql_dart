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

  test('@jsonpath fills a variable from an earlier field', () async {
    var user = objectType('User', fields: [field('id', graphQLString)]);
    var graphQL = GraphQL(
      graphQLSchema(
        queryType: objectType(
          'Query',
          fields: [
            field('me', user, resolve: (_, _) => {'id': 'u1'}),
            field(
              'greet',
              graphQLString,
              inputs: [GraphQLFieldInput('id', graphQLString)],
              resolve: (_, args) => 'hi ${args['id']}',
            ),
          ],
        ),
      ),
    );
    expect(
      await graphQL.parseAndExecute(
        r'query($id: String @jsonpath(path: "$.me.id")) '
        r'{ me { id } greet(id: $id) }',
      ),
      {
        'me': {'id': 'u1'},
        'greet': 'hi u1',
      },
    );
  });
}

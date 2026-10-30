import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

import '../example/main.dart';

/// Resolving generated types from model objects:
/// https://github.com/dart-backend/graphql_dart/issues/3
void main() {
  var createdAt = DateTime.utc(2026, 1, 2);
  var todo = Todo(
    id: '1',
    text: 'Mock Todo',
    completed: true,
    completionStatus: CompletionStatus.COMPLETE,
    createdAt: createdAt,
  );

  GraphQL graphQLFor(Object? value) => GraphQL(
    graphQLSchema(
      queryType: objectType(
        'Query',
        fields: [
          field('todo', todoGraphQLType, resolve: (_, _) => value),
          field('todos', listOf(todoGraphQLType), resolve: (_, _) => [value]),
        ],
      ),
    ),
  );

  const query =
      '{ todo { id text completion_status created_at updated_at } '
      'todos { text } }';
  var expected = {
    'todo': {
      'id': '1',
      'text': 'Mock Todo',
      'completion_status': 'COMPLETE',
      'created_at': createdAt.toIso8601String(),
      'updated_at': null,
    },
    'todos': [
      {'text': 'Mock Todo'},
    ],
  };

  test('a generated type resolves fields from a model object', () async {
    expect(await graphQLFor(todo).parseAndExecute(query), expected);
  });

  test('a generated type still resolves fields from a Map', () async {
    // toJson() keeps the CompletionStatus enum value; it is output by name.
    expect(await graphQLFor(todo.toJson()).parseAndExecute(query), expected);
  });
}

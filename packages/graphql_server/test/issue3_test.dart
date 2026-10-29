import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

/// Resolving fields of model objects: https://github.com/dart-backend/graphql_dart/issues/3
class Todo {
  final String text;
  final bool isComplete;

  Todo(this.text, this.isComplete);

  Map<String, dynamic> toJson() => {'text': text, 'is_complete': isComplete};
}

GraphQL graphQLFor(GraphQLObjectType todoType, {dynamic defaultFieldResolver}) {
  return GraphQL(
    graphQLSchema(
      queryType: objectType(
        'Query',
        fields: [
          field('todo', todoType, resolve: (_, _) => Todo('Mock', true)),
        ],
      ),
    ),
    defaultFieldResolver: defaultFieldResolver,
  );
}

void main() {
  const query = '{ todo { text is_complete } }';

  test('a resolver receives the parent object', () async {
    var todoType = objectType(
      'Todo',
      fields: [
        field('text', graphQLString, resolve: (todo, _) => todo.text as String),
        field(
          'is_complete',
          graphQLBoolean,
          resolve: (todo, _) => (todo as Todo).isComplete,
        ),
      ],
    );
    expect(await graphQLFor(todoType).parseAndExecute(query), {
      'todo': {'text': 'Mock', 'is_complete': true},
    });
  });

  test('defaultFieldResolver resolves fields without a resolver', () async {
    var todoType = objectType(
      'Todo',
      fields: [
        field('text', graphQLString),
        field('is_complete', graphQLBoolean),
      ],
    );
    var graphQL = graphQLFor(
      todoType,
      defaultFieldResolver: <T>(T todo, String? name, Map<String, dynamic> _) =>
          (todo as dynamic).toJson()[name] as T,
    );
    expect(await graphQL.parseAndExecute(query), {
      'todo': {'text': 'Mock', 'is_complete': true},
    });
  });

  test('a field that cannot be resolved is an error, not null', () {
    var todoType = objectType(
      'Todo',
      fields: [
        field('text', graphQLString),
        field('is_complete', graphQLBoolean),
      ],
    );
    expect(
      graphQLFor(todoType).parseAndExecute(query),
      throwsA(
        isA<GraphQLException>().having(
          (e) => e.errors.single.message,
          'message',
          startsWith('Cannot resolve field "text" of type "Todo" from a Todo'),
        ),
      ),
    );
  });
}

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

void main() {
  test('single element', () async {
    var todoType = objectType(
      'todo',
      fields: [
        field('text', graphQLString, resolve: (obj, args) => obj.text),
        field(
          'completed',
          graphQLBoolean,
          resolve: (obj, args) => obj.completed,
        ),
      ],
    );

    var schema = graphQLSchema(
      queryType: objectType(
        'api',
        fields: [
          field(
            'todos',
            listOf(todoType),
            resolve: (_, __) => [
              Todo(text: 'Clean your room!', completed: false),
            ],
          ),
        ],
      ),
    );

    var graphql = GraphQL(schema);
    var result = await graphql.parseAndExecute('{ todos { text } }');

    print(result);
    expect(result, {
      'todos': [
        {'text': 'Clean your room!'},
      ],
    });
  });
}

class Todo {
  final String? text;
  final bool? completed;

  Todo({this.text, this.completed});
}

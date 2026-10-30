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
            resolve: (_, _) => [
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

  // A MapService stores dates as ISO 8601 strings:
  // https://github.com/dart-backend/angel/issues/95
  group('Date field', () {
    var event = objectType('Event', fields: [field('at', graphQLDate)]);
    GraphQL graphQLFor(Object? at) => GraphQL(
      graphQLSchema(
        queryType: objectType(
          'Query',
          fields: [
            field('event', event, resolve: (_, _) => {'at': at}),
          ],
        ),
      ),
    );
    var date = DateTime.utc(2026, 1, 2);

    test('accepts a DateTime', () async {
      expect(await graphQLFor(date).parseAndExecute('{ event { at } }'), {
        'event': {'at': date.toIso8601String()},
      });
    });

    test('accepts an ISO 8601 string', () async {
      expect(
        await graphQLFor(date.toIso8601String())
            .parseAndExecute('{ event { at } }'),
        {
          'event': {'at': date.toIso8601String()},
        },
      );
    });

    test('rejects another string', () {
      expect(
        graphQLFor('not a date').parseAndExecute('{ event { at } }'),
        throwsA(isA<GraphQLException>()),
      );
    });
  });
}

class Todo {
  final String? text;
  final bool? completed;

  Todo({this.text, this.completed});
}

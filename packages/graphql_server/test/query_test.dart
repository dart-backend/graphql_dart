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

    test('writes an ISO 8601 string as a DateTime is written', () async {
      expect(
        await graphQLFor('2026-01-02').parseAndExecute('{ event { at } }'),
        {
          'event': {'at': DateTime.parse('2026-01-02').toIso8601String()},
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

  test('an enum name of a shared value keeps its name', () async {
    var color = GraphQLEnumType<int>('Color', [
      GraphQLEnumValue('RED', 1),
      GraphQLEnumValue('CRIMSON', 1),
    ]);
    var graphQL = GraphQL(
      graphQLSchema(
        queryType: objectType(
          'Query',
          fields: [field('color', color, resolve: (_, _) => 'CRIMSON')],
        ),
      ),
    );
    expect(await graphQL.parseAndExecute('{ color }'), {'color': 'CRIMSON'});
  });

  group('choosing the operation', () {
    var graphQL = GraphQL(
      graphQLSchema(
        queryType: objectType(
          'Query',
          fields: [field('hello', graphQLString, resolve: (_, _) => 'world')],
        ),
        mutationType: objectType(
          'Mutation',
          fields: [field('add', graphQLString, resolve: (_, _) => 'added')],
        ),
      ),
    );
    const document = 'query todos { hello } mutation add { add }';

    test('runs the one named', () async {
      expect(await graphQL.parseAndExecute(document, operationName: 'add'), {
        'add': 'added',
      });
    });

    test('needs a name of several operations', () {
      expect(
        graphQL.parseAndExecute(document),
        throwsA(
          isA<GraphQLException>().having(
            (e) => e.errors.single.message,
            'message',
            'Must provide operation name if query contains multiple '
                'operations.',
          ),
        ),
      );
    });

    test('rejects a name it does not define', () {
      expect(
        graphQL.parseAndExecute(document, operationName: 'nope'),
        throwsA(isA<GraphQLException>()),
      );
    });
  });

  test(
    'a variable can be of a custom scalar, which introspection lists',
    () async {
      var graphQL = GraphQL(
        graphQLSchema(
          queryType: objectType(
            'Query',
            fields: [
              field(
                'echo',
                graphQLString,
                inputs: [GraphQLFieldInput('v', _Shout())],
                resolve: (_, args) => args['v'] as String,
              ),
            ],
          ),
        ),
      );
      expect(
        await graphQL.parseAndExecute(
          r'query($v: Shout) { echo(v: $v) }',
          variableValues: {'v': 'hi'},
        ),
        {'echo': 'HI'},
      );
      var types = await graphQL.parseAndExecute(
        '{ __schema { types { name } } }',
      );
      expect(
        ((types as Map)['__schema']['types'] as List).map((t) => t['name']),
        contains('Shout'),
      );
    },
  );
}

/// A custom scalar, of upper-cased strings.
class _Shout extends GraphQLScalarType<String, String> {
  @override
  String get name => 'Shout';

  @override
  String get description => 'An upper-cased string.';

  @override
  String serialize(String value) => value;

  @override
  String deserialize(String serialized) => serialized.toUpperCase();

  @override
  ValidationResult<String> validate(String key, input) =>
      graphQLString.validate(key, input);

  @override
  GraphQLType<String, String> coerceToInputObject() => this;
}

class Todo {
  final String? text;
  final bool? completed;

  Todo({this.text, this.completed});
}

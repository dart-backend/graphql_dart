import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

void main() {
  var color = enumType('Color', {'RED': 1, 'BLUE': 2});
  var paintInput = GraphQLInputObjectType(
    'PaintInput',
    inputFields: [
      GraphQLInputObjectField('name', graphQLString),
      GraphQLInputObjectField('note', graphQLString),
    ],
  );

  var graphql = GraphQL(
    graphQLSchema(
      queryType: objectType(
        'Query',
        fields: [
          field(
            'paint',
            graphQLString,
            inputs: [GraphQLFieldInput('c', color)],
            resolve: (_, args) => '${args['c']}',
          ),
          field(
            'limit',
            graphQLString,
            inputs: [GraphQLFieldInput('n', graphQLInt, defaultValue: 10)],
            resolve: (_, args) => '${args['n']}',
          ),
          field(
            'required',
            graphQLString,
            inputs: [GraphQLFieldInput('s', graphQLString.nonNullable())],
            resolve: (_, args) => args['s'] as String,
          ),
          field(
            'echo',
            graphQLString,
            inputs: [GraphQLFieldInput('i', paintInput)],
            resolve: (_, args) => '${args['i']}',
          ),
        ],
      ),
    ),
  );

  test('enum variable is coerced once', () async {
    expect(
      await graphql.parseAndExecute(
        r'query($c: Color) { paint(c: $c) }',
        variableValues: {'c': 'BLUE'},
      ),
      {'paint': '2'},
    );
  });

  test('enum literal argument', () async {
    expect(await graphql.parseAndExecute('{ paint(c: RED) }'), {'paint': '1'});
  });

  test('enum variable rejects a Dart value', () {
    expect(
      graphql.parseAndExecute(
        r'query($c: Color) { paint(c: $c) }',
        variableValues: {'c': 1},
      ),
      throwsA(isA<GraphQLException>()),
    );
  });

  test('omitted variable uses the argument default', () async {
    expect(await graphql.parseAndExecute(r'query($n: Int) { limit(n: $n) }'), {
      'limit': '10',
    });
  });

  test('null variable for a non-null argument is an error', () {
    expect(
      graphql.parseAndExecute(
        r'query($s: String) { required(s: $s) }',
        variableValues: {'s': null},
      ),
      throwsA(isA<GraphQLException>()),
    );
  });

  test('input object variable with a null field', () async {
    expect(
      await graphql.parseAndExecute(
        r'query($i: PaintInput) { echo(i: $i) }',
        variableValues: {
          'i': {'name': 'x', 'note': null},
        },
      ),
      {'echo': '{name: x, note: null}'},
    );
  });

  group('union field', () {
    var cat = objectType(
      'Cat',
      fields: [field('color', color), field('meow', graphQLString)],
    );
    var dog = objectType('Dog', fields: [field('bark', graphQLString)]);
    var pets = GraphQL(
      graphQLSchema(
        queryType: objectType(
          'Query',
          fields: [
            field(
              'pet',
              GraphQLUnionType('Pet', [cat, dog]),
              inputs: [GraphQLFieldInput('dog', graphQLBoolean)],
              resolve: (_, args) => args['dog'] == true
                  ? {'bark': 'woof'}
                  : {'color': 1, 'meow': 'hi'},
            ),
          ],
        ),
      ),
    );

    test('resolves the member type', () async {
      expect(
        await pets.parseAndExecute(
          '{ pet { ... on Cat { color meow } ... on Dog { bark } } }',
        ),
        {
          'pet': {'color': 'RED', 'meow': 'hi'},
        },
      );
      expect(
        await pets.parseAndExecute(
          '{ pet(dog: true) { ... on Cat { meow } ... on Dog { bark } } }',
        ),
        {
          'pet': {'bark': 'woof'},
        },
      );
    });
  });
}

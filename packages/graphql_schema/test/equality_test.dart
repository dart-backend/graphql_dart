import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:test/test.dart';

/// Note: this doesn't test for scalar types, which are final, and therefore use built-in equality.
void main() {
  group('equality', () {
    test('enums', () {
      expect(
        enumTypeFromStrings('A', ['B', 'C']),
        enumTypeFromStrings('A', ['B', 'C']),
      );
      expect(
        enumTypeFromStrings('A', ['B', 'C']),
        isNot(enumTypeFromStrings('B', ['B', 'C'])),
      );
    });

    test('objects', () {
      expect(
        objectType('B', fields: [field('b', graphQLString.nonNullable())]),
        objectType('B', fields: [field('b', graphQLString.nonNullable())]),
      );

      expect(
        objectType('B', fields: [field('b', graphQLString.nonNullable())]),
        isNot(
          objectType('BD', fields: [field('b', graphQLString.nonNullable())]),
        ),
      );

      expect(
        objectType('B', fields: [field('b', graphQLString.nonNullable())]),
        isNot(
          objectType('B', fields: [field('ba', graphQLString.nonNullable())]),
        ),
      );

      expect(
        objectType('B', fields: [field('b', graphQLString.nonNullable())]),
        isNot(
          objectType('B', fields: [field('a', graphQLFloat.nonNullable())]),
        ),
      );
    });

    test('input type', () {});

    test('union type', () {
      expect(
        GraphQLUnionType('A', [
          objectType('B', fields: [field('b', graphQLString.nonNullable())]),
          objectType('C', fields: [field('c', graphQLString.nonNullable())]),
        ]),
        GraphQLUnionType('A', [
          objectType('B', fields: [field('b', graphQLString.nonNullable())]),
          objectType('C', fields: [field('c', graphQLString.nonNullable())]),
        ]),
      );

      expect(
        GraphQLUnionType('A', [
          objectType('B', fields: [field('b', graphQLString.nonNullable())]),
          objectType('C', fields: [field('c', graphQLString.nonNullable())]),
        ]),
        isNot(
          GraphQLUnionType('AA', [
            objectType('B', fields: [field('b', graphQLString.nonNullable())]),
            objectType('C', fields: [field('c', graphQLString.nonNullable())]),
          ]),
        ),
      );

      expect(
        GraphQLUnionType('A', [
          objectType('BB', fields: [field('b', graphQLString.nonNullable())]),
          objectType('C', fields: [field('c', graphQLString.nonNullable())]),
        ]),
        isNot(
          GraphQLUnionType('AA', [
            objectType(
              'BDD',
              fields: [field('b', graphQLString.nonNullable())],
            ),
            objectType('C', fields: [field('c', graphQLString.nonNullable())]),
          ]),
        ),
      );
    });

    test('field inputs compare default values', () {
      expect(
        GraphQLFieldInput('limit', graphQLInt, defaultValue: 10),
        isNot(GraphQLFieldInput('limit', graphQLInt, defaultValue: 50)),
      );
    });

    test('equal types have equal hash codes', () {
      GraphQLObjectType user() =>
          objectType('User', fields: [field('name', graphQLString)]);
      GraphQLInputObjectType userInput() => GraphQLInputObjectType(
        'UserInput',
        inputFields: [GraphQLInputObjectField('name', graphQLString)],
      );

      expect(user().hashCode, user().hashCode);
      expect(userInput().hashCode, userInput().hashCode);
      expect(
        enumTypeFromStrings('A', ['B']).hashCode,
        enumTypeFromStrings('A', ['B']).hashCode,
      );
      expect(
        GraphQLUnionType('U', [user()]).hashCode,
        GraphQLUnionType('U', [user()]).hashCode,
      );
      expect({user(), user()}, hasLength(1));
    });

    test('self-referencing type can be hashed', () {
      var node = objectType('Node');
      node.fields.add(field('parent', node));
      expect(() => node.hashCode, returnsNormally);
    });
  });

  group('types that refer to themselves', () {
    GraphQLObjectType todo({String text = 'text'}) {
      var type = objectType('Todo', fields: [field(text, graphQLString)]);
      return type..fields.add(field('parent', type));
    }

    test('equal ones built apart are equal', () {
      expect(todo(), todo());
      expect(todo().coerceToInputObject(), todo().coerceToInputObject());
      expect({todo(), todo()}, hasLength(1));
    });

    test('ones built apart that differ are not equal', () {
      expect(todo(), isNot(todo(text: 'title')));
      expect(
        todo().coerceToInputObject(),
        isNot(todo(text: 'title').coerceToInputObject()),
      );
    });

    test('interfaces are compared', () {
      var node = objectType('Node', isInterface: true);
      expect(objectType('Todo', interfaces: [node]), isNot(objectType('Todo')));
      expect(
        objectType('Todo', interfaces: [node]),
        objectType('Todo', interfaces: [node]),
      );
    });

    test('types that many fields refer to are compared once', () {
      List<GraphQLObjectType> build() {
        var types = [for (var i = 0; i < 12; i++) objectType('T$i')];
        for (var t in types) {
          for (var (i, u) in types.indexed) {
            t.fields.add(field('f$i', u));
          }
        }
        return types;
      }

      var sw = Stopwatch()..start();
      expect(build().first, build().first);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('types that refer to each other are compared', () {
      (GraphQLObjectType, GraphQLObjectType) pair() {
        var a = objectType('A', fields: [field('n', graphQLInt)]);
        var b = objectType('B', fields: [field('a', a)]);
        a.fields.add(field('b', b));
        return (a, b);
      }

      expect(pair().$1, pair().$1);
      expect(pair().$1.coerceToInputObject(), pair().$1.coerceToInputObject());
    });
  });
}

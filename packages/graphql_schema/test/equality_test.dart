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
}

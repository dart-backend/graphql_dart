import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:test/test.dart';

/// Note: this doesn't test for scalar types, which are final, and therefore use built-in equality.
void main() {
  group('equality', () {
    test('enums', () {
      expect(enumTypeFromStrings('A', ['B', 'C']),
          enumTypeFromStrings('A', ['B', 'C']));
      expect(enumTypeFromStrings('A', ['B', 'C']),
          isNot(enumTypeFromStrings('B', ['B', 'C'])));
    });

    test('objects', () {
      expect(
        objectType('B', fields: [
          field('b', graphQLString.nonNullable()),
        ]),
        objectType('B', fields: [
          field('b', graphQLString.nonNullable()),
        ]),
      );

      expect(
        objectType('B', fields: [
          field('b', graphQLString.nonNullable()),
        ]),
        isNot(objectType('BD', fields: [
          field('b', graphQLString.nonNullable()),
        ])),
      );

      expect(
        objectType('B', fields: [
          field('b', graphQLString.nonNullable()),
        ]),
        isNot(objectType('B', fields: [
          field('ba', graphQLString.nonNullable()),
        ])),
      );

      expect(
        objectType('B', fields: [
          field('b', graphQLString.nonNullable()),
        ]),
        isNot(objectType('B', fields: [
          field('a', graphQLFloat.nonNullable()),
        ])),
      );
    });

    test('input type', () {});

    test('union type', () {
      expect(
        GraphQLUnionType('A', [
          objectType('B', fields: [
            field('b', graphQLString.nonNullable()),
          ]),
          objectType('C', fields: [
            field('c', graphQLString.nonNullable()),
          ]),
        ]),
        GraphQLUnionType('A', [
          objectType('B', fields: [
            field('b', graphQLString.nonNullable()),
          ]),
          objectType('C', fields: [
            field('c', graphQLString.nonNullable()),
          ]),
        ]),
      );

      expect(
        GraphQLUnionType('A', [
          objectType('B', fields: [
            field('b', graphQLString.nonNullable()),
          ]),
          objectType('C', fields: [
            field('c', graphQLString.nonNullable()),
          ]),
        ]),
        isNot(GraphQLUnionType('AA', [
          objectType('B', fields: [
            field('b', graphQLString.nonNullable()),
          ]),
          objectType('C', fields: [
            field('c', graphQLString.nonNullable()),
          ]),
        ])),
      );

      expect(
        GraphQLUnionType('A', [
          objectType('BB', fields: [
            field('b', graphQLString.nonNullable()),
          ]),
          objectType('C', fields: [
            field('c', graphQLString.nonNullable()),
          ]),
        ]),
        isNot(GraphQLUnionType('AA', [
          objectType('BDD', fields: [
            field('b', graphQLString.nonNullable()),
          ]),
          objectType('C', fields: [
            field('c', graphQLString.nonNullable()),
          ]),
        ])),
      );
    });
  });
}

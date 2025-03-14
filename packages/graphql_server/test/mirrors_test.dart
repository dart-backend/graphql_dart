import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/mirrors.dart';
import 'package:test/test.dart';

void main() {
  group('convertDartType', () {
    group('on enum', () {
      // ignore: deprecated_member_use_from_same_package
      var type = convertDartType(RomanceLanguage);
      var asEnumType = type as GraphQLEnumType;

      test('produces enum type', () {
        expect(type, isNotNull);
      });

      test('rejects invalid value', () {
        expect(asEnumType.validate('@root', 'GERMAN').successful, false);
      });

      test('accepts valid value', () {
        expect(asEnumType.validate('@root', 'spanish').successful, true);
      });

      test('deserializes to concrete value', () {
        expect(asEnumType.deserialize('italian'), RomanceLanguage.italian);
      });

      test('serializes to concrete value', () {
        expect(asEnumType.serialize(RomanceLanguage.france), 'france');
      });

      /* TODO: Required fixing
      test('can serialize null', () {
        expect(asEnumType.serialize(null), null);
      });
      */

      test('fails to serialize invalid value', () {
        expect(() => asEnumType.serialize(34), throwsStateError);
      });

      test('fails to deserialize invalid value', () {
        expect(() => asEnumType.deserialize('JAPANESE'), throwsStateError);
      });
    });
  });
}

@graphQLClass
enum RomanceLanguage {
  spanish,
  france,
  italian,
}

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:graphql_generator2/graphql_generator2.dart';
import 'package:test/test.dart';

const _imports = '''
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
''';

/// The library of [source], with the directives [imports] before its `part`.
String _library(String source, String imports) =>
    "$_imports$imports\npart 'model.g.dart';\n$source";

/// The code [graphQLBuilder] generates of [source], a library of the package
/// `a` with the other libraries [others], by their paths, and the directives
/// [imports] before its `part`.
///
/// Fails the test if the builder logs an error, so that a builder that throws
/// does not pass as one that generated nothing.
Future<String> generate(
  String source, {
  Map<String, String> others = const {},
  String imports = '',
}) async {
  var readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();
  var errors = <String>[];
  await testBuilder(
    graphQLBuilder(BuilderOptions.empty),
    {
      'a|lib/model.dart': _library(source, imports),
      for (var MapEntry(:key, :value) in others.entries) 'a|lib/$key': value,
    },
    rootPackage: 'a',
    readerWriter: readerWriter,
    onLog: (log) {
      if (log.level.value >= 1000) errors.add('${log.message} ${log.error}');
    },
  );
  expect(errors, isEmpty, reason: 'The builder failed');
  // A hidden output, which the combining builder puts in `model.g.dart`.
  var output = AssetId(
    'a',
    '.dart_tool/build/generated/a/lib/model.graphql_generator2.g.part',
  );
  expect(
    readerWriter.testing.exists(output),
    isTrue,
    reason: 'Nothing was generated',
  );
  return readerWriter.testing.readString(output);
}

/// The errors of compiling the library of [source] with the code generated of
/// it as its part, so that a test fails on generated code that does not
/// compile.
Future<List<String>> compileErrors(
  String source, {
  Map<String, String> others = const {},
  String imports = '',
}) async {
  var generated = await generate(source, others: others, imports: imports);
  return resolveSources(
    {
      'a|lib/model.dart': _library(source, imports),
      'a|lib/model.g.dart': "part of 'model.dart';\n$generated",
      for (var MapEntry(:key, :value) in others.entries) 'a|lib/$key': value,
    },
    (resolver) async {
      var library = await resolver.libraryFor(AssetId('a', 'lib/model.dart'));
      var result = await library.session.getResolvedLibraryByElement(library);
      if (result is! ResolvedLibraryResult) return ['Not resolved: $result'];
      return [
        for (var unit in result.units)
          for (var diagnostic in unit.diagnostics)
            if (diagnostic.severity == Severity.error)
              '${unit.uri}: ${diagnostic.message}',
      ];
    },
    readAllSourcesFromFilesystem: true,
    rootPackage: 'a',
  );
}

void main() {
  const timeout = Timeout(Duration(minutes: 3));

  test('generates a resolver for each field, which compiles', () async {
    const source = '''
@graphQLClass
class Item {
  String? name;
}
''';
    var code = await generate(source);
    expect(code, contains('obj is Item'));
    expect(code, contains('? obj.name'));
    expect(code, contains(': obj == null'));
    expect(code, contains('throw GraphQLException.fromMessage('));
    expect(
      code,
      contains(
        r'"name" of "Item" from a value of type ${obj.runtimeType}: '
        'expected a Map or an instance of Item.',
      ),
    );
    expect(await compileErrors(source), isEmpty);
  }, timeout: timeout);

  test(r'compiles names and doc comments with a $', () async {
    const source = r'''
@graphQLClass
class Item$ {
  /// Costs $5.
  String? a$b;
}
''';
    var code = await generate(source);
    expect(code, contains(r"'a\$b'"));
    expect(code, contains(r'instance of Item\$.'));
    expect(code, contains(r"'Costs \$5.'"));
    expect(await compileErrors(source), isEmpty);
  }, timeout: timeout);

  test('names the generated class of a model in its error', () async {
    var code = await generate('''
@serializable
@graphQLClass
abstract class _Account {
  String? get name;
}
''');
    expect(code, contains('obj is _Account'));
    expect(code, contains('instance of Account.'));
  }, timeout: timeout);

  test('leaves out static and private fields, and compiles', () async {
    const source = '''
@graphQLClass
class Item extends Base {
  static const tableName = 'items';
  String? _hidden;
  String? name;
}
''';
    var others = {'base.dart': 'class Base { String? _secret; }'};
    const imports = "import 'base.dart';";
    var code = await generate(source, others: others, imports: imports);
    expect(code, contains("'name'"));
    expect(code, isNot(contains('tableName')));
    expect(code, isNot(contains('_hidden')));
    expect(code, isNot(contains('_secret')));
    expect(
      await compileErrors(source, others: others, imports: imports),
      isEmpty,
    );
  }, timeout: timeout);

  group('leaves out fields the serializer excludes', () {
    test('as abstract getters of a model', () async {
      var code = await generate('''
@serializable
@graphQLClass
abstract class AccountEntity {
  String? get name;

  @SerializableField(exclude: true)
  String? get passwordHash;
}
''');
      expect(code, contains("'name'"));
      expect(code, isNot(contains('password')));
    }, timeout: timeout);

    test('as final fields', () async {
      const source = '''
@graphQLClass
class User {
  final String name;

  @SerializableField(exclude: true)
  final String passwordHash;

  @exclude
  final String? token;

  @SerializableField(exclude: true, canSerialize: true)
  final String? shown;

  User(this.name, this.passwordHash, this.token, this.shown);
}
''';
      var code = await generate(source);
      expect(code, contains("'name'"));
      expect(code, contains("'shown'"));
      expect(code, isNot(contains('password')));
      expect(code, isNot(contains('token')));
      expect(await compileErrors(source), isEmpty);
    }, timeout: timeout);
  });

  test('gives an enum value as it is, for the enum type to name', () async {
    const source = '''
enum Color { red, green }

final colorType = enumType<Color>('Color', {
  'RED': Color.red,
  'GREEN': Color.green,
});

@graphQLClass
class Item {
  @GraphQLDocumentation(typeName: #colorType)
  Color? color;
}
''';
    var code = await generate(source);
    expect(code, contains('? obj.color\n'));
    expect(code, isNot(contains('obj.color.name')));
    expect(code, isNot(contains('obj.color?.name')));
    expect(await compileErrors(source), isEmpty);
  }, timeout: timeout);
}

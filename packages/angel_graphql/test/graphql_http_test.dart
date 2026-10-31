import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

/// The requests of `graphQLHttp`: https://github.com/dart-backend/graphql_dart/issues/17
void main() {
  late AngelHttp http;
  late Uri uri;
  late HttpClient client;

  setUp(() async {
    var graphQL = GraphQL(
      graphQLSchema(
        queryType: objectType(
          'Query',
          fields: [
            field(
              'hello',
              graphQLString,
              inputs: [GraphQLFieldInput('name', graphQLString)],
              resolve: (_, args) => 'Hello, ${args['name'] ?? 'world'}!',
            ),
          ],
        ),
        mutationType: objectType(
          'Mutation',
          fields: [
            field('add', graphQLString, resolve: (_, _) => 'added'),
            field(
              'upload',
              graphQLString,
              inputs: [
                GraphQLFieldInput('file', graphQLUpload),
                GraphQLFieldInput('files', listOf(graphQLUpload)),
              ],
              resolve: (_, args) => [
                (args['file'] as UploadedFile?)?.filename,
                for (var f in (args['files'] as List?) ?? [])
                  (f as UploadedFile).filename,
              ].nonNulls.join(','),
            ),
          ],
        ),
      ),
    );
    var app = Angel();
    app.all('/graphql', graphQLHttp(graphQL));
    http = AngelHttp(app);
    var server = await http.startServer('127.0.0.1', 0);
    uri = Uri.parse('http://127.0.0.1:${server.port}/graphql');
    client = HttpClient();
  });

  tearDown(() async {
    client.close();
    await http.close();
  });

  Future<Object?> send(HttpClientRequest request, [String? body]) async {
    if (body != null) request.write(body);
    var response = await request.close();
    return json.decode(await response.transform(utf8.decoder).join());
  }

  Future<Object?> postJson(Map<String, dynamic> body) async {
    var request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    return send(request, json.encode(body));
  }

  const document = 'query todos { hello } mutation add { add }';

  group('JSON', () {
    test('runs the operation of operationName', () async {
      expect(await postJson({'query': document, 'operationName': 'add'}), {
        'data': {'add': 'added'},
      });
      expect(await postJson({'query': document, 'operationName': 'todos'}), {
        'data': {'hello': 'Hello, world!'},
      });
    });

    test('accepts operation_name, as before', () async {
      expect(await postJson({'query': document, 'operation_name': 'add'}), {
        'data': {'add': 'added'},
      });
    });

    test('takes variables', () async {
      expect(
        await postJson({
          'query': r'query($n: String) { hello(name: $n) }',
          'variables': {'n': 'Dart'},
        }),
        {
          'data': {'hello': 'Hello, Dart!'},
        },
      );
    });
  });

  test('GET reads its query parameters', () async {
    var request = await client.getUrl(
      uri.replace(
        queryParameters: {
          'query': r'query a { hello } query b($n: String) { hello(name: $n) }',
          'operationName': 'b',
          'variables': json.encode({'n': 'GET'}),
        },
      ),
    );
    expect(await send(request), {
      'data': {'hello': 'Hello, GET!'},
    });
  });

  test('application/graphql takes the query as the body', () async {
    var request = await client.postUrl(uri);
    request.headers.contentType = ContentType('application', 'graphql');
    expect(await send(request, '{ hello }'), {
      'data': {'hello': 'Hello, world!'},
    });
  });

  group('multipart', () {
    Future<Object?> postMultipart(
      Map<String, dynamic> operations,
      Map<String, List<String>> map,
      Map<String, String> files,
    ) async {
      const boundary = 'graphql-boundary';
      var body = StringBuffer();
      void part(String name, String content, {String? filename}) {
        body
          ..write('--$boundary\r\n')
          ..write('Content-Disposition: form-data; name="$name"')
          ..write(filename == null ? '' : '; filename="$filename"')
          ..write('\r\n')
          ..write(filename == null ? '' : 'Content-Type: text/plain\r\n')
          ..write('\r\n$content\r\n');
      }

      part('operations', json.encode(operations));
      part('map', json.encode(map));
      for (var MapEntry(:key, :value) in files.entries) {
        part(key, 'contents of $value', filename: value);
      }
      body.write('--$boundary--\r\n');

      var request = await client.postUrl(uri);
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      return send(request, body.toString());
    }

    test('puts a file in its variables', () async {
      expect(
        await postMultipart(
          {
            'query': r'mutation($file: Upload) { upload(file: $file) }',
            'variables': {'file': null},
          },
          {
            '0': ['variables.file'],
          },
          {'0': 'a.txt'},
        ),
        {
          'data': {'upload': 'a.txt'},
        },
      );
    });

    test('puts files in a list of its variables', () async {
      expect(
        await postMultipart(
          {
            'query':
                r'query q { hello } '
                r'mutation m($files: [Upload]) { upload(files: $files) }',
            'operationName': 'm',
            'variables': {
              'files': [null, null],
            },
          },
          {
            '0': ['variables.files.0'],
            '1': ['variables.files.1'],
          },
          {'0': 'a.txt', '1': 'b.txt'},
        ),
        {
          'data': {'upload': 'a.txt,b.txt'},
        },
      );
    });

    test('an Upload that is not a file is a validation error', () async {
      var result = await postJson({
        'query': r'mutation($file: Upload) { upload(file: $file) }',
        'variables': {'file': 'not a file'},
      });
      expect(
        ((result as Map)['errors'] as List).map((e) => e['message']),
        contains('Expected "file" to be an uploaded file.'),
      );
    });

    test('rejects a path that is not of its variables', () async {
      var result = await postMultipart(
        {'query': r'mutation($file: Upload) { upload(file: $file) }'},
        {
          '0': ['operations.query'],
        },
        {'0': 'a.txt'},
      );
      expect((result as Map)['errors'], isNotEmpty);
    });
  });
}

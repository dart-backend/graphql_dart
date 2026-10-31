import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

/// A WebSocket client of the test server, of JSON messages.
class _Client {
  final WebSocket socket;
  late final StreamIterator<Map> _iterator;

  _Client(this.socket) {
    _iterator = StreamIterator(
      socket.map((text) => json.decode(text as String) as Map),
    );
  }

  void send(Map<String, dynamic> message) => socket.add(json.encode(message));

  Future<Map> next() async {
    expect(
      await _iterator.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    return _iterator.current;
  }

  /// Waits for the server to close the connection, and gives its close code.
  Future<int?> closed() async {
    while (await _iterator.moveNext().timeout(const Duration(seconds: 3))) {}
    return socket.closeCode;
  }

  Future<void> close() async {
    await socket.close();
    await _iterator.cancel();
  }
}

void main() {
  late AngelHttp http;
  late Uri uri;
  late StreamController<int> ticks;

  setUp(() async {
    ticks = StreamController<int>.broadcast();
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
        subscriptionType: objectType(
          'Subscription',
          fields: [
            field(
              'tick',
              graphQLInt,
              resolve: (_, _) => ticks.stream.map((n) => {'tick': n}),
            ),
          ],
        ),
      ),
    );

    var app = Angel();
    app.get(
      '/ws',
      graphQLWS(
        graphQL,
        onConnect: (req, payload) => payload?['token'] != 'bad',
      ),
    );
    http = AngelHttp(app);
    var server = await http.startServer('127.0.0.1', 0);
    uri = Uri.parse('ws://127.0.0.1:${server.port}/ws');
  });

  tearDown(() async {
    await ticks.close();
    await http.close();
  });

  Future<_Client> connect(List<String> protocols) async =>
      _Client(await WebSocket.connect('$uri', protocols: protocols));

  /// Adds tick [n] once the subscription listens to the ticks.
  Future<void> tick(int n) async {
    for (var i = 0; i < 100 && !ticks.hasListener; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    ticks.add(n);
  }

  group('graphql-transport-ws', () {
    test('is chosen, also when the client offers both', () async {
      var client = await connect(['graphql-ws', 'graphql-transport-ws']);
      expect(client.socket.protocol, 'graphql-transport-ws');
      await client.close();
    });

    test('serves subscriptions and queries', () async {
      var client = await connect(['graphql-transport-ws']);
      client.send({'type': 'connection_init'});
      expect(await client.next(), {'type': 'connection_ack'});

      client.send({
        'id': 's',
        'type': 'subscribe',
        'payload': {'query': 'subscription { tick }'},
      });
      await tick(1);
      expect(await client.next(), {
        'type': 'next',
        'id': 's',
        'payload': {
          'data': {'tick': 1},
        },
      });

      // A query, without variables, while the subscription runs.
      client.send({
        'id': 'q',
        'type': 'subscribe',
        'payload': {'query': '{ hello }'},
      });
      expect((await client.next())['payload'], {
        'data': {'hello': 'Hello, world!'},
      });
      expect(await client.next(), {'type': 'complete', 'id': 'q'});

      client.send({'id': 's', 'type': 'complete'});
      await client.close();
    });

    test('closes with 4403 when onConnect rejects', () async {
      var client = await connect(['graphql-transport-ws']);
      client.send({
        'type': 'connection_init',
        'payload': {'token': 'bad'},
      });
      expect(await client.closed(), 4403);
    });
  });

  group('subscriptions-transport-ws', () {
    test('serves subscriptions, and stops them', () async {
      var client = await connect(['graphql-ws']);
      expect(client.socket.protocol, 'graphql-ws');
      client.send({'type': 'connection_init'});
      expect((await client.next())['type'], 'connection_ack');

      client.send({
        'id': 's',
        'type': 'start',
        'payload': {'query': 'subscription { tick }'},
      });
      await tick(1);
      expect(await client.next(), {
        'type': 'data',
        'id': 's',
        'payload': {
          'data': {'tick': 1},
        },
      });

      client.send({'id': 's', 'type': 'stop'});
      expect(await client.next(), {'type': 'complete', 'id': 's'});
      await client.close();
    });

    test('rejects a connection that onConnect rejects', () async {
      var client = await connect(['graphql-ws']);
      client.send({
        'type': 'connection_init',
        'payload': {'token': 'bad'},
      });
      expect((await client.next())['type'], 'connection_error');
      await client.close();
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:graphql_server2/graphql_transport_ws.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// A [TransportWSServer] of [graphQL], which may reject connections.
class _Server extends TransportWSServer {
  final GraphQL graphQL;
  final bool accept;

  _Server(
    super.channel,
    this.graphQL, {
    required super.close,
    super.connectionInitWaitTimeout,
    this.accept = true,
  });

  @override
  bool onConnect(Map<String, dynamic>? payload) => accept;

  @override
  Future<Object?> onSubscribe(
    String id,
    String query, {
    Map<String, dynamic>? variables,
    String? operationName,
    Map<String, dynamic>? extensions,
  }) => graphQL.parseAndExecute(
    query,
    variableValues: variables ?? const {},
    operationName: operationName,
  );
}

/// A client of a [_Server], over an in-memory channel.
class _Client {
  final _channel = StreamChannelController<String>();
  final _messages = <Map>[];
  final _waiting = <Completer<Map>>[];
  int? closeCode;
  String? closeReason;
  late final _Server server;

  _Client(
    GraphQL graphQL, {
    bool accept = true,
    Duration timeout = const Duration(seconds: 3),
  }) {
    server = _Server(
      _channel.local,
      graphQL,
      accept: accept,
      connectionInitWaitTimeout: timeout,
      close: (code, reason) {
        closeCode = code;
        closeReason = reason;
        _channel.local.sink.close();
      },
    );
    _channel.foreign.stream.listen((text) {
      var message = json.decode(text) as Map;
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete(message);
      } else {
        _messages.add(message);
      }
    });
  }

  void send(Map<String, dynamic> message) =>
      _channel.foreign.sink.add(json.encode(message));

  /// The next message from the server.
  Future<Map> next() {
    if (_messages.isNotEmpty) return Future.value(_messages.removeAt(0));
    var completer = Completer<Map>();
    _waiting.add(completer);
    return completer.future.timeout(const Duration(seconds: 3));
  }

  Future<void> connect() async {
    send({'type': 'connection_init'});
    expect(await next(), {'type': 'connection_ack'});
  }

  /// Waits for the server to end the connection.
  Future<void> closed() => server.done.timeout(const Duration(seconds: 3));

  void disconnect() => _channel.foreign.sink.close();
}

/// Waits until [condition] holds.
Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting');
}

void main() {
  late StreamController<int> ticks;
  var cancelled = false;

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

  setUp(() {
    cancelled = false;
    ticks = StreamController<int>(onCancel: () => cancelled = true);
  });

  group('operations', () {
    test('a query gives one result, then completes', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({
        'id': '1',
        'type': 'subscribe',
        'payload': {
          'query': r'query($n: String) { hello(name: $n) }',
          'variables': {'n': 'Dart'},
        },
      });
      expect(await client.next(), {
        'id': '1',
        'type': 'next',
        'payload': {
          'data': {'hello': 'Hello, Dart!'},
        },
      });
      expect(await client.next(), {'id': '1', 'type': 'complete'});
    });

    test('a subscription gives its events, then completes', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({
        'id': 's',
        'type': 'subscribe',
        'payload': {'query': 'subscription { tick }'},
      });
      await until(() => ticks.hasListener);
      ticks
        ..add(1)
        ..add(2);
      expect((await client.next())['payload'], {
        'data': {'tick': 1},
      });
      expect((await client.next())['payload'], {
        'data': {'tick': 2},
      });
      await ticks.close();
      expect(await client.next(), {'id': 's', 'type': 'complete'});
    });

    test('a complete from the client stops a subscription', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({
        'id': 's',
        'type': 'subscribe',
        'payload': {'query': 'subscription { tick }'},
      });
      await until(() => ticks.hasListener);
      client.send({'id': 's', 'type': 'complete'});
      await until(() => cancelled);

      // The id can be used again.
      client.send({
        'id': 's',
        'type': 'subscribe',
        'payload': {'query': '{ hello }'},
      });
      expect((await client.next())['type'], 'next');
    });

    test('an invalid operation is an error, without a complete', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({
        'id': '1',
        'type': 'subscribe',
        'payload': {'query': '{ hello }}'},
      });
      var error = await client.next();
      expect(error['type'], 'error');
      expect(error['id'], '1');
      expect(
        error['payload'],
        isA<List>().having((l) => l, 'errors', isNotEmpty),
      );

      client.send({'type': 'ping'});
      expect(await client.next(), {'type': 'pong'});
    });

    test('the end of the connection stops its subscriptions', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({
        'id': 's',
        'type': 'subscribe',
        'payload': {'query': 'subscription { tick }'},
      });
      await until(() => ticks.hasListener);
      client.disconnect();
      await client.closed();
      await until(() => cancelled);
    });

    test('a complete of an unknown id is ignored', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({'id': 'x', 'type': 'complete'});
      client.send({'type': 'ping'});
      expect(await client.next(), {'type': 'pong'});
      expect(client.closeCode, isNull);
    });
  });

  group('closes the connection', () {
    Future<void> expectClose(_Client client, int code) async {
      await client.closed();
      expect(client.closeCode, code);
    }

    test('for an operation before the connection is acknowledged', () async {
      var client = _Client(graphQL);
      client.send({
        'id': '1',
        'type': 'subscribe',
        'payload': {'query': '{ hello }'},
      });
      await expectClose(client, TransportWSCloseCode.unauthorized);
    });

    test('for a second connection_init', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({'type': 'connection_init'});
      await expectClose(
        client,
        TransportWSCloseCode.tooManyInitialisationRequests,
      );
    });

    test('for a subscribe of an id in use', () async {
      var client = _Client(graphQL);
      await client.connect();
      Map<String, dynamic> subscribe() => {
        'id': 's',
        'type': 'subscribe',
        'payload': {'query': 'subscription { tick }'},
      };
      client.send(subscribe());
      await until(() => ticks.hasListener);
      client.send(subscribe());
      await expectClose(client, TransportWSCloseCode.subscriberAlreadyExists);
      await until(() => cancelled);
    });

    test('for an unknown type, or a message that is not JSON', () async {
      var client = _Client(graphQL);
      client.send({'type': 'start'});
      await expectClose(client, TransportWSCloseCode.badRequest);

      var other = _Client(graphQL);
      other._channel.foreign.sink.add('not json');
      await expectClose(other, TransportWSCloseCode.badRequest);
    });

    test('for a subscribe without a query', () async {
      var client = _Client(graphQL);
      await client.connect();
      client.send({'id': '1', 'type': 'subscribe', 'payload': {}});
      await expectClose(client, TransportWSCloseCode.badRequest);
    });

    test('without a connection_init in time', () async {
      var client = _Client(graphQL, timeout: const Duration(milliseconds: 20));
      await expectClose(
        client,
        TransportWSCloseCode.connectionInitialisationTimeout,
      );
    });

    test('when onConnect rejects the connection', () async {
      var client = _Client(graphQL, accept: false);
      client.send({'type': 'connection_init'});
      await expectClose(client, TransportWSCloseCode.forbidden);
    });
  });
}

import 'dart:async';

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:graphql_server2/subscriptions_transport_ws.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// A legacy [Server] of [graphQL].
class _Server extends Server {
  final GraphQL graphQL;

  /// Completes when connections may be accepted, if given.
  final Future<void>? accepting;

  _Server(
    super.client,
    this.graphQL, {
    this.accepting,
    super.keepAliveInterval,
  });

  @override
  Future<bool> onConnect(RemoteClient client, [Map? connectionParams]) async {
    await accepting;
    return true;
  }

  @override
  Future<GraphQLResult> onOperation(
    String? id,
    String query, [
    Map<String, dynamic>? variables,
    String? operationName,
  ]) async {
    try {
      return GraphQLResult(
        await graphQL.parseAndExecute(
          query,
          variableValues: variables ?? const {},
          operationName: operationName,
        ),
      );
    } on GraphQLException catch (e) {
      return GraphQLResult(null, errors: e.errors);
    }
  }
}

/// A [RemoteClient] that records what the server sends it, also after its
/// connection has ended, when a [RemoteClient] drops it.
class _RecordingClient extends RemoteClient {
  final sent = <OperationMessage>[];
  late final StreamController<OperationMessage> _sent = StreamController()
    ..stream.listen(sent.add);

  _RecordingClient(super.channel) : super.withoutJson();

  @override
  StreamSink<OperationMessage> get sink => _sent.sink;
}

void main() {
  late StreamController<int> ticks;
  // Opened to let the `slow` subscription's resolver return its stream.
  var gate = Completer<void>();
  var slowCancelled = false;
  late StreamChannelController<Map> channel;
  late StreamIterator<Map> messages;
  late _Server server;

  var graphQL = GraphQL(
    graphQLSchema(
      queryType: objectType(
        'Query',
        fields: [
          field('hello', graphQLString, resolve: (_, _) => 'world'),
          field(
            'boom',
            graphQLString,
            resolve: (_, _) => throw StateError('boom'),
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
          field(
            'slow',
            graphQLInt,
            resolve: (_, _) async {
              await gate.future;
              return StreamController<Map<String, dynamic>>(
                onCancel: () => slowCancelled = true,
              ).stream;
            },
          ),
          field(
            'fails',
            graphQLInt,
            resolve: (_, _) => Stream<Map<String, dynamic>>.error(
              GraphQLException.fromMessage('It failed'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<Map> next() async {
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    return messages.current;
  }

  setUp(() async {
    gate = Completer<void>();
    slowCancelled = false;
    ticks = StreamController<int>();
    channel = StreamChannelController<Map>();
    server = _Server(RemoteClient.withoutJson(channel.local), graphQL);
    messages = StreamIterator(channel.foreign.stream);
    channel.foreign.sink.add({'type': 'connection_init'});
    expect((await next())['type'], 'connection_ack');
  });

  tearDown(() => channel.foreign.sink.close());

  test('a query without variables gives its data, then completes', () async {
    channel.foreign.sink.add({
      'id': '1',
      'type': 'start',
      'payload': {'query': '{ hello }'},
    });
    expect(await next(), {
      'type': 'data',
      'id': '1',
      'payload': {
        'data': {'hello': 'world'},
      },
    });
    expect(await next(), {'type': 'complete', 'id': '1'});
  });

  test('stop cancels a subscription', () async {
    var cancelled = Completer<void>();
    ticks.onCancel = cancelled.complete;
    channel.foreign.sink.add({
      'id': 's',
      'type': 'start',
      'payload': {'query': 'subscription { tick }'},
    });
    for (var i = 0; i < 100 && !ticks.hasListener; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    ticks.add(1);
    expect((await next())['payload'], {
      'data': {'tick': 1},
    });

    channel.foreign.sink.add({'id': 's', 'type': 'stop'});
    await cancelled.future.timeout(const Duration(seconds: 3));
    expect(await next(), {'type': 'complete', 'id': 's'});
  });

  test('an invalid start is an error, and the connection stays', () async {
    channel.foreign.sink.add({'id': '1', 'type': 'start', 'payload': {}});
    var error = await next();
    expect(error['type'], 'error');
    expect(error['id'], '1');

    channel.foreign.sink.add({
      'id': '2',
      'type': 'start',
      'payload': {'query': '{ hello }'},
    });
    expect((await next())['type'], 'data');
    await server.done.timeout(Duration.zero, onTimeout: () {});
  });

  test('a RemoteClient drops a message after its channel closed', () async {
    // A sink that throws once closed, as a WebSocket's does.
    var outgoing = StreamController<String>();
    outgoing.stream.listen(null);
    // An incoming stream that stays open, as a live connection's does.
    var incoming = StreamController<String>();
    var client = RemoteClient(StreamChannel(incoming.stream, outgoing.sink));
    await outgoing.close();
    // The test fails on an uncaught error.
    client.sink.add(OperationMessage(OperationMessage.gqlConnectionKeepAlive));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  test('a RemoteClient reads and writes JSON text', () async {
    var text = StreamChannelController<String>();
    var client = RemoteClient(text.local);
    var received = client.stream.first;
    text.foreign.sink
      ..add('not json')
      ..add('{"foo": 1}')
      ..add('{"type": "connection_init"}');
    expect((await received).type, 'connection_init');

    var sent = text.foreign.stream.first;
    client.sink.add(OperationMessage(OperationMessage.gqlConnectionAck));
    expect(await sent, '{"type":"connection_ack"}');
  });

  Future<void> listening() async {
    for (var i = 0; i < 100 && !ticks.hasListener; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(ticks.hasListener, isTrue);
  }

  void start(String id, String query) => channel.foreign.sink.add({
    'id': id,
    'type': 'start',
    'payload': {'query': query},
  });

  test('the end of the connection stops its operations', () async {
    var cancelled = Completer<void>();
    ticks.onCancel = cancelled.complete;
    start('s', 'subscription { tick }');
    await listening();

    await channel.foreign.sink.close();
    await server.done.timeout(const Duration(seconds: 3));
    await cancelled.future.timeout(const Duration(seconds: 3));
  });

  test('connection_terminate stops operations, and ends', () async {
    start('s', 'subscription { tick }');
    await listening();
    channel.foreign.sink.add({'type': 'connection_terminate'});
    await server.done.timeout(const Duration(seconds: 3));
    expect(ticks.hasListener, isFalse);
  });

  test('a start of an id in use stops its operation', () async {
    var cancelled = Completer<void>();
    ticks.onCancel = cancelled.complete;
    start('1', 'subscription { tick }');
    await listening();

    start('1', '{ hello }');
    await cancelled.future.timeout(const Duration(seconds: 3));
    expect(await next(), {
      'type': 'data',
      'id': '1',
      'payload': {
        'data': {'hello': 'world'},
      },
    });
    expect(await next(), {'type': 'complete', 'id': '1'});
  });

  test('an operation that throws is answered with errors', () async {
    start('1', '{ boom }');
    var data = await next();
    expect(data['type'], 'data');
    expect(data['payload']['errors'], isNotEmpty);
    expect(await next(), {'type': 'complete', 'id': '1'});
  });

  test('a stream error gives the errors of its GraphQLException', () async {
    start('1', 'subscription { fails }');
    var data = await next();
    expect(data['payload'], {
      'errors': [
        {'message': 'It failed'},
      ],
    });
    expect(await next(), {'type': 'complete', 'id': '1'});
  });

  test('a connection that fails is closed', () async {
    channel.foreign.sink.addError(StateError('broken'));
    await server.done.timeout(const Duration(seconds: 3));
    // The server closed its side, which ends the client's stream.
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isFalse,
    );
  });

  test('a stream given after a stop is cleaned up', () async {
    start('1', 'subscription { slow }');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    channel.foreign.sink.add({'id': '1', 'type': 'stop'});
    expect(await next(), {'type': 'complete', 'id': '1'});
    gate.complete();
    for (var i = 0; i < 100 && !slowCancelled; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(slowCancelled, isTrue);
  });

  test('a connection that ends during onConnect is not acknowledged', () async {
    var incoming = StreamController<Map>();
    var accepting = Completer<void>();
    var client = _RecordingClient(
      StreamChannel(incoming.stream, StreamController<Map>().sink),
    );
    var received = client.sent;
    var slow = _Server(
      client,
      graphQL,
      accepting: accepting.future,
      keepAliveInterval: const Duration(milliseconds: 10),
    );
    incoming.add({'type': 'connection_init'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await incoming.close();
    await slow.done.timeout(const Duration(seconds: 3));

    accepting.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(received, isEmpty);
  });
}

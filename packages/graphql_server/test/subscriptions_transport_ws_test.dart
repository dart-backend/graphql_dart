import 'dart:async';

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:graphql_server2/subscriptions_transport_ws.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// A legacy [Server] of [graphQL].
class _Server extends Server {
  final GraphQL graphQL;

  _Server(super.client, this.graphQL);

  @override
  bool onConnect(RemoteClient client, [Map? connectionParams]) => true;

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

void main() {
  late StreamController<int> ticks;
  late StreamChannelController<Map> channel;
  late StreamIterator<Map> messages;
  late _Server server;

  var graphQL = GraphQL(
    graphQLSchema(
      queryType: objectType(
        'Query',
        fields: [field('hello', graphQLString, resolve: (_, _) => 'world')],
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

  Future<Map> next() async {
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    return messages.current;
  }

  setUp(() async {
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

  test('a RemoteClient reads and writes JSON text', () async {
    var text = StreamChannelController<String>();
    var client = RemoteClient(text.local);
    var received = client.stream.first;
    text.foreign.sink
      ..add('not json')
      ..add('{"type": "connection_init"}');
    expect((await received).type, 'connection_init');

    var sent = text.foreign.stream.first;
    client.sink.add(OperationMessage(OperationMessage.gqlConnectionAck));
    expect(await sent, '{"type":"connection_ack"}');
  });
}

import 'dart:async';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:graphql_server2/graphql_transport_ws.dart';
import 'package:graphql_server2/subscriptions_transport_ws.dart' as stw;
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';

/// The WebSocket subprotocol of the `graphql-transport-ws` protocol, of the
/// `graphql-ws` library, which current clients use.
const graphQLTransportWSProtocol = 'graphql-transport-ws';

/// The WebSocket subprotocol of Apollo's older `subscriptions-transport-ws`
/// protocol.
const subscriptionsTransportWSProtocol = 'graphql-ws';

/// Decides whether to accept the WebSocket connection of [req], given the
/// payload of its `connection_init`, such as credentials.
typedef GraphQLWSConnectHandler = FutureOr<bool> Function(
  RequestContext req,
  Map? payload,
);

/// A [RequestHandler] that serves a spec-compliant GraphQL backend, over
/// WebSockets. This endpoint only supports WebSockets, and can be used to
/// deliver subscription events.
///
/// It speaks the protocol of the WebSocket subprotocol the client asks for:
///
/// * `graphql-transport-ws`, of the `graphql-ws` library, which current
///   clients use, such as Apollo Client 3, urql and GraphiQL 2;
/// * `graphql-ws`, of Apollo's older `subscriptions-transport-ws`, also when
///   the client asks for none.
///
/// [onConnect] decides whether to accept a connection; all are accepted by
/// default. With `graphql-transport-ws`, a client that sends no
/// `connection_init` within [connectionInitWaitTimeout] is disconnected.
/// [keepAliveInterval] sets how often to send a keep-alive message.
///
/// See:
/// * https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md
/// * https://github.com/apollographql/subscriptions-transport-ws
RequestHandler graphQLWS(
  GraphQL graphQL, {
  Duration? keepAliveInterval,
  Duration connectionInitWaitTimeout = const Duration(seconds: 3),
  GraphQLWSConnectHandler? onConnect,
}) {
  return (req, res) async {
    if (req is! HttpRequestContext) {
      throw AngelHttpException.badRequest(
        message: 'The `graphQLWS` endpoint only accepts HTTP/1.1 requests.',
      );
    }
    if (!WebSocketTransformer.isUpgradeRequest(req.rawRequest!)) {
      throw AngelHttpException.badRequest(
        message: 'The `graphQLWS` endpoint only accepts WebSockets.',
      );
    }

    await res.detach();
    var socket = await WebSocketTransformer.upgrade(
      req.rawRequest!,
      protocolSelector: (protocols) {
        // The modern protocol, if the client offers both.
        for (var protocol in [
          graphQLTransportWSProtocol,
          subscriptionsTransportWSProtocol,
        ]) {
          if (protocols.contains(protocol)) return protocol;
        }
        throw AngelHttpException.badRequest(
          message:
              'Only the "$graphQLTransportWSProtocol" and '
              '"$subscriptionsTransportWSProtocol" protocols are allowed.',
        );
      },
    );
    var channel = IOWebSocketChannel(socket);
    var text = _textChannel(channel);
    var run = _Runner(graphQL, req, res);

    if (socket.protocol == graphQLTransportWSProtocol) {
      var server = _TransportWSServer(
        text,
        run,
        onConnect,
        close: (code, reason) => channel.sink.close(code, reason),
        connectionInitWaitTimeout: connectionInitWaitTimeout,
        keepAliveInterval: keepAliveInterval,
      );
      await server.done;
    } else {
      var server = _LegacyServer(
        stw.RemoteClient(text),
        run,
        onConnect,
        keepAliveInterval,
      );
      await server.done;
    }
  };
}

/// The text messages of [webSocket], written to it one by one rather than
/// piped with `addStream`, which would keep its sink from being closed with
/// a close code.
StreamChannel<String> _textChannel(IOWebSocketChannel webSocket) {
  var outgoing = StreamController<String>();
  outgoing.stream.listen(webSocket.sink.add);
  webSocket.sink.done.whenComplete(outgoing.close);
  return StreamChannel(webSocket.stream.cast<String>(), outgoing.sink);
}

/// Runs the operations of the WebSocket of [req].
class _Runner {
  final GraphQL graphQL;
  final RequestContext req;
  final ResponseContext res;

  _Runner(this.graphQL, this.req, this.res);

  Future<Object?> call(
    String query,
    Map<String, dynamic>? variables,
    String? operationName,
  ) => graphQL.parseAndExecute(
    query,
    operationName: operationName,
    sourceUrl: 'input',
    globalVariables: {'__requestctx': req, '__responsectx': res},
    variableValues: variables ?? const {},
  );
}

class _TransportWSServer extends TransportWSServer {
  final _Runner run;
  final GraphQLWSConnectHandler? connect;

  _TransportWSServer(
    super.channel,
    this.run,
    this.connect, {
    required super.close,
    super.connectionInitWaitTimeout,
    super.keepAliveInterval,
  });

  @override
  FutureOr<bool> onConnect(Map<String, dynamic>? payload) =>
      connect?.call(run.req, payload) ?? true;

  @override
  Future<Object?> onSubscribe(
    String id,
    String query, {
    Map<String, dynamic>? variables,
    String? operationName,
    Map<String, dynamic>? extensions,
  }) => run(query, variables, operationName);
}

class _LegacyServer extends stw.Server {
  final _Runner run;
  final GraphQLWSConnectHandler? connect;

  _LegacyServer(
    super.client,
    this.run,
    this.connect,
    Duration? keepAliveInterval,
  ) : super(keepAliveInterval: keepAliveInterval);

  @override
  FutureOr<bool> onConnect(stw.RemoteClient client, [Map? connectionParams]) =>
      connect?.call(run.req, connectionParams) ?? true;

  @override
  Future<stw.GraphQLResult> onOperation(
    String? id,
    String query, [
    Map<String, dynamic>? variables,
    String? operationName,
  ]) async {
    try {
      return stw.GraphQLResult(await run(query, variables, operationName));
    } on GraphQLException catch (e) {
      return stw.GraphQLResult(null, errors: e.errors);
    }
  }
}

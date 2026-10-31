import 'dart:async';
import 'dart:convert';

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:stream_channel/stream_channel.dart';

import 'message.dart';

/// The server side of one connection of the `graphql-transport-ws` protocol,
/// which the `graphql-ws` client and Apollo Client 3 speak.
///
/// It reads and writes JSON text over [channel], such as a WebSocket's, and
/// closes the connection with [close], given a close code of
/// [TransportWSCloseCode] and a reason, as the protocol reports errors that
/// way. Extend it, and implement [onSubscribe] to run operations, usually with
/// `GraphQL.parseAndExecute`.
///
/// See: https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md
abstract class TransportWSServer {
  /// The JSON text messages of the connection.
  final StreamChannel<String> channel;

  /// Closes the connection with a close code and a reason.
  final void Function(int code, String reason) close;

  /// How long to wait for `connection_init`, before closing with
  /// [TransportWSCloseCode.connectionInitialisationTimeout].
  final Duration connectionInitWaitTimeout;

  /// How often to send a `ping` once connected, if at all.
  final Duration? keepAliveInterval;

  final _operations = <String, _Operation>{};
  final _done = Completer<void>();
  StreamSubscription<String>? _subscription;
  Timer? _initTimer, _keepAlive;
  bool _initReceived = false, _acknowledged = false, _closed = false;

  TransportWSServer(
    this.channel, {
    required this.close,
    this.connectionInitWaitTimeout = const Duration(seconds: 3),
    this.keepAliveInterval,
  }) {
    _initTimer = Timer(connectionInitWaitTimeout, () {
      if (!_initReceived) {
        _closeWith(
          TransportWSCloseCode.connectionInitialisationTimeout,
          'Connection initialisation timeout',
        );
      }
    });
    _subscription = channel.stream.listen(
      _onText,
      // An error, such as a binary message, is an invalid message: the
      // connection is closed, rather than kept open unanswered.
      onError: (_) =>
          _closeWith(TransportWSCloseCode.badRequest, 'Invalid message'),
      onDone: _end,
    );
  }

  /// Completes when the connection has ended.
  Future<void> get done => _done.future;

  /// Whether the connection was acknowledged, so operations can run.
  bool get isAcknowledged => _acknowledged;

  /// Decides whether to accept a connection, given the `payload` of its
  /// `connection_init`, such as credentials. Accepts all by default; return
  /// `false` to close it with [TransportWSCloseCode.forbidden].
  FutureOr<bool> onConnect(Map<String, dynamic>? payload) => true;

  /// The payload of the `connection_ack`, if any.
  Map<String, dynamic>? get connectionAckPayload => null;

  /// Runs the operation [id] of the `subscribe` payload: its [query],
  /// [variables], [operationName] and [extensions].
  ///
  /// Returns the data of a query or mutation, or a `Stream` of execution
  /// results (`{'data': ...}`, with `'errors'` if any) of a subscription, as
  /// `GraphQL.parseAndExecute` does. A [GraphQLException] it throws is sent
  /// as an `error` message.
  FutureOr<Object?> onSubscribe(
    String id,
    String query, {
    Map<String, dynamic>? variables,
    String? operationName,
    Map<String, dynamic>? extensions,
  });

  void _onText(String text) {
    TransportWSMessage message;
    try {
      message = TransportWSMessage.fromJson(json.decode(text));
    } on FormatException catch (e) {
      return _closeWith(TransportWSCloseCode.badRequest, e.message);
    }

    switch (message.type) {
      case TransportWSMessage.connectionInit:
        _onInit(message);
      case TransportWSMessage.ping:
        _send(TransportWSMessage(TransportWSMessage.pong));
      case TransportWSMessage.pong:
        break;
      case TransportWSMessage.subscribe:
        _onSubscribe(message);
      case TransportWSMessage.complete:
        // Of an operation that is done, or unknown, it is ignored.
        if (message.id case var id?) _operations.remove(id)?.cancel();
      default:
        _closeWith(
          TransportWSCloseCode.badRequest,
          'Invalid message type "${message.type}"',
        );
    }
  }

  Future<void> _onInit(TransportWSMessage message) async {
    if (_initReceived) {
      return _closeWith(
        TransportWSCloseCode.tooManyInitialisationRequests,
        'Too many initialisation requests',
      );
    }
    _initReceived = true;
    _initTimer?.cancel();

    var payload = message.payload;
    if (payload != null && payload is! Map) {
      return _closeWith(
        TransportWSCloseCode.badRequest,
        'The payload of "connection_init" must be an object',
      );
    }

    bool accepted;
    try {
      accepted = await onConnect((payload as Map?)?.cast<String, dynamic>());
    } catch (_) {
      accepted = false;
    }
    if (_closed) return;
    if (!accepted) {
      return _closeWith(TransportWSCloseCode.forbidden, 'Forbidden');
    }

    _acknowledged = true;
    _send(
      TransportWSMessage(
        TransportWSMessage.connectionAck,
        payload: connectionAckPayload,
      ),
    );
    if (keepAliveInterval case var interval?) {
      _keepAlive = Timer.periodic(
        interval,
        (_) => _send(TransportWSMessage(TransportWSMessage.ping)),
      );
    }
  }

  Future<void> _onSubscribe(TransportWSMessage message) async {
    if (!_acknowledged) {
      return _closeWith(TransportWSCloseCode.unauthorized, 'Unauthorized');
    }

    var id = message.id;
    var payload = message.payload;
    if (id == null || id.isEmpty) {
      return _closeWith(
        TransportWSCloseCode.badRequest,
        'A "subscribe" message must have an "id"',
      );
    }
    if (payload is! Map || payload['query'] is! String) {
      return _closeWith(
        TransportWSCloseCode.badRequest,
        'The payload of "subscribe" must be an object with a string "query"',
      );
    }
    var variables = payload['variables'];
    var operationName = payload['operationName'];
    var extensions = payload['extensions'];
    if ((variables != null && variables is! Map) ||
        (operationName != null && operationName is! String) ||
        (extensions != null && extensions is! Map)) {
      return _closeWith(
        TransportWSCloseCode.badRequest,
        'Invalid "variables", "operationName" or "extensions" of "subscribe"',
      );
    }
    if (_operations.containsKey(id)) {
      return _closeWith(
        TransportWSCloseCode.subscriberAlreadyExists,
        'Subscriber for $id already exists',
      );
    }

    // Registered before running, so a duplicate id or a `complete` that
    // comes while it runs is seen.
    var operation = _operations[id] = _Operation();

    Object? result;
    try {
      result = await onSubscribe(
        id,
        payload['query'] as String,
        variables: (variables as Map?)?.cast<String, dynamic>(),
        operationName: operationName as String?,
        extensions: (extensions as Map?)?.cast<String, dynamic>(),
      );
    } catch (e) {
      if (operation.isActive(this, id)) _sendError(id, e);
      return;
    }
    if (!operation.isActive(this, id)) {
      // Stopped while it ran: a stream it gave is listened to and cancelled
      // at once, so that its source cleans up.
      if (result is Stream) result.listen(null).cancel();
      return;
    }

    if (result is Stream) {
      operation.subscription = result.listen(
        (event) {
          if (operation.isActive(this, id)) {
            _send(
              TransportWSMessage(
                TransportWSMessage.next,
                id: id,
                payload: event,
              ),
            );
          }
        },
        onError: (Object e) {
          if (operation.isActive(this, id)) _sendError(id, e);
        },
        onDone: () {
          if (operation.isActive(this, id)) _complete(id);
        },
        cancelOnError: true,
      );
    } else {
      _send(
        TransportWSMessage(
          TransportWSMessage.next,
          id: id,
          payload: {'data': result},
        ),
      );
      _complete(id);
    }
  }

  void _complete(String id) {
    _operations.remove(id);
    _send(TransportWSMessage(TransportWSMessage.complete, id: id));
  }

  /// Ends operation [id] with an `error` message of [e].
  void _sendError(String id, Object e) {
    _operations.remove(id)?.cancel();
    var errors = e is GraphQLException
        ? e.errors.map((e) => e.toJson()).toList()
        : [
            {'message': e.toString()},
          ];
    _send(
      TransportWSMessage(TransportWSMessage.error, id: id, payload: errors),
    );
  }

  void _send(TransportWSMessage message) {
    if (!_closed) channel.sink.add(json.encode(message.toJson()));
  }

  void _closeWith(int code, String reason) {
    if (_closed) return;
    close(code, reason);
    _end();
  }

  /// Stops all operations and timers, once the connection has ended.
  void _end() {
    if (_closed) return;
    _closed = true;
    _initTimer?.cancel();
    _keepAlive?.cancel();
    for (var operation in _operations.values) {
      operation.cancel();
    }
    _operations.clear();
    _subscription?.cancel();
    if (!_done.isCompleted) _done.complete();
  }
}

/// A running operation, and its subscription once it is a subscription.
class _Operation {
  StreamSubscription? subscription;

  /// Whether it is still the operation of [id] of [server], neither stopped
  /// nor replaced.
  bool isActive(TransportWSServer server, String id) =>
      !server._closed && identical(server._operations[id], this);

  void cancel() => subscription?.cancel();
}

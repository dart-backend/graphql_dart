import 'dart:async';

import 'package:graphql_schema2/graphql_schema2.dart';

import 'remote_client.dart';
import 'transport.dart';

abstract class Server {
  final RemoteClient client;
  final Duration? keepAliveInterval;
  final Completer _done = Completer();
  StreamSubscription<OperationMessage>? _sub;
  bool _init = false, _ended = false;
  Timer? _timer;

  /// The running operations, by id, so that `stop` and the end of the
  /// connection can cancel them.
  final _operations = <String, _Operation>{};

  /// Completes when the connection has ended, also when it failed.
  Future get done => _done.future;

  Server(this.client, {this.keepAliveInterval}) {
    _sub = client.stream.listen(
      (msg) async {
        if ((msg.type == OperationMessage.gqlConnectionInit) && !_init) {
          try {
            Map? connectionParams;
            if (msg.payload is Map) {
              connectionParams = msg.payload as Map?;
            } else if (msg.payload != null) {
              throw FormatException(
                '${msg.type} payload must be a map (object).',
              );
            }

            var connect = await onConnect(client, connectionParams);
            // The connection may have ended while onConnect ran.
            if (_ended) return;
            if (!connect) throw false;
            _init = true;
            client.sink.add(
              OperationMessage(OperationMessage.gqlConnectionAck),
            );

            if (keepAliveInterval != null) {
              client.sink.add(
                OperationMessage(OperationMessage.gqlConnectionKeepAlive),
              );
              _timer ??= Timer.periodic(keepAliveInterval!, (timer) {
                client.sink.add(
                  OperationMessage(OperationMessage.gqlConnectionKeepAlive),
                );
              });
            }
          } catch (e) {
            if (e == false) {
              _reportError('The connection was rejected.');
            } else {
              _reportError(e.toString());
            }
          }
        } else if (_init) {
          if (msg.type == OperationMessage.gqlStart) {
            await _start(msg);
          } else if (msg.type == OperationMessage.gqlStop) {
            if (msg.id case var id?) _stop(id);
          } else if (msg.type == OperationMessage.gqlConnectionTerminate) {
            await _end();
            client.close();
          }
        }
      },
      // A connection that failed is closed, rather than kept open unanswered.
      onError: (_) async {
        await _end();
        client.close();
      },
      onDone: _end,
    );
  }

  Future<void> _start(OperationMessage msg) async {
    var id = msg.id;
    if (id == null) {
      return _reportError('${msg.type} id is required.');
    }

    // An invalid `start` is reported to the client, and the connection kept.
    String? invalid;
    var payload = msg.payload;
    if (payload == null) {
      invalid = '${msg.type} payload is required.';
    } else if (payload is! Map) {
      invalid = '${msg.type} payload must be a map (object).';
    } else if (payload['query'] is! String) {
      invalid = '${msg.type} payload must contain a string named "query".';
    } else if (payload['variables'] != null && payload['variables'] is! Map) {
      invalid =
          '${msg.type} payload\'s "variables" field must be a map (object).';
    } else if (payload['operationName'] != null &&
        payload['operationName'] is! String) {
      invalid =
          '${msg.type} payload\'s "operationName" field must be a string.';
    }
    if (invalid != null) {
      return client.sink.add(
        OperationMessage(
          OperationMessage.gqlError,
          id: id,
          payload: {'message': invalid},
        ),
      );
    }

    payload as Map;
    // A `start` of an id in use replaces its operation, which is stopped.
    // Registered before running, so a `stop` that comes while it runs is
    // seen.
    _operations.remove(id)?.cancel();
    var operation = _operations[id] = _Operation();

    GraphQLResult result;
    try {
      result = await onOperation(
        id,
        payload['query'] as String,
        (payload['variables'] as Map?)?.cast<String, dynamic>(),
        payload['operationName'] as String?,
      );
    } catch (e) {
      if (!_isActive(id, operation)) return;
      _send(id, operation, {'errors': _errorsOf(e)});
      return _finish(id, operation);
    }
    if (!_isActive(id, operation)) {
      // Stopped while it ran: a stream it gave is listened to and cancelled
      // at once, so that its source cleans up.
      var data = result.data;
      if (data is Map && data['data'] is Stream) data = data['data'];
      if (data is Stream) data.listen(null).cancel();
      return;
    }

    var data = result.data;
    if (result.errors.isNotEmpty) {
      _send(id, operation, {
        'errors': result.errors.map((e) => e.toJson()).toList(),
      });
      return _finish(id, operation);
    }

    if (data is Map && data.keys.length == 1 && data.containsKey('data')) {
      data = data['data'];
    }

    if (data is Stream) {
      operation.subscription = data.listen(
        (event) {
          // Events are execution results, of `data` and maybe `errors`.
          _send(
            id,
            operation,
            event is Map && event.containsKey('data') ? event : {'data': event},
          );
        },
        onError: (Object e) {
          _send(id, operation, {'errors': _errorsOf(e)});
          _finish(id, operation);
        },
        onDone: () => _finish(id, operation),
        cancelOnError: true,
      );
    } else {
      _send(id, operation, {'data': data});
      _finish(id, operation);
    }
  }

  /// Whether [operation] is still the operation of [id], neither stopped nor
  /// replaced.
  bool _isActive(String id, _Operation operation) =>
      !_ended && identical(_operations[id], operation);

  /// The JSON errors of [e]: those of a [GraphQLException], or its message.
  List<Map<String, dynamic>> _errorsOf(Object e) => e is GraphQLException
      ? e.errors.map((e) => e.toJson()).toList()
      : [
          {'message': e.toString()},
        ];

  void _send(String id, _Operation operation, Object? payload) {
    if (_isActive(id, operation)) {
      client.sink.add(
        OperationMessage(OperationMessage.gqlData, id: id, payload: payload),
      );
    }
  }

  /// Ends operation [id], with a `complete` message.
  void _finish(String id, _Operation operation) {
    if (!_isActive(id, operation)) return;
    _operations.remove(id);
    client.sink.add(OperationMessage(OperationMessage.gqlComplete, id: id));
  }

  /// Stops operation [id], at the client's request.
  void _stop(String id) {
    var operation = _operations.remove(id);
    if (operation == null) return;
    operation.cancel();
    client.sink.add(OperationMessage(OperationMessage.gqlComplete, id: id));
  }

  /// Stops all operations and the keep-alive timer, once the connection has
  /// ended, and completes [done].
  Future<void> _end() async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    for (var operation in _operations.values) {
      operation.cancel();
    }
    _operations.clear();
    await _sub?.cancel();
    if (!_done.isCompleted) _done.complete();
  }

  void _reportError(String message) {
    client.sink.add(
      OperationMessage(
        OperationMessage.gqlConnectionError,
        payload: {'message': message},
      ),
    );
  }

  FutureOr<bool> onConnect(RemoteClient client, [Map? connectionParams]);

  FutureOr<GraphQLResult> onOperation(
    String? id,
    String query, [
    Map<String, dynamic>? variables,
    String? operationName,
  ]);
}

/// A running operation, and its subscription once it is a subscription.
class _Operation {
  StreamSubscription? subscription;

  void cancel() => subscription?.cancel();
}

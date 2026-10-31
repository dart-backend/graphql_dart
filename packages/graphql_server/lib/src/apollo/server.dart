import 'dart:async';

import 'remote_client.dart';
import 'transport.dart';

abstract class Server {
  final RemoteClient client;
  final Duration? keepAliveInterval;
  final Completer _done = Completer();
  StreamSubscription<OperationMessage>? _sub;
  bool _init = false;
  Timer? _timer;

  /// The subscriptions of the running operations, by id, so that `stop` and
  /// the end of the connection can cancel them.
  final _operations = <String, StreamSubscription?>{};

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
            _cancelAll();
            await _sub?.cancel();
          }
        }
      },
      onError: (e) {
        _cancelAll();
        if (!_done.isCompleted) _done.completeError(e);
      },
      onDone: () {
        _cancelAll();
        if (!_done.isCompleted) _done.complete();
      },
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
    // Registered before running, so a `stop` that comes while it runs is
    // seen.
    _operations[id] = null;
    var result = await onOperation(
      id,
      payload['query'] as String,
      (payload['variables'] as Map?)?.cast<String, dynamic>(),
      payload['operationName'] as String?,
    );
    if (!_operations.containsKey(id)) return;

    var data = result.data;
    if (result.errors.isNotEmpty) {
      _send(id, {'errors': result.errors.map((e) => e.toJson()).toList()});
      return _finish(id);
    }

    if (data is Map && data.keys.length == 1 && data.containsKey('data')) {
      data = data['data'];
    }

    if (data is Stream) {
      _operations[id] = data.listen(
        (event) {
          // Events are execution results, of `data` and maybe `errors`.
          _send(
            id,
            event is Map && event.containsKey('data') ? event : {'data': event},
          );
        },
        onError: (Object e) {
          _send(id, {
            'errors': [
              {'message': e.toString()},
            ],
          });
          _finish(id);
        },
        onDone: () => _finish(id),
        cancelOnError: true,
      );
    } else {
      _send(id, {'data': data});
      _finish(id);
    }
  }

  void _send(String id, Object? payload) {
    if (_operations.containsKey(id)) {
      client.sink.add(
        OperationMessage(OperationMessage.gqlData, id: id, payload: payload),
      );
    }
  }

  /// Ends operation [id], with a `complete` message.
  void _finish(String id) {
    _operations.remove(id);
    client.sink.add(OperationMessage(OperationMessage.gqlComplete, id: id));
  }

  /// Stops operation [id], at the client's request.
  void _stop(String id) {
    if (!_operations.containsKey(id)) return;
    _operations.remove(id)?.cancel();
    client.sink.add(OperationMessage(OperationMessage.gqlComplete, id: id));
  }

  void _cancelAll() {
    _timer?.cancel();
    for (var subscription in _operations.values) {
      subscription?.cancel();
    }
    _operations.clear();
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

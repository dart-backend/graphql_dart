/// A message of the `graphql-transport-ws` protocol.
///
/// See: https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md
class TransportWSMessage {
  /// Sent by the client to open a connection, with an optional payload such
  /// as credentials.
  static const String connectionInit = 'connection_init';

  /// Sent by the server to accept a connection.
  static const String connectionAck = 'connection_ack';

  /// Sent by either side; the other replies with [pong].
  static const String ping = 'ping';

  /// The reply to a [ping], or a heartbeat of its own.
  static const String pong = 'pong';

  /// Sent by the client to start an operation, of an `id` it chooses.
  static const String subscribe = 'subscribe';

  /// A result of an operation.
  static const String next = 'next';

  /// The errors that ended an operation; no [complete] follows.
  static const String error = 'error';

  /// Sent by the server when an operation is done, and by the client to stop
  /// one.
  static const String complete = 'complete';

  /// The type of this message.
  final String type;

  /// The operation this message is of, if any.
  final String? id;

  /// The payload of this message, if any.
  final Object? payload;

  const TransportWSMessage(this.type, {this.id, this.payload});

  /// Reads a message from its JSON object; throws a [FormatException] if it
  /// has no string `type`, or an `id` that is not a string.
  factory TransportWSMessage.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('A message must be a JSON object.');
    }
    var type = json['type'];
    if (type is! String) {
      throw const FormatException('A message must have a string "type".');
    }
    var id = json['id'];
    if (id != null && id is! String) {
      throw const FormatException('The "id" of a message must be a string.');
    }
    return TransportWSMessage(
      type,
      id: id as String?,
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (payload != null) 'payload': payload,
  };
}

/// The WebSocket close codes of the `graphql-transport-ws` protocol.
abstract final class TransportWSCloseCode {
  /// An invalid message: of an unknown type, or malformed.
  static const int badRequest = 4400;

  /// An operation before the connection was acknowledged.
  static const int unauthorized = 4401;

  /// A connection the server rejected, such as one that failed to
  /// authenticate.
  static const int forbidden = 4403;

  /// No `connection_init` within the server's wait timeout.
  static const int connectionInitialisationTimeout = 4408;

  /// A `subscribe` of an `id` that is still in use.
  static const int subscriberAlreadyExists = 4409;

  /// A second `connection_init`.
  static const int tooManyInitialisationRequests = 4429;
}

/// An implementation of the `graphql-transport-ws` protocol, of the
/// `graphql-ws` library, which current GraphQL clients use for subscriptions
/// over WebSockets.
///
/// Its WebSocket subprotocol is `graphql-transport-ws`. For Apollo's older
/// `subscriptions-transport-ws` protocol, whose subprotocol is `graphql-ws`,
/// see `subscriptions_transport_ws.dart`.
///
/// See:
/// https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md
library;

export 'src/transport_ws/message.dart';
export 'src/transport_ws/server.dart';

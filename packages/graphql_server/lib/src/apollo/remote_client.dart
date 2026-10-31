import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

import 'transport.dart';

class RemoteClient extends StreamChannelMixin<OperationMessage> {
  final StreamChannel<Map> channel;
  final StreamChannelController<OperationMessage> _ctrl =
      StreamChannelController();

  RemoteClient.withoutJson(this.channel) {
    // A message sent after the connection has closed is dropped.
    _ctrl.local.stream.listen((m) => _addTo(channel.sink, m.toJson()));
    // The end of [channel], and its errors, are passed on, so that a server
    // knows when the connection has ended. A message that is not one, such
    // as one without a string `type`, is left out.
    channel.stream.listen(
      (m) {
        OperationMessage message;
        try {
          message = OperationMessage.fromJson(m);
        } on ArgumentError {
          return;
        }
        _ctrl.local.sink.add(message);
      },
      onError: _ctrl.local.sink.addError,
      onDone: _ctrl.local.sink.close,
    );
  }

  RemoteClient(StreamChannel<String> channel)
    : this.withoutJson(_jsonChannel(channel));

  /// The JSON objects of the text messages of [channel]; a message that is
  /// not a JSON object is left out.
  ///
  /// Not `jsonDocument.bind(channel).cast<Map>()`, whose sink fails with a
  /// `TypeError` as soon as anything is added to it.
  static StreamChannel<Map> _jsonChannel(StreamChannel<String> channel) {
    var outgoing = StreamController<Map>();
    outgoing.stream
        .map(json.encode)
        .listen((m) => _addTo(channel.sink, m), onDone: channel.sink.close);
    return StreamChannel(
      channel.stream.expand((text) {
        try {
          var message = json.decode(text);
          return message is Map ? [message] : const <Map>[];
        } on FormatException {
          return const <Map>[];
        }
      }),
      outgoing.sink,
    );
  }

  /// Adds [message] to [sink], unless the sink is closed.
  static void _addTo<T>(StreamSink<T> sink, T message) {
    try {
      sink.add(message);
    } on StateError {
      // Closed: the connection has ended.
    }
  }

  @override
  StreamSink<OperationMessage> get sink => _ctrl.foreign.sink;

  @override
  Stream<OperationMessage> get stream => _ctrl.foreign.stream;

  void close() {
    channel.sink.close();
    _ctrl.local.sink.close();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

import 'transport.dart';

class RemoteClient extends StreamChannelMixin<OperationMessage> {
  final StreamChannel<Map> channel;
  final StreamChannelController<OperationMessage> _ctrl =
      StreamChannelController();

  RemoteClient.withoutJson(this.channel) {
    _ctrl.local.stream
        .map((m) => m.toJson())
        .cast<Map>()
        .forEach(channel.sink.add);
    channel.stream.listen((m) {
      _ctrl.local.sink.add(OperationMessage.fromJson(m));
    });
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
        .listen(channel.sink.add, onDone: channel.sink.close);
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

  @override
  StreamSink<OperationMessage> get sink => _ctrl.foreign.sink;

  @override
  Stream<OperationMessage> get stream => _ctrl.foreign.stream;

  void close() {
    channel.sink.close();
    _ctrl.local.sink.close();
  }
}

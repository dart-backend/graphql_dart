import 'dart:async';

/// A utility for batching multiple requests together, to improve application performance.
///
/// Enqueues batches of requests until the next tick, when they are processed in bulk.
///
/// Port of Facebook's `DataLoader`:
/// https://github.com/graphql/dataloader
class DataLoader<Id, Data> {
  /// Invoked to fetch a batch of keys simultaneously.
  final FutureOr<Iterable<Data>> Function(Iterable<Id>) loadMany;

  /// Whether to use a memoization cache to store the results of past lookups.
  final bool cache;

  /// Cached lookups, including ones still being loaded, so a key requested
  /// again while its batch runs is not fetched twice.
  final _cache = <Id, Future<Data>>{};

  /// Keys waiting for the next batch, in the order they were requested.
  var _queue = <Id, Completer<Data>>{};
  bool _scheduled = false;
  bool _closed = false;

  DataLoader(this.loadMany, {this.cache = true});

  Future<void> _dispatch() async {
    // Cleared first, so a load during this batch schedules the next one.
    _scheduled = false;
    if (_queue.isEmpty) return;

    var batch = _queue;
    _queue = {};
    var ids = batch.keys.toList(growable: false);
    var completers = batch.values.toList(growable: false);

    try {
      var data = (await loadMany(ids)).toList(growable: false);
      if (data.length != ids.length) {
        throw StateError(
          'loadMany returned ${data.length} values for ${ids.length} keys.',
        );
      }

      for (var i = 0; i < ids.length; i++) {
        completers[i].complete(data[i]);
      }
    } catch (e, st) {
      for (var i = 0; i < ids.length; i++) {
        var future = completers[i].future;
        // A failed lookup is not cached, so it can be retried. The key may
        // have been cleared and loaded again since, so check it is this one.
        if (identical(_cache[ids[i]], future)) _cache.remove(ids[i]);
        completers[i].completeError(e, st);
      }
    }
  }

  /// Clears the value at [key], if it exists.
  void clear(Id key) => _cache.remove(key);

  /// Clears the entire cache.
  void clearAll() => _cache.clear();

  /// Primes the cache with the provided key and value. If the key already exists, no change is made.
  ///
  /// To forcefully prime the cache, clear the key first with
  /// `loader..clear(key)..prime(key, value)`.
  ///
  /// Does nothing if [cache] is `false` or this loader is closed.
  void prime(Id key, Data value) {
    if (cache && !_closed) {
      _cache.putIfAbsent(key, () => Future<Data>.value(value));
    }
  }

  /// Closes this [DataLoader], cancelling all pending requests and clearing
  /// the cache. A batch already passed to [loadMany] still completes.
  ///
  /// Calling [load] afterwards throws a [StateError].
  void close() {
    _closed = true;
    for (var completer in _queue.values) {
      // Cancelling is not the caller's fault, so a load nobody awaits is not
      // reported as an uncaught error. Awaiting it still throws.
      completer.future.ignore();
      completer.completeError(
        StateError('The DataLoader was closed before the item was loaded.'),
        StackTrace.current,
      );
    }
    _queue.clear();
    _cache.clear();
  }

  /// Returns a [Future] that completes when the next batch of requests completes.
  ///
  /// Throws a [StateError] if this loader is closed.
  Future<Data> load(Id id) {
    if (_closed) throw StateError('Cannot load from a closed DataLoader.');

    if (cache) {
      var cached = _cache[id];
      if (cached != null) return cached;
    }

    var future = _queue.putIfAbsent(id, Completer<Data>.new).future;
    if (cache) _cache[id] = future;

    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_dispatch);
    }

    return future;
  }
}

import 'dart:async';

import 'package:graphql_data_loader2/graphql_data_loader2.dart';
import 'package:test/test.dart';

void main() {
  var numbers = List.generate(10, (i) => i.toStringAsFixed(2));
  var numberLoader = DataLoader<int, String>((ids) {
    print('ID batch: $ids');
    return ids.map((i) => numbers[i]);
  });

  test('batch', () async {
    var zero = numberLoader.load(0);
    var one = numberLoader.load(1);
    var two = numberLoader.load(2);
    var batch = await Future.wait([zero, one, two]);
    print('Fetched result: $batch');
    expect(batch, ['0.00', '1.00', '2.00']);
  });

  test('dedupe', () async {
    var loader = DataLoader<int, Map<int, List<int>>>((ids) {
      return ids.map((i) => {i: ids.toList()});
    });

    var zero = loader.load(0);
    var one = loader.load(1);
    var two = loader.load(2);
    var anotherZero = loader.load(0);
    var batch = await Future.wait([zero, one, two, anotherZero]);

    expect(batch, [
      {
        0: [0, 1, 2],
      },
      {
        1: [0, 1, 2],
      },
      {
        2: [0, 1, 2],
      },
      {
        0: [0, 1, 2],
      },
    ]);
  });

  group('cache', () {
    late DataLoader<int, _Unique> uniqueLoader;
    late DataLoader<int, _Unique> noCache;

    setUp(() {
      uniqueLoader = DataLoader<int, _Unique>((ids) async {
        var numbers = await numberLoader.loadMany(ids);
        return numbers.map((s) => _Unique(s));
      });
      noCache = DataLoader(uniqueLoader.loadMany, cache: false);
    });

    tearDown(() {
      uniqueLoader.close();
      noCache.close();
    });

    test('only lookup once', () async {
      var a = await uniqueLoader.load(3);
      var b = await uniqueLoader.load(3);
      expect(a, b);
    });

    test('can be disabled', () async {
      var a = await noCache.load(3);
      var b = await noCache.load(3);
      expect(a, isNot(b));
    });

    test('clear', () async {
      var a = await uniqueLoader.load(3);
      uniqueLoader.clear(3);
      var b = await uniqueLoader.load(3);
      expect(a, isNot(b));
    });

    test('clearAll', () async {
      var a = await uniqueLoader.load(3);
      uniqueLoader.clearAll();
      var b = await uniqueLoader.load(3);
      expect(a, isNot(b));
    });

    test('prime', () async {
      uniqueLoader.prime(3, _Unique('hey'));
      var a = await uniqueLoader.load(3);
      expect(a.value, 'hey');
    });

    test('prime does nothing when the cache is disabled', () async {
      noCache.prime(3, _Unique('hey'));
      expect((await noCache.load(3)).value, '3.00');
    });
  });

  test('load during a running batch is sent in the next batch', () async {
    var batches = <List<int>>[];
    var release = Completer<void>();
    var loader = DataLoader<int, int>((ids) async {
      batches.add(ids.toList());
      if (batches.length == 1) await release.future;
      return ids;
    });

    var first = loader.load(1);
    await Future<void>.delayed(Duration.zero);
    var second = loader.load(2);
    release.complete();

    expect(await Future.wait([first, second]), [1, 2]);
    expect(batches, [
      [1],
      [2],
    ]);
  });

  test('a key loading in a running batch is not fetched again', () async {
    var calls = 0;
    var release = Completer<void>();
    var loader = DataLoader<int, int>((ids) async {
      calls++;
      await release.future;
      return ids;
    });

    var first = loader.load(1);
    await Future<void>.delayed(Duration.zero);
    var second = loader.load(1);
    release.complete();

    expect(await Future.wait([first, second]), [1, 1]);
    expect(calls, 1);
  });

  test('a failed batch rejects its loads and is not cached', () async {
    var fail = true;
    var loader = DataLoader<int, int>((ids) {
      if (fail) throw StateError('db down');
      return ids;
    });

    expect(loader.load(1), throwsStateError);
    expect(loader.load(2), throwsStateError);
    await Future<void>.delayed(Duration.zero);

    fail = false;
    expect(await loader.load(1), 1);
  });

  test('a result of the wrong length rejects the batch', () async {
    var loader = DataLoader<int, int>((ids) => ids.skip(1));
    var loads = [loader.load(1), loader.load(2)];
    for (var load in loads) {
      await expectLater(load, throwsStateError);
    }
  });

  test('a lazy result is evaluated once per key', () async {
    var evaluated = 0;
    var loader = DataLoader<int, int>(
      (ids) => ids.map((i) {
        evaluated++;
        return i;
      }),
    );
    await Future.wait([loader.load(1), loader.load(2), loader.load(3)]);
    expect(evaluated, 3);
  });

  test('close rejects pending loads and later loads', () async {
    var loader = DataLoader<int, int>((ids) => ids);
    var pending = loader.load(1);
    loader.close();
    await expectLater(pending, throwsStateError);
    expect(() => loader.load(2), throwsStateError);
  });
}

class _Unique {
  final String value;

  _Unique(this.value);
}

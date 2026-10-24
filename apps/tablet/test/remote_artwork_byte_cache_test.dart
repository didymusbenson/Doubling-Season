import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/services/remote_artwork_byte_cache.dart';

void main() {
  test(
    'validated derivative and fallback display share one request and byte reference',
    () async {
      var calls = 0;
      final cache = RemoteArtworkByteCache(
        loadBytes: (_) async {
          calls++;
          return Uint8List(1);
        },
      );
      final validated = await cache.load('crop');
      final displayed = await cache.load('crop', fallback: 'canonical');
      expect(identical(validated, displayed), isTrue);
      expect(calls, 1);
    },
  );
  test(
    'validation and repeated render requests keep future and byte identity',
    () async {
      var calls = 0;
      final bytes = Uint8List.fromList([1, 2]);
      final cache = RemoteArtworkByteCache(
        loadBytes: (_) async {
          calls++;
          return bytes;
        },
      );
      final first = cache.load('source');
      expect(identical(first, cache.load('source')), isTrue);
      expect(identical(await first, await cache.load('source')), isTrue);
      expect(calls, 1);
    },
  );
  test(
    'bounded eviction includes pending entries and reloads oldest',
    () async {
      var calls = 0;
      final cache = RemoteArtworkByteCache(
        capacity: 2,
        loadBytes: (_) async {
          calls++;
          return Uint8List(1);
        },
      );
      await cache.load('a');
      await cache.load('b');
      await cache.load('c');
      expect(cache.cachedCount, 2);
      await cache.load('a');
      expect(calls, 4);
      expect(cache.cachedCount, 2);
    },
  );
  test(
    'derived failure uses canonical already validated bytes without changing selected URL',
    () async {
      var canonicalCalls = 0;
      const selected = 'canonical';
      final bytes = Uint8List(2);
      final cache = RemoteArtworkByteCache(
        loadBytes: (url) async {
          if (url == 'crop') throw StateError('crop unavailable');
          canonicalCalls++;
          return bytes;
        },
      );
      final validated = await cache.load(selected);
      final display = cache.load('crop', fallback: selected);
      expect(
        identical(display, cache.load('crop', fallback: selected)),
        isTrue,
      );
      expect(identical(await display, validated), isTrue);
      expect(canonicalCalls, 1);
      expect(selected, 'canonical');
    },
  );
  test(
    'failed loads do not loop and retry only after cooldown or explicit retry',
    () async {
      var calls = 0;
      var time = DateTime.utc(2026);
      var fail = true;
      final cache = RemoteArtworkByteCache(
        now: () => time,
        loadBytes: (_) async {
          calls++;
          if (fail) throw StateError('offline');
          return Uint8List(1);
        },
      );
      await expectLater(cache.load('a'), throwsStateError);
      await expectLater(cache.load('a'), throwsStateError);
      expect(calls, 1);
      time = time.add(const Duration(seconds: 31));
      await expectLater(cache.load('a'), throwsStateError);
      expect(calls, 2);
      fail = false;
      await cache.load('a', retry: true);
      expect(calls, 3);
      expect(cache.failed('a'), isFalse);
    },
  );
  test(
    'manual retry invalidates failed derivative and canonical keys',
    () async {
      var fail = true;
      final cache = RemoteArtworkByteCache(
        loadBytes: (_) async {
          if (fail) throw StateError('offline');
          return Uint8List(1);
        },
      );
      await expectLater(
        cache.load('crop', fallback: 'source'),
        throwsStateError,
      );
      cache.evict('crop', fallback: 'source');
      cache.evict('source');
      fail = false;
      expect(await cache.load('crop', fallback: 'source'), hasLength(1));
    },
  );
  test('evicted in-flight failure cannot populate failure cache', () async {
    final pending = Completer<Uint8List>();
    final cache = RemoteArtworkByteCache(
      capacity: 1,
      loadBytes: (url) =>
          url == 'old' ? pending.future : Future.value(Uint8List(1)),
    );
    final old = cache.load('old');
    final assertion = expectLater(old, throwsStateError);
    await cache.load('new');
    pending.completeError(StateError('late failure'));
    await assertion;
    expect(cache.failed('old'), isFalse);
    expect(cache.cachedCount, 1);
  });
}

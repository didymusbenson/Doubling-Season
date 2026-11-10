import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripling_table/services/catalog_compatibility.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/storage/storage_namespace.dart';

import 'support/table_fixture.dart';

String payload(String name) => jsonEncode([
  {
    'name': name,
    'pt': '1/1',
    'colors': 'G',
    'abilities': 'Preserve rules text',
    'type': 'Creature',
    'artwork': [
      {
        'url': 'https://example.com/art.png',
        'set': 'TEST',
        'artist': 'Original artist',
      },
    ],
  },
]);

Map<String, dynamic> manifest(String raw, int version) => {
  'version': version,
  'sha256': sha256.convert(utf8.encode(raw)).toString(),
  'size': utf8.encode(raw).length,
  'min_app_version': '1.9.0',
};

String record(
  String raw,
  int version, [
  Map<String, dynamic> extra = const {},
]) => jsonEncode({...manifest(raw, version), 'payload': raw, ...extra});

class _Assets extends CachingAssetBundle {
  final String raw;
  final int version;
  bool fail = false;
  _Assets(this.raw, this.version);

  @override
  Future<ByteData> load(String key) async {
    if (fail) throw StateError('Bundled data unavailable');
    final data = key.endsWith('token_manifest.json')
        ? jsonEncode(manifest(raw, version))
        : raw;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(data)));
  }
}

class _Cache extends Fake implements Box<String> {
  final Map<String, String> records = {};
  int writes = 0;
  int flushes = 0;
  int? failFlush;
  int? failWrite;
  bool dropNextWrite = false;
  bool failDelete = false;

  @override
  String? get(dynamic key, {String? defaultValue}) =>
      records[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, String value) async {
    writes++;
    if (writes == failWrite) throw StateError('Write failed');
    if (dropNextWrite) {
      dropNextWrite = false;
      return;
    }
    records[key as String] = value;
  }

  @override
  Future<void> flush() async {
    flushes++;
    if (flushes == failFlush) throw StateError('Disk full');
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    if (failDelete) throw StateError('Delete failed');
    for (final key in keys) {
      records.remove(key);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture fixture;
  late _Assets assets;
  late _Cache cache;
  late TabletCatalog catalog;
  late MockClient client;
  late Future<http.Response> Function(http.Request) request;
  late int requests;
  final bundled = payload('Bundled');
  final downloaded = payload('Downloaded');

  setUp(() async {
    fixture = TableFixture();
    await fixture.initialize();
    assets = _Assets(bundled, 13);
    cache = _Cache();
    requests = 0;
    request = (_) async => http.Response.bytes(utf8.encode(downloaded), 200);
    client = MockClient((r) {
      requests++;
      return request(r);
    });
    catalog = TabletCatalog.forTesting(
      fixture.controller,
      client: client,
      assets: assets,
      openCache: () async => cache,
    );
  });
  tearDown(() {
    catalog.dispose();
    client.close();
    fixture.dispose();
  });

  test(
    'legacy manifest compatibility is independent of Table display version',
    () {
      final old = CatalogUpdate.fromManifest(manifest(downloaded, 14));
      expect(old.schemaVersion, 1);
      expect(old.minimumReaderVersion, 1);
      expect(old.minimumVersion, '1.9.0');
      expect(CatalogCompatibility.legacyAppCompatibility, '1.11.0');
      CatalogUpdate.fromManifest({
        ...manifest(downloaded, 14),
        'schema_version': 1,
        'min_catalog_reader_version': 1,
        'min_app_version': '1.11.0',
      });
    },
  );

  final invalid = <String, Object?>{
    'version': 14.5,
    'size': -1,
    'sha256': 'bad',
    'schema_version': 2,
    'min_catalog_reader_version': 2,
    'min_app_version': '1.12.0',
  };
  for (final item in invalid.entries) {
    test(
      'reject ${item.key} before downloading or replacing a good cache',
      () async {
        await catalog.load();
        final before = fixture.repository.encoded;
        cache.records['override'] = record(downloaded, 14);
        final saved = Map.of(cache.records);
        request = (_) async => http.Response(
          jsonEncode({...manifest(downloaded, 15), item.key: item.value}),
          200,
        );
        final result = await catalog.checkForUpdate();
        expect(result.error, isNotNull);
        await expectLater(catalog.applyUpdate(result), throwsStateError);
        expect(requests, 1);
        expect(cache.records, saved);
        expect(fixture.repository.encoded, before);
      },
    );
  }

  for (final value in [
    'garbage',
    '1.11',
    '1.11.0-beta',
    '1.11.0+2',
    '01.9.0',
    '1.11.0.1',
  ]) {
    test('malformed legacy floor is not normalized: $value', () {
      expect(
        () => CatalogUpdate.fromManifest({
          ...manifest(downloaded, 14),
          'min_app_version': value,
        }),
        throwsFormatException,
      );
    });
  }
  for (final key in [
    'version',
    'schema_version',
    'min_catalog_reader_version',
  ]) {
    for (final value in [null, 0, -1, '1', 1.0]) {
      test('strict integer $key refuses $value (${value.runtimeType})', () {
        expect(
          () => CatalogUpdate.fromManifest({
            ...manifest(downloaded, 14),
            key: value,
          }),
          throwsA(anything),
        );
      });
    }
  }

  test('bundled catalog is validated without a network connection', () async {
    await catalog.load();
    expect(catalog.loaded, isTrue);
    expect(catalog.version, 13);
    expect(catalog.tokens.single.name, 'Bundled');
    expect(catalog.tokens.single.artwork.single.artist, 'Original artist');
    expect(requests, 0);
  });

  test('legacy metadata-free cache loads without rewriting it', () async {
    cache.records['override'] = jsonEncode({
      'version': 14,
      'sha256': manifest(downloaded, 14)['sha256'],
      'payload': downloaded,
    });
    final before = Map.of(cache.records);
    await catalog.load();
    expect(catalog.version, 14);
    expect(catalog.tokens.single.name, 'Downloaded');
    expect(cache.records, before);
    expect(cache.writes, 0);
  });

  test('stale cache never shadows a newer bundled catalog', () async {
    cache.records['override'] = record(downloaded, 12);
    await catalog.load();
    expect(catalog.version, 13);
    expect(cache.records, contains('override'));
  });

  for (final extra in [
    {'schema_version': 2},
    {'min_catalog_reader_version': 2},
    {'record_version': 2},
    {'record_version': 1.0},
    {'min_app_version': '2.0.0'},
    {'sha256': '0' * 64},
  ]) {
    test(
      'unsupported cache $extra is retained and refuses overwrite',
      () async {
        cache.records['override'] = record(downloaded, 99, extra);
        cache.records['previous'] = record(downloaded, 14);
        final before = Map.of(cache.records);
        await catalog.load();
        expect(catalog.version, 14);
        expect(catalog.error, contains('retained'));
        await expectLater(
          catalog.applyUpdate(
            CatalogUpdate.fromManifest(manifest(downloaded, 100)),
          ),
          throwsA(anything),
        );
        expect(requests, 0);
        expect(cache.records, before);
        expect(cache.writes, 0);
      },
    );
  }

  test('cache still works offline if bundled asset loading fails', () async {
    assets.fail = true;
    cache.records['override'] = record(downloaded, 14);
    await catalog.load();
    expect(catalog.loaded, isTrue);
    expect(catalog.version, 14);
    expect(catalog.error, contains('Bundled catalog unavailable'));
  });

  test('offline manifest failure preserves game and active catalog', () async {
    await catalog.load();
    final game = fixture.repository.encoded;
    request = (_) async => throw const SocketException('offline');
    expect((await catalog.checkForUpdate()).error, contains('offline'));
    expect(catalog.version, 13);
    expect(fixture.repository.encoded, game);
    expect(cache.writes, 0);
  });

  test(
    'apply retains prior catalog and stores the complete compatibility contract',
    () async {
      cache.records['override'] = record(bundled, 13);
      final prior = cache.records['override'];
      await catalog.load();
      final game = fixture.repository.encoded;
      final update = CatalogUpdate.fromManifest({
        ...manifest(downloaded, 14),
        'schema_version': 1,
        'min_catalog_reader_version': 1,
      });
      await catalog.applyUpdate(update);
      expect(catalog.version, 14);
      expect(cache.records['previous'], prior);
      final stored = jsonDecode(cache.records['override']!) as Map;
      expect(stored['min_app_version'], '1.9.0');
      expect(stored['schema_version'], 1);
      expect(stored['min_catalog_reader_version'], 1);
      expect(stored['record_version'], 1);
      expect(fixture.repository.encoded, game);
      expect(cache.flushes, 2);
    },
  );

  for (final body in [
    '[]',
    '{"unexpected":"envelope"}',
    '[{"name":""}]',
    '[{"name":42}]',
  ]) {
    test('invalid verified payload is refused: $body', () async {
      await catalog.load();
      request = (_) async => http.Response.bytes(utf8.encode(body), 200);
      await expectLater(
        catalog.applyUpdate(CatalogUpdate.fromManifest(manifest(body, 14))),
        throwsA(anything),
      );
      expect(catalog.version, 13);
      expect(cache.writes, 0);
    });
  }

  test(
    'hash, length, malformed UTF-8 and oversized declarations fail safely',
    () async {
      await catalog.load();
      final update = CatalogUpdate.fromManifest(manifest(downloaded, 14));
      for (final bytes in [
        utf8.encode('changed'),
        [0xff, 0xfe],
      ]) {
        request = (_) async => http.Response.bytes(bytes, 200);
        await expectLater(catalog.applyUpdate(update), throwsFormatException);
      }
      expect(
        () => CatalogUpdate.fromManifest({
          ...manifest(downloaded, 14),
          'size': CatalogCompatibility.maximumPayloadBytes + 1,
        }),
        throwsFormatException,
      );
      expect(catalog.version, 13);
      expect(cache.writes, 0);
    },
  );

  test('stale and repeated applications do not download or write', () async {
    await catalog.load();
    await catalog.applyUpdate(
      CatalogUpdate.fromManifest(manifest(downloaded, 13)),
    );
    final update = CatalogUpdate.fromManifest(manifest(downloaded, 14));
    await catalog.applyUpdate(update);
    await catalog.applyUpdate(update);
    expect(requests, 1);
    expect(cache.writes, 1);
  });

  test(
    'concurrent updates cannot promote an older delayed generation',
    () async {
      await catalog.load();
      final gate = Completer<http.Response>();
      request = (_) => gate.future;
      final newer = catalog.applyUpdate(
        CatalogUpdate.fromManifest(manifest(downloaded, 15)),
      );
      final older = catalog.applyUpdate(
        CatalogUpdate.fromManifest(manifest(downloaded, 14)),
      );
      gate.complete(http.Response.bytes(utf8.encode(downloaded), 200));
      await Future.wait([newer, older]);
      expect(catalog.version, 15);
      expect(requests, 1);
      expect(jsonDecode(cache.records['override']!)['version'], 15);
    },
  );

  for (final failurePoint in [1, 2]) {
    test(
      'flush failure $failurePoint never reports activation; retry recovers',
      () async {
        cache.records['override'] = record(bundled, 13);
        await catalog.load();
        final prior = cache.records['override'];
        cache.failFlush = failurePoint;
        final update = CatalogUpdate.fromManifest(manifest(downloaded, 14));
        await expectLater(catalog.applyUpdate(update), throwsStateError);
        expect(catalog.version, 13);
        expect(cache.records['previous'], prior);
        cache.failFlush = null;
        await catalog.applyUpdate(update);
        expect(catalog.version, 14);
      },
    );
  }

  test('failed readback cannot report successful activation', () async {
    await catalog.load();
    cache.dropNextWrite = true;
    await expectLater(
      catalog.applyUpdate(CatalogUpdate.fromManifest(manifest(downloaded, 14))),
      throwsStateError,
    );
    expect(catalog.version, 13);
  });

  test(
    'explicit revert waits for update and cannot reactivate previous on reload',
    () async {
      cache.records['override'] = record(bundled, 13);
      await catalog.load();
      final applying = catalog.applyUpdate(
        CatalogUpdate.fromManifest(manifest(downloaded, 14)),
      );
      final reverting = catalog.revertToBundled();
      await Future.wait([applying, reverting]);
      expect(catalog.version, 13);
      expect(catalog.tokens.single.name, 'Bundled');
      expect(cache.records, isEmpty);
      await catalog.load();
      expect(catalog.version, 13);
    },
  );

  test(
    'failed bundled validation preserves both generations on revert',
    () async {
      cache.records['override'] = record(downloaded, 14);
      cache.records['previous'] = record(bundled, 13);
      await catalog.load();
      final before = Map.of(cache.records);
      assets.clear();
      assets.fail = true;
      await expectLater(catalog.revertToBundled(), throwsStateError);
      expect(catalog.version, 14);
      expect(cache.records, before);
    },
  );

  test(
    'load queued behind apply sees only the acknowledged generation',
    () async {
      await catalog.load();
      final gate = Completer<http.Response>();
      request = (_) => gate.future;
      final applying = catalog.applyUpdate(
        CatalogUpdate.fromManifest(manifest(downloaded, 14)),
      );
      final loading = catalog.load();
      gate.complete(http.Response.bytes(utf8.encode(downloaded), 200));
      await Future.wait([applying, loading]);
      expect(catalog.version, 14);
    },
  );

  test(
    'unknown retained generation alone blocks writes without erasure',
    () async {
      cache.records['previous'] = record(downloaded, 99, {'schema_version': 2});
      final before = Map.of(cache.records);
      await catalog.load();
      expect(catalog.version, 13);
      await expectLater(
        catalog.applyUpdate(
          CatalogUpdate.fromManifest(manifest(downloaded, 14)),
        ),
        throwsFormatException,
      );
      expect(cache.records, before);
      expect(requests, 0);
    },
  );

  for (final failurePoint in [1, 2]) {
    test(
      'put failure $failurePoint preserves active state and does not poison queue',
      () async {
        cache.records['override'] = record(bundled, 13);
        await catalog.load();
        final prior = cache.records['override'];
        cache.failWrite = failurePoint;
        final update = CatalogUpdate.fromManifest(manifest(downloaded, 14));
        await expectLater(catalog.applyUpdate(update), throwsStateError);
        expect(catalog.version, 13);
        expect(cache.records['override'], prior);
        cache.failWrite = null;
        await catalog.applyUpdate(update);
        expect(catalog.version, 14);
      },
    );
  }

  test(
    'oversized actual response with absent size is refused before caching',
    () async {
      await catalog.load();
      final oversized = ' ' * (CatalogCompatibility.maximumPayloadBytes + 1);
      request = (_) async => http.Response.bytes(utf8.encode(oversized), 200);
      await expectLater(
        catalog.applyUpdate(
          CatalogUpdate.fromManifest({
            ...manifest(oversized, 14),
            'size': null,
          }),
        ),
        throwsFormatException,
      );
      expect(catalog.version, 13);
      expect(cache.writes, 0);
    },
  );

  for (final failDelete in [true, false]) {
    test(
      'revert ${failDelete ? 'delete' : 'flush'} failure does not report activation',
      () async {
        cache.records['override'] = record(downloaded, 14);
        cache.records['previous'] = record(bundled, 13);
        await catalog.load();
        final before = Map.of(cache.records);
        cache.failDelete = failDelete;
        if (!failDelete) cache.failFlush = 1;
        await expectLater(catalog.revertToBundled(), throwsStateError);
        expect(catalog.version, 14);
        if (failDelete) expect(cache.records, before);
        cache.failDelete = false;
        cache.failFlush = null;
        await catalog.revertToBundled();
        expect(catalog.version, 13);
        expect(cache.records, isEmpty);
      },
    );
  }

  test(
    'real Hive close/reopen retains metadata and preview isolates production',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'catalog-contract-',
      );
      Hive.init(directory.path);
      TabletCatalog? first;
      TabletCatalog? second;
      try {
        if (tableStorageNamespace.isNotEmpty) {
          final production = await Hive.openBox<String>(
            'tripling_season_tablet_catalog_v1',
          );
          await production.put('sentinel', 'untouched');
          await production.flush();
        }
        Future<Box<String>> open() =>
            Hive.openBox<String>(TableStorageKeys.catalog);
        first = TabletCatalog.forTesting(
          fixture.controller,
          client: client,
          assets: assets,
          openCache: open,
        );
        await first.load();
        await first.applyUpdate(
          CatalogUpdate.fromManifest(manifest(downloaded, 14)),
        );
        await Hive.close();
        second = TabletCatalog.forTesting(
          fixture.controller,
          client: client,
          assets: assets,
          openCache: open,
        );
        await second.load();
        expect(second.version, 14);
        expect(second.tokens.single.artwork.single.artist, 'Original artist');
        expect(
          (await open()).get('override'),
          contains('min_catalog_reader_version'),
        );
        if (tableStorageNamespace.isNotEmpty) {
          final production = await Hive.openBox<String>(
            'tripling_season_tablet_catalog_v1',
          );
          expect(production.toMap(), {'sentinel': 'untouched'});
        }
      } finally {
        first?.dispose();
        second?.dispose();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

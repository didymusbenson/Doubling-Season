import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/services/tablet_media_store.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/storage/storage_namespace.dart';

import 'support/table_fixture.dart';

// PNG fixture with distinct trailing fixture labels. Image rendering is not the
// contract under test: this suite checks exact portable bytes and references.
Uint8List _image(String label) => Uint8List.fromList([
  ...base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jH1sAAAAASUVORK5CYII=',
  ),
  ...utf8.encode(label),
]);
String _reference(List<int> bytes) => 'tablet-art:${sha256.convert(bytes)}';

Map<String, dynamic> _document(Map<String, Uint8List> images) {
  final refs = images.keys.toList();
  final art = refs.first;
  return {
    'schemaVersion': 4,
    'product': 'tripling-table',
    'preset': {
      'id': 'external-source-id',
      'name': 'Portable artwork',
      'imageUrl': refs.length > 1 ? refs[1] : art,
      'tokens': [
        {
          'name': 'Saproling',
          'pt': '1/1',
          'abilities': '',
          'colors': 'G',
          'type': 'Creature — Saproling',
          'artworkUrl': art,
          'artworkSet': 'UPLOAD',
          'artworkDisplayStyle': 'fadeout',
          'artworkOptions': [
            for (final ref in refs)
              {'url': ref, 'set': 'UPLOAD', 'artist': 'user uploaded'},
          ],
        },
      ],
      'utilities': [
        {
          'kind': 'custom_toggle',
          'name': 'Retained custom toggle',
          'description': 'On description',
          'colors': 'U',
          'defaultValue': 0,
          'visible': false,
          'artworkUrl': art,
          'configuration': {
            'type': 'toggle',
            'isCustom': true,
            'offDescription': 'Off description',
            'onArtworkUrl': refs.length > 2 ? refs[2] : art,
            'offArtworkUrl': refs.length > 3 ? refs[3] : art,
            'artworkOptions': [
              {'url': art, 'set': 'UPLOAD', 'artist': 'user uploaded'},
            ],
          },
        },
      ],
    },
    'assets': {
      for (final entry in images.entries) entry.key: base64Encode(entry.value),
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<dynamic> media;
  late TableFixture fixture;
  late PresetService presets;
  final persisted = <String, Uint8List>{};
  final corruptEvidence = <String, dynamic>{};

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('preset-media-');
    Hive.init(directory.path);
    media = await Hive.openBox<dynamic>(TableStorageKeys.media);
  });
  setUp(() async {
    fixture = TableFixture(stateWithTokens([sampleToken()]));
    await fixture.initialize();
    fixture.catalog.loaded = true;
    presets = PresetService(fixture.controller, fixture.catalog);
  });
  tearDown(() => fixture.dispose());
  tearDownAll(() async {
    // Read flushed bytes after closing Hive, independently of the production
    // TabletMediaStore cache. No production media call follows this reopen.
    await Hive.close();
    Hive.init(directory.path);
    final reopened = await Hive.openBox<dynamic>(TableStorageKeys.media);
    for (final entry in persisted.entries) {
      expect(reopened.get(entry.key.substring(11)), orderedEquals(entry.value));
    }
    for (final entry in corruptEvidence.entries) {
      expect(reopened.containsKey(entry.key.substring(11)), isTrue);
      expect(reopened.get(entry.key.substring(11)), entry.value);
    }
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Map<String, Uint8List> images(String prefix, {int count = 4}) => {
    for (var i = 0; i < count; i++)
      _reference(_image('$prefix-$i')): _image('$prefix-$i'),
  };

  Future<void> rejectedWithoutMutation(Map<String, dynamic> document) async {
    final before = cloneJson(fixture.controller.state.toJson());
    final durableBefore = fixture.repository.encoded;
    final mediaKeys = media.keys.toSet();
    final encoded = jsonEncode(document);
    await expectLater(presets.importJson(encoded), throwsFormatException);
    expect(fixture.controller.state.toJson(), before);
    expect(fixture.repository.encoded, durableBefore);
    expect(media.keys.toSet(), mediaKeys);
    expect(jsonEncode(document), encoded);
  }

  test(
    'v4 imports new portable bytes, preserves metadata and exports exactly',
    () async {
      final assets = images('roundtrip');
      final input = _document(assets);
      final encoded = jsonEncode(input);
      final source = cloneJson(input['preset'] as Map<String, dynamic>);
      final boardBefore = cloneJson(fixture.controller.session.toJson());
      for (final reference in assets.keys) {
        expect(media.containsKey(reference.substring(11)), isFalse);
        expect(TabletMediaStore.peek(reference), isNull);
      }
      final imported = await presets.importJson(encoded);
      expect(imported['id'], isNot(source['id']));
      expect(imported['tokens'], source['tokens']);
      expect(imported['utilities'], source['utilities']);
      expect(imported['imageUrl'], source['imageUrl']);
      expect(fixture.controller.session.toJson(), boardBefore);
      expect(jsonEncode(input), encoded);
      for (final entry in assets.entries) {
        expect(media.get(entry.key.substring(11)), orderedEquals(entry.value));
        expect(
          await TabletMediaStore.read(entry.key),
          orderedEquals(entry.value),
        );
      }
      persisted.addAll(assets);
      final savedBefore = cloneJson(imported);
      final exported = jsonMap(
        jsonDecode(await presets.exportJson(imported['id'] as String)),
      );
      expect(exported['assets'], input['assets']);
      expect(exported['preset'], savedBefore);
      expect(imported, savedBefore);

      final reopened = TableController(repository: fixture.repository);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.state.decks.single, savedBefore);
      expect(reopened.session.toJson(), boardBefore);
      await presets.load(fixture.playerId, imported['id'] as String);
      expect(
        fixture.player.tokens.single.artworkOptions.first['artist'],
        'user uploaded',
      );
      expect(
        fixture.player.tokens.single.extra['artworkDisplayStyle'],
        'fadeout',
      );
      expect(fixture.player.tokens.single.amount, 0);
      expect(
        fixture.player.utilities.single.configuration,
        (source['utilities'] as List).single['configuration'],
      );
      expect(fixture.player.utilities.single.visible, isFalse);
    },
  );

  test('corrupt existing hash refuses import and preserves evidence', () async {
    final assets = images('corrupt-existing', count: 1);
    final reference = assets.keys.single;
    final corrupt = Uint8List.fromList([91, 92, 93]);
    corruptEvidence[reference] = Uint8List.fromList(corrupt);
    await media.put(reference.substring(11), corrupt);
    await media.flush();
    final before = cloneJson(fixture.controller.state.toJson());
    final durableBefore = fixture.repository.encoded;
    await expectLater(
      presets.importJson(jsonEncode(_document(assets))),
      throwsStateError,
    );
    expect(media.get(reference.substring(11)), orderedEquals(corrupt));
    expect(fixture.controller.state.toJson(), before);
    expect(fixture.repository.encoded, durableBefore);
    expect(TabletMediaStore.peek(reference), isNull);
    expect(await TabletMediaStore.read(reference), isNull);
  });

  test('warm cache cannot hide corrupted stored bytes during export', () async {
    final assets = images('corrupt-after-cache', count: 1);
    final imported = await presets.importJson(jsonEncode(_document(assets)));
    final reference = assets.keys.single;
    expect(
      TabletMediaStore.peek(reference),
      orderedEquals(assets.values.single),
    );
    final corrupt = Uint8List.fromList([18, 19, 20]);
    corruptEvidence[reference] = Uint8List.fromList(corrupt);
    await media.put(reference.substring(11), corrupt);
    await media.flush();
    final before = cloneJson(fixture.controller.state.toJson());
    // The presentation cache stays fast and stable; verified reads are the
    // explicit persistence boundary and invalidate that cache on corruption.
    expect(
      identical(
        await TabletMediaStore.read(reference),
        TabletMediaStore.peek(reference),
      ),
      isTrue,
    );
    await expectLater(
      presets.exportJson(imported['id'] as String),
      throwsStateError,
    );
    expect(media.get(reference.substring(11)), orderedEquals(corrupt));
    expect(fixture.controller.state.toJson(), before);
    expect(TabletMediaStore.peek(reference), isNull);
    expect(await TabletMediaStore.read(reference, verifyStored: true), isNull);
  });

  test(
    'legacy byte lists verify and malformed stored values remain untouched',
    () async {
      final bytes = _image('legacy-byte-list');
      final reference = _reference(bytes);
      await media.put(reference.substring(11), bytes.toList());
      expect(await TabletMediaStore.read(reference), orderedEquals(bytes));
      expect(await TabletMediaStore.save(bytes), reference);
      persisted[reference] = bytes;
      final invalid = <dynamic>[
        null,
        'not image bytes',
        [1, 256],
        [1, 'two'],
      ];
      for (var i = 0; i < invalid.length; i++) {
        final incoming = _image('invalid-stored-$i');
        final ref = _reference(incoming);
        await media.put(ref.substring(11), invalid[i]);
        corruptEvidence[ref] = invalid[i];
        expect(await TabletMediaStore.read(ref), isNull);
        await expectLater(TabletMediaStore.save(incoming), throwsStateError);
        expect(media.get(ref.substring(11)), invalid[i]);
        expect(media.containsKey(ref.substring(11)), isTrue);
      }
      await media.flush();
    },
  );

  test(
    'valid existing hash reuses exact bytes without duplicate media',
    () async {
      final assets = images('valid-existing', count: 1);
      final reference = assets.keys.single;
      await media.put(reference.substring(11), assets.values.single);
      await media.flush();
      final keys = media.keys.toSet();
      final imported = await presets.importJson(jsonEncode(_document(assets)));
      expect(media.keys.toSet(), keys);
      expect(
        media.get(reference.substring(11)),
        orderedEquals(assets.values.single),
      );
      expect(
        await TabletMediaStore.read(reference),
        orderedEquals(assets.values.single),
      );
      expect(
        (jsonDecode(await presets.exportJson(imported['id'] as String))
            as Map)['assets'],
        _document(assets)['assets'],
      );
      persisted.addAll(assets);
    },
  );

  test(
    'callers cannot mutate content-addressed media through owned buffers',
    () async {
      final bytes = _image('defensive-copy');
      final expected = Uint8List.fromList(bytes);
      final pending = TabletMediaStore.save(bytes);
      bytes[0] = 0;
      final reference = await pending;
      expect(reference, _reference(expected));
      final read = (await TabletMediaStore.read(reference))!;
      expect(() => read[0] = 0, throwsUnsupportedError);
      final peek = TabletMediaStore.peek(reference)!;
      expect(() => peek[0] = 0, throwsUnsupportedError);
      expect(await TabletMediaStore.read(reference), orderedEquals(expected));
      expect(TabletMediaStore.peek(reference), orderedEquals(expected));
      expect(identical(await TabletMediaStore.read(reference), peek), isTrue);
      expect(media.get(reference.substring(11)), orderedEquals(expected));
      persisted[reference] = expected;
    },
  );

  test(
    'missing later asset refuses before even the first media write',
    () async {
      final input = _document(images('missing'));
      (input['assets'] as Map).remove((input['assets'] as Map).keys.last);
      await rejectedWithoutMutation(input);
    },
  );

  test('wrong digest refuses all media and library mutations', () async {
    final input = _document(images('wrong-hash'));
    final assets = input['assets'] as Map;
    assets[assets.keys.last] = base64Encode(_image('different bytes'));
    await rejectedWithoutMutation(input);
  });

  test('malformed base64 refuses all media and library mutations', () async {
    final input = _document(images('malformed-base64'));
    final assets = input['assets'] as Map;
    assets[assets.keys.last] = '**not-base64**';
    await rejectedWithoutMutation(input);
  });

  test(
    'aggregate artwork above 64 MiB refuses before media writes',
    () async {
      final bytes = Uint8List(11 * 1024 * 1024);
      final encodedAssets = <String, String>{};
      for (var i = 0; i < 6; i++) {
        bytes[0] = i;
        encodedAssets[_reference(bytes)] = base64Encode(bytes);
      }
      final input = _document(images('total-limit', count: 1));
      final token = ((input['preset'] as Map)['tokens'] as List).single as Map;
      token['artworkUrl'] = encodedAssets.keys.first;
      token['artworkOptions'] = [
        for (final ref in encodedAssets.keys) {'url': ref, 'set': 'UPLOAD'},
      ];
      (input['preset'] as Map)['imageUrl'] = encodedAssets.keys.first;
      (input['preset'] as Map)['utilities'] = [];
      input['assets'] = encodedAssets;
      await rejectedWithoutMutation(input);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'individual image above 12 MiB cannot add a preset or alter board',
    () async {
      final bytes = Uint8List(12 * 1024 * 1024 + 1);
      final input = _document({_reference(bytes): bytes});
      await rejectedWithoutMutation(input);
    },
  );

  for (final length in [0, 12 * 1024 * 1024 + 1]) {
    test(
      'invalid later asset of $length bytes refuses before first media write',
      () async {
        final assets = images('preflight-$length');
        final invalid = Uint8List(length);
        assets[_reference(invalid)] = invalid;
        await rejectedWithoutMutation(_document(assets));
      },
    );
  }

  test(
    'failed library save retains only immutable media and retry is safe',
    () async {
      final assets = images('failed-library');
      final input = jsonEncode(_document(assets));
      final before = cloneJson(fixture.controller.state.toJson());
      final encodedBefore = fixture.repository.encoded;
      fixture.repository.failSave = true;
      await expectLater(presets.importJson(input), throwsStateError);
      expect(fixture.controller.state.toJson(), before);
      expect(fixture.repository.encoded, encodedBefore);
      for (final entry in assets.entries) {
        expect(media.get(entry.key.substring(11)), orderedEquals(entry.value));
      }
      persisted.addAll(assets);
      final keys = media.keys.toSet();
      fixture.repository.failSave = false;
      final imported = await presets.importJson(input);
      expect(fixture.controller.state.decks, hasLength(1));
      expect(fixture.controller.state.decks.single['id'], imported['id']);
      expect(fixture.controller.session.toJson(), before['session']);
      expect(media.keys.toSet(), keys);
    },
  );

  test(
    'unavailable portable artwork fails export without changing source',
    () async {
      final absent = _reference(_image('absent-export'));
      final imported = await presets.importJson(
        jsonEncode({
          'schemaVersion': 3,
          'deck': {
            'name': 'Missing asset',
            'templates': [
              {'name': 'Saproling', 'artworkUrl': absent},
            ],
          },
        }),
      );
      final before = cloneJson(fixture.controller.state.toJson());
      await expectLater(
        presets.exportJson(imported['id'] as String),
        throwsStateError,
      );
      expect(fixture.controller.state.toJson(), before);
    },
  );
}

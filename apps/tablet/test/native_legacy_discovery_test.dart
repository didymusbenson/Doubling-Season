import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/native_legacy_discovery.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory support;
  late Directory preferences;

  Future<void> setup(LegacyNativePlatform platform) async {
    final android = platform == LegacyNativePlatform.android;
    documents = await Directory(
      '${root.path}/${android ? 'app_flutter' : 'Documents'}',
    ).create();
    support = await Directory(
      '${root.path}/${android ? 'files' : 'Library/Application Support'}',
    ).create(recursive: true);
    preferences = Directory(
      '${root.path}/${android ? 'shared_prefs' : 'Library/Preferences'}',
    );
  }

  Future<void> file(String path, [List<int> bytes = const [0, 1, 2]]) async {
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<void> complete(LegacyNativePlatform platform) async {
    // Empty Hive files are real valid empty-box encodings. Discovery is not an
    // adapter decode; nonempty shipped serialization lives in reader fixtures.
    for (final name in NativeLegacyDiscovery.primaryBoxes) {
      await file('${documents.path}/$name.hive', []);
      await file('${documents.path}/$name.lock', []);
    }
    final android = platform == LegacyNativePlatform.android;
    await file(
      '${preferences.path}/${android ? 'FlutterSharedPreferences.xml' : 'LooseTie.Doubling-Season.plist'}',
      (android
              ? '<map><boolean name="flutter.summoningSicknessEnabled" value="true"/></map>'
              : '<?xml version="1.0"?><plist version="1.0"><dict><key>flutter.summoningSicknessEnabled</key><true/></dict></plist>')
          .codeUnits,
    );
  }

  Future<NativeLegacyInventory> inspect(LegacyNativePlatform platform) =>
      NativeLegacyDiscovery.inspectResolvedRoots(
        platform: platform,
        documents: documents,
        support: support,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('native-legacy-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  for (final platform in LegacyNativePlatform.values) {
    group(platform.name, () {
      test('absence is observation only; discovery creates no files', () async {
        await setup(platform);
        final before = await root
            .list(recursive: true)
            .map((e) => e.path)
            .toList();
        final result = await inspect(platform);
        expect(result.presence, NativeLegacyPresence.noEvidence);
        expect(result.fileHashes, isEmpty);
        expect(
          await root.list(recursive: true).map((e) => e.path).toList(),
          before,
        );
        expect(() => result.fileHashes['bad'] = 'bad', throwsUnsupportedError);
      });
      test(
        'complete layout includes both art roots, backups and order journal without writes',
        () async {
          await setup(platform);
          await complete(platform);
          await file('${documents.path}/custom_artwork/user image.png');
          await file('${support.path}/artwork_cache/cover.jpg');
          await file('${documents.path}/hive_backups/items.hive');
          await file('${documents.path}/boardorderoperations.hive', []);
          await file('${documents.path}/token_db/database.json');
          final result = await inspect(platform);
          expect(result.presence, NativeLegacyPresence.candidate);
          expect(
            result.fileHashes['documents/custom_artwork/user image.png'],
            sha256.convert([0, 1, 2]).toString(),
          );
          expect(result.fileHashes, contains('artwork_cache/cover.jpg'));
          expect(
            result.fileHashes,
            contains('documents/hive_backups/items.hive'),
          );
          expect(
            result.fileHashes,
            contains('documents/boardorderoperations.hive'),
          );
          expect(
            result.fileHashes,
            contains('documents/token_db/database.json'),
          );
          expect((await inspect(platform)).fileHashes, result.fileHashes);
          expect(
            await File(
              '${documents.path}/custom_artwork/user image.png',
            ).readAsBytes(),
            [0, 1, 2],
          );
        },
      );
      test(
        'backup-only, artwork-only and empty artwork directory cannot mean fresh',
        () async {
          await setup(platform);
          await Directory('${support.path}/artwork_cache').create();
          expect(
            (await inspect(platform)).presence,
            NativeLegacyPresence.blocked,
          );
          await file('${documents.path}/hive_backups/items.hive');
          expect(
            (await inspect(platform)).presence,
            NativeLegacyPresence.blocked,
          );
          await file('${documents.path}/custom_artwork/orphan.png');
          expect(
            (await inspect(platform)).presence,
            NativeLegacyPresence.blocked,
          );
        },
      );
      test(
        'missing primary, missing preferences, compaction and unknown stores block',
        () async {
          await setup(platform);
          await complete(platform);
          await File('${documents.path}/decks.hive').delete();
          expect(
            (await inspect(platform)).blockers,
            contains('Missing primary box: decks'),
          );
          await file('${documents.path}/decks.hive', []);
          await preferences.delete(recursive: true);
          expect(
            (await inspect(platform)).blockers,
            contains('Missing raw preference domain'),
          );
          await complete(platform);
          await file('${documents.path}/decks.hivec');
          await file('${documents.path}/unknown.hive');
          final result = await inspect(platform);
          expect(result.presence, NativeLegacyPresence.blocked);
          expect(result.blockers.any((b) => b.contains('compaction')), isTrue);
          expect(
            result.blockers.any((b) => b.contains('Unknown Hive')),
            isTrue,
          );
        },
      );
      test(
        'preference recovery sidecars block and unrelated domains are not read',
        () async {
          await setup(platform);
          await complete(platform);
          await file('${preferences.path}/unrelated.xml');
          final name = platform == LegacyNativePlatform.android
              ? 'FlutterSharedPreferences.xml'
              : 'LooseTie.Doubling-Season.plist';
          await file('${preferences.path}/$name.bak');
          final result = await inspect(platform);
          expect(result.presence, NativeLegacyPresence.blocked);
          expect(
            result.fileHashes,
            isNot(contains('preferences/unrelated.xml')),
          );
          expect(result.fileHashes, contains('preferences/$name.bak'));
        },
      );
      test(
        'corrupt bytes are evidence, never fresh or a decoded migration',
        () async {
          await setup(platform);
          await file('${documents.path}/items.hive', [255, 0, 99]);
          final result = await inspect(platform);
          expect(result.presence, NativeLegacyPresence.blocked);
          expect(
            result.fileHashes['documents/items.hive'],
            sha256.convert([255, 0, 99]).toString(),
          );
        },
      );
      test(
        'links in documents or preferences fail rather than follow',
        () async {
          await setup(platform);
          await Link('${documents.path}/outside').create(root.parent.path);
          await expectLater(inspect(platform), throwsFormatException);
          await Link('${documents.path}/outside').delete();
          await Link(preferences.path).create(root.path);
          await expectLater(inspect(platform), throwsFormatException);
        },
      );
      test(
        'wrong types at artwork and preference sidecars fail closed',
        () async {
          await setup(platform);
          await complete(platform);
          await file('${support.path}/artwork_cache');
          await expectLater(inspect(platform), throwsFormatException);
          await File('${support.path}/artwork_cache').delete();
          final name = platform == LegacyNativePlatform.android
              ? 'FlutterSharedPreferences.xml'
              : 'LooseTie.Doubling-Season.plist';
          await Directory('${preferences.path}/$name.bak').create();
          await expectLater(inspect(platform), throwsFormatException);
        },
      );
      test('missing and mismatched native roots fail closed', () async {
        await setup(platform);
        await expectLater(
          NativeLegacyDiscovery.inspectResolvedRoots(
            platform: platform,
            documents: support,
            support: documents,
          ),
          throwsFormatException,
        );
        await documents.delete();
        await expectLater(inspect(platform), throwsFormatException);
      });
    });
  }
  test('oversized file fails before reading it', () async {
    await setup(LegacyNativePlatform.android);
    final handle = await File(
      '${documents.path}/large.hive',
    ).open(mode: FileMode.write);
    await handle.truncate(NativeLegacyDiscovery.maxFileBytes + 1);
    await handle.close();
    await expectLater(
      inspect(LegacyNativePlatform.android),
      throwsFormatException,
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doubling_season/models/deck.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/rule_outcome.dart';
import 'package:doubling_season/models/rule_trigger.dart';
import 'package:doubling_season/models/token_artwork_preference.dart';
import 'package:doubling_season/models/token_counter.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/models/token_rule.dart';
import 'package:doubling_season/models/token_template.dart';
import 'package:doubling_season/models/toggle_widget.dart';
import 'package:doubling_season/models/toggle_widget_template.dart';
import 'package:doubling_season/models/tracker_widget.dart';
import 'package:doubling_season/models/tracker_widget_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/binary_writer_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/frame.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';

final _date = DateTime.utc(2026, 11, 10);
const _art = 'file:///original/upload.png';

class _Memory extends LegacyMigrationStorage {
  final values = <String, String>{};
  int writes = 0;
  bool failFlush = false;
  bool loseWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (!loseWrites) values[key] = value;
  }

  @override
  Future<void> flush() async {
    if (failFlush) throw const FileSystemException('Injected full disk');
  }
}

HiveImpl _registry() {
  final hive = HiveImpl();
  hive.registerAdapter<Item>(ItemAdapter());
  hive.registerAdapter<TokenCounter>(TokenCounterAdapter());
  hive.registerAdapter<Deck>(DeckAdapter());
  hive.registerAdapter<TokenTemplate>(TokenTemplateAdapter());
  hive.registerAdapter<ArtworkVariant>(ArtworkVariantAdapter());
  hive.registerAdapter<TokenArtworkPreference>(TokenArtworkPreferenceAdapter());
  hive.registerAdapter<TrackerWidget>(TrackerWidgetAdapter());
  hive.registerAdapter<ToggleWidget>(ToggleWidgetAdapter());
  hive.registerAdapter<TrackerWidgetTemplate>(TrackerWidgetTemplateAdapter());
  hive.registerAdapter<ToggleWidgetTemplate>(ToggleWidgetTemplateAdapter());
  hive.registerAdapter<TokenRule>(TokenRuleAdapter());
  hive.registerAdapter<RuleTrigger>(RuleTriggerAdapter());
  hive.registerAdapter<RuleOutcome>(RuleOutcomeAdapter());
  return hive;
}

Future<Map<String, String>> _hashes(Directory dir) async => {
  await for (final file in dir.list(recursive: true, followLinks: false))
    if (file is File)
      file.path: sha256.convert(await file.readAsBytes()).toString(),
};

Future<void> _file(Directory dir, String path, List<int> bytes) async {
  final file = File('${dir.path}/$path');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _fixture(Directory dir, {bool rich = false}) async {
  final hive = _registry()..init(dir.path);
  final item = Item(
    name: 'Goblin',
    pt: '1/1',
    amount: 9,
    tapped: 3,
    summoningSick: 2,
    createdAt: _date,
    artworkUrl: _art,
    artworkOptions: [
      ArtworkVariant(set: 'CUSTOM', url: _art, artist: 'user uploaded'),
    ],
    counters: [TokenCounter(name: 'charge', amount: 4)],
  );
  final items = await hive.openBox<Item>('items');
  await items.put(9, item);
  await items.put(
    '9',
    Item(name: 'Duplicate name', pt: '1/1', createdAt: _date),
  );
  await items.put(
    'deleted',
    Item(name: 'Deleted', pt: '1/1', createdAt: _date),
  );
  await items.delete('deleted');
  final decks = await hive.openBox<Deck>('decks');
  await decks.put(
    'deck',
    Deck(
      name: 'Saved setup',
      templates: [TokenTemplate.fromItem(item)],
      customArtworkUrl: _art,
    ),
  );
  final trackers = await hive.openBox<TrackerWidget>('trackerWidgets');
  final toggles = await hive.openBox<ToggleWidget>('toggleWidgets');
  if (rich) {
    await trackers.put(
      'tracker',
      TrackerWidget(
        widgetId: 'custom',
        name: 'Custom',
        description: 'description',
        colorIdentity: '',
        order: 0,
        currentValue: 3,
        defaultValue: 0,
        createdAt: _date,
      ),
    );
    await toggles.put(
      2,
      ToggleWidget(
        widgetId: 'custom',
        name: 'Toggle',
        onDescription: 'on',
        offDescription: 'off',
        colorIdentity: '',
        order: 0,
        isActive: true,
        createdAt: _date,
      ),
    );
  }
  if (rich) {
    await decks.put(
      'deck',
      Deck(
        name: 'Saved setup',
        templates: [TokenTemplate.fromItem(item)],
        customArtworkUrl: _art,
        trackerWidgets: trackers.values
            .map(TrackerWidgetTemplate.fromWidget)
            .toList(),
        toggleWidgets: toggles.values
            .map(ToggleWidgetTemplate.fromWidget)
            .toList(),
      ),
    );
  }
  final prefs = await hive.openBox<TokenArtworkPreference>(
    'artworkPreferences',
  );
  await prefs.put(
    'art',
    TokenArtworkPreference(tokenIdentity: 'Goblin', customArtworkPath: _art),
  );
  final custom = await hive.openBox<String>('customTokens');
  await custom.put('custom', '{"name":"Custom", "pt":"1/1", "futureField":42}');
  final rules = await hive.openBox<TokenRule>('tokenRules');
  if (rich) {
    await rules.put(
      'rule',
      TokenRule(
        name: 'Rule',
        enabled: false,
        trigger: RuleTrigger(),
        outcomes: [RuleOutcome()],
      ),
    );
  }
  await hive.openBox<String>('boardOrderOperations');
  await hive.close();
  await _file(
    dir,
    'preferences.xml',
    utf8.encode(
      '<map><boolean name="flutter.summoningSicknessEnabled" value="true"/><string name="flutter.unknown">preserved</string></map>',
    ),
  );
  await _file(dir, 'media/upload.png', [1, 2, 3, 4]);
  await _file(dir, 'media/unreferenced.png', [5, 6]);
  await _file(dir, 'hive_backups/unknown.hive', [77, 88]);
}

LegacySourceLayout _layout({
  Map<String, String?>? boxes,
  String sourceId = 'fixture-installation',
}) => LegacySourceLayout(
  sourceId: sourceId,
  sourceVersion: 'repo-fixture-0273043-not-shipped',
  copyEvidence: 'Generated fixture; all seven writers closed before copying',
  capturedAt: _date,
  boxes:
      boxes ??
      {
        for (final name in LegacyMigrationSnapshot.collections)
          name: '${name.toLowerCase()}.hive',
      },
  preferencesPath: 'preferences.xml',
  preferencesFormat: LegacyPreferencesFormat.androidXml,
  mediaPaths: {_art: 'media/upload.png'},
);

void main() {
  late Directory directory;
  late _Memory recovery;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy_source_reader_');
    recovery = _Memory();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<LegacyAcquiredSource> read({
    LegacySourceLayout? layout,
    Future<void> Function(String)? hook,
  }) => LegacySourceReader().acquireCopiedDirectory(
    directory: directory,
    layout: layout ?? _layout(),
    recoveryStorage: recovery,
    onBoundary: hook,
  );

  test(
    'actual root Hive adapters preserve rich copy with all sources untouched',
    () async {
      await _fixture(directory, rich: true);
      final before = await _hashes(directory);
      final acquired = await read();
      final snapshot = acquired.snapshot.toJson();
      final collections = snapshot['collections'] as Map;
      expect((collections['items'] as List).map((x) => x['key']), [9, '9']);
      final item = collections['items'][0]['value'];
      expect(item['amount'], 9);
      expect(item['tapped'], 3);
      expect(item['summoningSick'], 2);
      expect(item['counters'], [
        {'name': 'charge', 'amount': 4},
      ]);
      expect(item['artworkOptions'][0]['artist'], 'user uploaded');
      expect(collections['customTokens'][0]['value']['futureField'], 42);
      expect(
        collections['tokenRules'][0]['value']['outcomes'][0]['outcomeType'],
        'multiply',
      );
      expect(snapshot['preferences']['unknown'], 'preserved');
      expect(acquired.localMedia[_art], [1, 2, 3, 4]);
      final inventory = jsonDecode(
        recovery.values[LegacySourceReader.inventoryKey]!,
      );
      expect(
        inventory['files'].keys,
        containsAll(['media/unreferenced.png', 'hive_backups/unknown.hive']),
      );
      for (final entry in before.entries) {
        final saved = jsonDecode(recovery.values['raw_file_${entry.value}']!);
        expect(
          base64Decode(saved['bytes']),
          await File(entry.key).readAsBytes(),
        );
      }
      expect(await _hashes(directory), before);
      expect(Hive.isBoxOpen('items'), false);
    },
  );

  test(
    'copied snapshot feeds journal, remaps media and repeats deterministically',
    () async {
      await _fixture(directory);
      final first = await read();
      final second = await read();
      expect(first.snapshot.digest, second.snapshot.digest);
      final journal = LegacyMigrationJournal(_Memory());
      final result = await first.prepare(journal);
      expect(result.blockers, isEmpty);
      await journal.commit(result.transactionId);
      final reopened = await journal.openCommitted();
      expect(reopened!.transactionId, result.transactionId);
      expect((await second.prepare(journal)).committed, true);
      final media = first.localMedia;
      media[_art]![0] = 99;
      expect(first.localMedia[_art]![0], 1);
    },
  );

  test(
    'nested sandbox layout retains adjacent Hive backup directories',
    () async {
      final documents = await Directory('${directory.path}/Documents').create();
      await _fixture(documents);
      final base = _layout();
      final layout = LegacySourceLayout(
        sourceId: base.sourceId,
        sourceVersion: base.sourceVersion,
        copyEvidence: base.copyEvidence,
        capturedAt: base.capturedAt,
        boxes: {
          for (final entry in base.boxes.entries)
            entry.key: 'Documents/${entry.value}',
        },
        preferencesPath: 'Documents/preferences.xml',
        preferencesFormat: base.preferencesFormat,
        mediaPaths: {_art: 'Documents/media/upload.png'},
      );
      final acquired = await read(layout: layout);
      expect(acquired.localMedia[_art], [1, 2, 3, 4]);
      expect(
        jsonDecode(recovery.values[LegacySourceReader.inventoryKey]!)['files'],
        contains('Documents/hive_backups/unknown.hive'),
      );
    },
  );

  test(
    'real Hive recovery archive closes and reopens with exact raw files',
    () async {
      await _fixture(directory);
      final recoveryDirectory = await Directory.systemTemp.createTemp(
        'legacy_raw_recovery_',
      );
      Hive.init(recoveryDirectory.path);
      try {
        var store = await HiveLegacyMigrationStorage.openFixture(
          'raw_source_reader',
        );
        final first = await LegacySourceReader().acquireCopiedDirectory(
          directory: directory,
          layout: _layout(),
          recoveryStorage: store,
        );
        await store.close();
        store = await HiveLegacyMigrationStorage.openFixture(
          'raw_source_reader',
        );
        final second = await LegacySourceReader().acquireCopiedDirectory(
          directory: directory,
          layout: _layout(),
          recoveryStorage: store,
        );
        expect(first.inventoryDigest, second.inventoryDigest);
        final journalStore = await HiveLegacyMigrationStorage.openFixture(
          'decoded_source_reader',
        );
        final journal = LegacyMigrationJournal(journalStore);
        final result = await second.prepare(journal);
        await journal.commit(result.transactionId);
        await journalStore.close();
        final reopened = await HiveLegacyMigrationStorage.openFixture(
          'decoded_source_reader',
        );
        expect(
          (await LegacyMigrationJournal(
            reopened,
          ).openCommitted())!.transactionId,
          result.transactionId,
        );
        expect(Hive.isBoxOpen('items'), false);
      } finally {
        await Hive.close();
        await recoveryDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'all acquisition interruption boundaries retry without source changes',
    () async {
      await _fixture(directory);
      final boundaries = <String>[];
      await read(
        hook: (boundary) async {
          boundaries.add(boundary);
        },
      );
      final before = await _hashes(directory);
      for (final boundary in boundaries) {
        recovery = _Memory();
        await expectLater(
          read(
            hook: (at) async {
              if (at == boundary) throw StateError('interrupted');
            },
          ),
          throwsStateError,
        );
        final retry = await read();
        expect(retry.snapshot.sourceId, 'fixture-installation');
        expect(await _hashes(directory), before);
      }
    },
  );

  test(
    'corrupt and truncated Hive reject without repair while originals remain retained',
    () async {
      await _fixture(directory);
      final file = File('${directory.path}/items.hive');
      final original = await file.readAsBytes();
      for (final bytes in [
        original.sublist(0, original.length - 1),
        [...original, 1, 2, 3],
        [0, 0, 0, 0],
      ]) {
        await file.writeAsBytes(bytes);
        recovery = _Memory();
        final before = await _hashes(directory);
        await expectLater(read(), throwsA(isA<FormatException>()));
        expect(await _hashes(directory), before);
        expect(recovery.values, contains(LegacySourceReader.inventoryKey));
        expect(recovery.values, contains('raw_file_${sha256.convert(bytes)}'));
      }
    },
  );

  test(
    'copy mutation and symlinks fail without opening or altering sources',
    () async {
      await _fixture(directory);
      await expectLater(
        read(
          hook: (at) async {
            if (at == 'copied') await _file(directory, 'new-file', [1]);
          },
        ),
        throwsFormatException,
      );
      expect(recovery.values, isEmpty);
      await Link('${directory.path}/escaped').create('/tmp');
      await expectLater(read(), throwsFormatException);
    },
  );

  test(
    'missing declared box fails; explicitly absent historical boxes are empty',
    () async {
      await _fixture(directory);
      await File('${directory.path}/tokenrules.hive').delete();
      await expectLater(read(), throwsFormatException);
      recovery = _Memory();
      final layout = _layout(boxes: {..._layout().boxes, 'tokenRules': null});
      final acquired = await read(layout: layout);
      expect(acquired.snapshot.toJson()['collections']['tokenRules'], isEmpty);
    },
  );

  test(
    'failed durability and silent write loss prevent decode; retry is safe',
    () async {
      await _fixture(directory);
      for (final lose in [false, true]) {
        recovery = _Memory()
          ..loseWrites = lose
          ..failFlush = !lose;
        await expectLater(read(), throwsA(anything));
        recovery
          ..loseWrites = false
          ..failFlush = false;
        expect((await read()).snapshot.sourceId, 'fixture-installation');
      }
    },
  );

  test(
    'retained corruption cannot be prepared and other sources cannot overwrite it',
    () async {
      await _fixture(directory);
      final acquired = await read();
      final journalStorage = _Memory();
      await expectLater(
        read(layout: _layout(sourceId: 'different-installation')),
        throwsFormatException,
      );
      final fileKey = recovery.values.keys.firstWhere(
        (k) => k.startsWith('raw_file_'),
      );
      recovery.values[fileKey] = '{"bytes":"AA==","sha256":"wrong"}';
      await expectLater(
        acquired.prepare(LegacyMigrationJournal(journalStorage)),
        throwsFormatException,
      );
      expect(journalStorage.values, isEmpty);
    },
  );

  test(
    'rejects incomplete layouts, traversal, duplicate files and remote media',
    () {
      expect(() => _layout(boxes: {}), throwsFormatException);
      expect(
        () => _layout(boxes: {..._layout().boxes, 'items': '../outside.hive'}),
        throwsFormatException,
      );
      expect(
        () => _layout(boxes: {..._layout().boxes, 'items': 'decks.hive'}),
        throwsFormatException,
      );
    },
  );

  test(
    'actual adapters accept historical missing optional item fields',
    () async {
      await _fixture(directory);
      final registry = HiveImpl()
        ..registerAdapter<Item>(_HistoricalItemAdapter());
      final writer = BinaryWriterImpl(registry);
      writer.writeFrame(
        Frame('old', Item(name: 'Old token', pt: '2/2', createdAt: _date)),
      );
      await _file(directory, 'items.hive', writer.toBytes());
      final acquired = await read();
      final value = acquired.snapshot
          .toJson()['collections']['items'][0]['value'];
      expect(value['name'], 'Old token');
      expect(value['order'], 0.0);
      expect(value['type'], '');
      expect(value['artworkUrl'], isNull);
      expect(value['plusOnePowerCounters'], 0);
      expect(value['plusOneToughnessCounters'], 0);
    },
  );

  test(
    'oversized source file refuses before allocation or retention',
    () async {
      await _fixture(directory);
      final file = await File(
        '${directory.path}/oversized',
      ).open(mode: FileMode.write);
      await file.truncate(LegacySourceReader.maxFileBytes + 1);
      await file.close();
      await expectLater(read(), throwsFormatException);
      expect(recovery.values, isEmpty);
    },
  );

  test(
    'POSIX backslash aliases cannot omit a raw source file',
    () async {
      await _fixture(directory);
      await _file(directory, 'foo/bar', [1]);
      await _file(directory, r'foo\bar', [2]);
      final before = await _hashes(directory);
      await expectLater(read(), throwsFormatException);
      expect(recovery.values, isEmpty);
      expect(await _hashes(directory), before);
    },
    skip: Platform.isWindows,
  );

  test(
    'simultaneous acquisitions cannot overwrite a retained inventory',
    () async {
      await _fixture(directory);
      final results = await Future.wait([
        read().then((_) => 'first'),
        read(
          layout: _layout(sourceId: 'other'),
        ).then((_) => 'other', onError: (_) => 'refused'),
      ]);
      expect(results, ['first', 'refused']);
      expect(
        jsonDecode(
          recovery.values[LegacySourceReader.inventoryKey]!,
        )['layout']['sourceId'],
        'fixture-installation',
      );
    },
  );

  test('extra unrecognized Hive store blocks and remains retained', () async {
    await _fixture(directory);
    await _file(directory, 'future.hive', [1, 2]);
    await expectLater(read(), throwsFormatException);
    expect(recovery.values, contains('raw_file_${sha256.convert([1, 2])}'));
  });

  test(
    'pending board order recovery is retained and blocks snapshot creation',
    () async {
      await _fixture(directory);
      final writer = BinaryWriterImpl(HiveImpl());
      writer.writeFrame(Frame('pendingV1', '[{"kind":0,"key":9,"order":2}]'));
      await _file(directory, 'boardorderoperations.hive', writer.toBytes());
      final before = await _hashes(directory);
      await expectLater(read(), throwsFormatException);
      expect(await _hashes(directory), before);
      expect(recovery.values, contains(LegacySourceReader.inventoryKey));
    },
  );

  test(
    'valid-CRC fractional integers and noncanonical booleans are refused',
    () async {
      await _fixture(directory);
      for (final kind in ['fractionalInt', 'overflowInt', 'invalidBool']) {
        final registry = HiveImpl()
          ..registerAdapter<Item>(_MalformedScalarAdapter(kind));
        final writer = BinaryWriterImpl(registry);
        writer.writeFrame(
          Frame('corrupt', Item(name: 'Corrupt', pt: '1/1', createdAt: _date)),
        );
        await _file(directory, 'items.hive', writer.toBytes());
        recovery = _Memory();
        await expectLater(read(), throwsFormatException, reason: kind);
        expect(recovery.values, contains(LegacySourceReader.inventoryKey));
      }
    },
  );

  test(
    'future Hive type, unknown fields and duplicate fields refuse activation',
    () async {
      await _fixture(directory);
      for (final kind in ['unknownType', 'unknownField', 'duplicateField']) {
        final registry = HiveImpl()..registerAdapter(_BadAdapter(kind));
        final writer = BinaryWriterImpl(registry);
        writer.writeFrame(Frame(0, _BadValue()));
        await _file(directory, 'items.hive', writer.toBytes());
        recovery = _Memory();
        await expectLater(read(), throwsA(anything));
        expect(recovery.values, contains(LegacySourceReader.inventoryKey));
      }
    },
  );
}

class _BadValue {}

class _BadAdapter extends TypeAdapter<_BadValue> {
  final String kind;
  _BadAdapter(this.kind);
  @override
  int get typeId => kind == 'unknownType' ? 13 : 0;
  @override
  _BadValue read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, _BadValue obj) {
    writer
      ..writeByte(2)
      ..writeByte(kind == 'unknownField' ? 18 : 1)
      ..write('A')
      ..writeByte(1)
      ..write('B');
  }
}

class _HistoricalItemAdapter extends TypeAdapter<Item> {
  @override
  int get typeId => 0;
  @override
  Item read(BinaryReader reader) => ItemAdapter().read(reader);
  @override
  void write(BinaryWriter writer, Item item) {
    final fields = [
      item.abilities,
      item.name,
      item.pt,
      item.colors,
      item.amount,
      item.tapped,
      item.summoningSick,
      item.plusOneCounters,
      item.minusOneCounters,
      item.counters,
      item.createdAt,
    ];
    writer.writeByte(fields.length);
    for (var i = 0; i < fields.length; i++) {
      writer
        ..writeByte(i)
        ..write(fields[i]);
    }
  }
}

class _MalformedScalarAdapter extends _HistoricalItemAdapter {
  final String kind;
  _MalformedScalarAdapter(this.kind);
  @override
  void write(BinaryWriter writer, Item item) {
    final fields = [
      item.abilities,
      item.name,
      item.pt,
      item.colors,
      item.amount,
      item.tapped,
      item.summoningSick,
      item.plusOneCounters,
      item.minusOneCounters,
      item.counters,
      item.createdAt,
    ];
    writer.writeByte(fields.length);
    for (var i = 0; i < fields.length; i++) {
      writer.writeByte(i);
      if (i == 4 && kind != 'invalidBool') {
        // Actual Hive integer tag followed by a deliberately invalid float64.
        writer
          ..writeByte(1)
          ..writeDouble(kind == 'fractionalInt' ? 1.5 : 1e30);
      } else if (i == 10 && kind == 'invalidBool') {
        // Built-in DateTime-with-time-zone tag, millis, then invalid isUtc byte.
        writer
          ..writeByte(18)
          ..writeInt(_date.millisecondsSinceEpoch)
          ..writeByte(2);
      } else {
        writer.write(fields[i]);
      }
    }
  }
}

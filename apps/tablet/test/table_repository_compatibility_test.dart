import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/storage/table_repository.dart';

import 'support/table_fixture.dart';

String _encode(
  Map<String, dynamic> json, {
  int version = 1,
  int? sequence = 10,
}) {
  final payload = jsonEncode(json);
  return jsonEncode({
    'format': 'tripling-season-tablet',
    'version': version,
    'sequence': ?sequence,
    'sha256': sha256.convert(utf8.encode(payload)).toString(),
    'payload': payload,
  });
}

TabletState _richState(int count) {
  final state = stateWithTokens([
    sampleToken(
      artworkUrl: 'tablet-art:retained-media',
      counters: {'shield': 3},
    ),
  ]);
  while (state.profiles.length < count) {
    final index = state.profiles.length;
    state.profiles.add(SeatProfile(id: 'seat-$index', name: 'Seat $index'));
    state.session.players.add(
      PlayerState(id: 'player-$index', seatId: 'seat-$index', slot: index),
    );
  }
  state.session.players = state.session.players.take(count).toList();
  state.session.players.first.life = 27;
  state.session.players.first.tokens.first.extra['future-extension'] = {'a': 1};
  state.session.revision = 1;
  state.session.history.add(
    HistoryEntry(
      id: 'retained-history',
      label: 'Life',
      createdAt: DateTime.utc(2026, 11, 10),
      updatedAt: DateTime.utc(2026, 11, 10),
      playerId: state.session.players.first.id,
      affectedPlayerIds: [state.session.players.first.id],
      commands: [
        HistoryCommand(
          id: 'retained-command',
          label: 'Life',
          at: DateTime.utc(2026, 11, 10),
          revision: 1,
          changes: [
            HistoryChange(
              path: ['session', 'players', 0, 'life'],
              before: 40,
              after: 27,
            ),
          ],
        ),
      ],
    ),
  );
  state.archives.add(
    GameArchive(
      id: 'retained-archive',
      label: 'Archive',
      savedAt: DateTime.utc(2026, 11, 10),
      session: state.session.copy(),
    ),
  );
  state.decks.add({
    'id': 'deck',
    'metadata': {
      'unknown': ['preserved'],
    },
  });
  state.library['custom'] = {'name': 'Untouched'};
  state.settings['theme'] = 'dark';
  return state;
}

// The envelope and schema gates are frozen from fa9ed9c, the last storage
// implementation whose state validator accepted only 2–4 players. Both guards
// preceded payload validation and open() rethrew UnsupportedTableFormat.
void _oldReader(String encoded) {
  final envelope = jsonMap(jsonDecode(encoded));
  if (envelope['format'] != 'tripling-season-tablet' ||
      envelope['version'] != 1) {
    throw const UnsupportedTableFormat('Old reader stopped before fallback.');
  }
  final payload = envelope['payload'] as String;
  if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
    throw const FormatException('Integrity');
  }
  final json = jsonMap(jsonDecode(payload));
  if (json['schemaVersion'] != 1) {
    throw const UnsupportedTableFormat('Old reader stopped before fallback.');
  }
  if ((json['session']['players'] as List).length > 4) {
    throw const FormatException('Old validator would recover an older game.');
  }
}

class _Crash {
  int? at;
  int calls = 0;
  void boundary() {
    calls++;
    if (at != null && calls >= at!) throw StateError('Simulated storage loss');
  }
}

class _FaultBox extends Fake implements Box<String> {
  final Box<String> delegate;
  final _Crash crash;
  _FaultBox(this.delegate, this.crash);
  @override
  bool get isEmpty => delegate.isEmpty;
  @override
  String? get(dynamic key, {String? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, String value) async {
    crash.boundary();
    await delegate.put(key, value);
  }

  @override
  Future<void> flush() async {
    crash.boundary();
    await delegate.flush();
  }

  @override
  Future<void> delete(dynamic key) async {
    crash.boundary();
    await delegate.delete(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<String> main;
  late Box<String> backup;
  late Box<String> recovery;
  late _Crash crash;
  late TableRepository repository;

  Future<TableRepository> makeRepository() async => TableRepository.forTesting(
    openBox: (name) async => _FaultBox(await Hive.openBox<String>(name), crash),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('table-compatibility-');
    Hive.init(directory.path);
    main = await Hive.openBox<String>(TableRepository.boxName);
    backup = await Hive.openBox<String>('${TableRepository.boxName}_previous');
    recovery = await Hive.openBox<String>(
      '${TableRepository.boxName}_recovery',
    );
    crash = _Crash();
    repository = await makeRepository();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final count in [2, 3, 4, 5, 6]) {
    test(
      'v1 $count-player full state upgrades losslessly and retains exact original',
      () async {
        final original = _richState(count);
        final legacyJson = original.toJson()..['schemaVersion'] = 1;
        final encoded = _encode(legacyJson, sequence: count == 2 ? null : 10);
        await main.put('current', encoded);
        final result = await repository.open();
        expect(result.state.toJson(), original.toJson());
        expect(result.recoveryMessage, isNull);
        final retained = backup.toMap().entries.where(
          (e) => e.key.toString().startsWith('before_format_2_'),
        );
        expect(retained.single.value, encoded);
        expect(jsonDecode(main.get('current')!)['version'], 2);
        expect(
          () => _oldReader(main.get('current')!),
          throwsA(isA<UnsupportedTableFormat>()),
        );
        // Rolling previous changes; the immutable checkpoint does not.
        result.state.session.players.first.life--;
        await repository.save(result.state);
        await repository.save(result.state);
        expect(backup.get(retained.single.key), encoded);
        await Hive.close();
        Hive.init(directory.path);
        final reopened = await (await makeRepository()).open();
        expect(reopened.state.toJson(), result.state.toJson());
      },
    );
  }

  test(
    'old validator hazard is reproduced, upgraded envelope blocks even corrupt payload',
    () async {
      final original = _richState(6).toJson()..['schemaVersion'] = 1;
      final encoded = _encode(original);
      expect(() => _oldReader(encoded), throwsFormatException);
      await main.put('current', encoded);
      await repository.open();
      final upgraded = jsonMap(jsonDecode(main.get('current')!))
        ..['payload'] = 'damaged';
      expect(
        () => _oldReader(jsonEncode(upgraded)),
        throwsA(isA<UnsupportedTableFormat>()),
      );
    },
  );

  test(
    'schema 1 archives with six players survive a four-player active game',
    () async {
      final original = _richState(6);
      original.session.players = original.session.players.take(4).toList();
      final encoded = _encode(original.toJson()..['schemaVersion'] = 1);
      await main.put('current', encoded);
      final result = await repository.open();
      expect(result.state.toJson(), original.toJson());
      expect(result.state.archives.single.session.players.length, 6);
    },
  );

  test(
    'new installations use format 2 and reopen without another write',
    () async {
      final state = (await repository.open()).state;
      final encoded = main.get('current');
      expect(jsonDecode(encoded!)['version'], 2);
      expect((await repository.open()).state.toJson(), state.toJson());
      expect(main.get('current'), encoded);
    },
  );

  for (final location in ['main', 'recovery', 'backup', 'same-container']) {
    for (final future in [
      'envelope',
      'schema',
      'field',
      'players',
      'shape',
      'semantics',
    ]) {
      test(
        'unknown $future in $location blocks all writes without fallback',
        () async {
          final state = _richState(4);
          await main.put(
            'current',
            _encode(state.toJson(), version: 2, sequence: 99),
          );
          final json = state.toJson();
          var version = 2;
          switch (future) {
            case 'envelope':
              version = 3;
            case 'schema':
              json['schemaVersion'] = 3;
            case 'field':
              json['session']['players'][0]['futureField'] = {
                'must': 'survive',
              };
            case 'semantics':
              json['session']['dayNight'] = 'future-designation';
            case 'shape':
              json['session']['players'][0]['life'] = {'value': 27};
            case 'players':
              final large = _richState(7);
              json['profiles'] = large.toJson()['profiles'];
              json['session'] = large.toJson()['session'];
          }
          final encoded = _encode(json, version: version, sequence: 1);
          switch (location) {
            case 'main':
              await main.put('current', encoded);
            case 'recovery':
              await recovery.put('current', encoded);
            case 'backup':
              await backup.put('current', encoded);
            case 'same-container':
              await main.put('previous', encoded);
          }
          final before = [main.toMap(), backup.toMap(), recovery.toMap()];
          await expectLater(
            repository.open(),
            throwsA(isA<UnsupportedTableFormat>()),
          );
          expect([main.toMap(), backup.toMap(), recovery.toMap()], before);
          await expectLater(repository.save(state), throwsStateError);
        },
      );
    }
  }

  test('failed reopen revokes a previously successful writer', () async {
    final state = (await repository.open()).state;
    final unknown = _encode(state.toJson(), version: 3);
    await main.put('current', unknown);
    await expectLater(
      repository.open(),
      throwsA(isA<UnsupportedTableFormat>()),
    );
    await expectLater(repository.save(state), throwsStateError);
    expect(main.get('current'), unknown);
  });

  for (var boundary = 1; boundary <= 6; boundary++) {
    test(
      'upgrade interruption at boundary $boundary preserves an exact resumable game',
      () async {
        final original = _richState(6);
        final encoded = _encode(original.toJson()..['schemaVersion'] = 1);
        await main.put('current', encoded);
        crash.at = boundary;
        await expectLater(repository.open(), throwsStateError);
        await expectLater(repository.save(original), throwsStateError);
        crash.at = null;
        await Hive.close();
        Hive.init(directory.path);
        repository = await makeRepository();
        expect((await repository.open()).state.toJson(), original.toJson());
        backup = Hive.box<String>('${TableRepository.boxName}_previous');
        expect(
          backup
              .toMap()
              .entries
              .where((e) => e.key.toString().startsWith('before_format_2_'))
              .single
              .value,
          encoded,
        );
      },
    );
  }

  test(
    'corrupt current is retained before recovering legacy previous',
    () async {
      final original = _richState(5);
      final encoded = _encode(original.toJson()..['schemaVersion'] = 1);
      await main.put('current', 'corrupt exact bytes');
      await backup.put('current', encoded);
      final result = await repository.open();
      expect(result.state.toJson(), original.toJson());
      expect(result.recoveryMessage, isNotNull);
      expect(
        main
            .toMap()
            .entries
            .where((e) => e.key.toString().startsWith('quarantine_'))
            .single
            .value,
        'corrupt exact bytes',
      );
    },
  );

  test(
    'failed quarantine blocks recovery and never replaces damaged bytes',
    () async {
      await main.put('current', 'corrupt exact bytes');
      await backup.put('current', _encode(_richState(4).toJson(), version: 2));
      crash.at = 1;
      await expectLater(repository.open(), throwsStateError);
      expect(main.get('current'), 'corrupt exact bytes');
      await expectLater(repository.save(_richState(4)), throwsStateError);
    },
  );

  test(
    'same-container legacy backup recovers without clearing either source',
    () async {
      final original = _richState(4);
      final encoded = _encode(original.toJson()..['schemaVersion'] = 1);
      await main.put('previous', encoded);
      final result = await repository.open();
      expect(result.state.toJson(), original.toJson());
      expect(main.get('previous'), encoded);
    },
  );
  test(
    'missing optional v1 fields receive existing defaults without losing state',
    () async {
      final original = _richState(4);
      final json = original.toJson()..['schemaVersion'] = 1;
      json['session'].remove('profileUndoProtectedThroughRevision');
      json['session']['players'][0].remove('summoningSicknessEnabled');
      json['session']['players'][0]['tokens'][0].remove('minusOneCounters');
      final encoded = _encode(json);
      await main.put('current', encoded);
      final result = await repository.open();
      expect(result.state.toJson(), original.toJson());
      expect(backup.values, contains(encoded));
    },
  );

  test(
    'an unreadable main container recovers elsewhere without resetting source',
    () async {
      final original = _richState(6);
      final encoded = _encode(original.toJson()..['schemaVersion'] = 1);
      await main.put('sentinel', 'unreadable source stays here');
      await backup.put('current', encoded);
      repository = TableRepository.forTesting(
        openBox: (name) async {
          if (name == TableRepository.boxName) {
            throw StateError('Unreadable container');
          }
          return Hive.openBox<String>(name);
        },
      );
      final result = await repository.open();
      expect(result.state.toJson(), original.toJson());
      expect(result.recoveryMessage, isNotNull);
      expect(main.toMap(), {'sentinel': 'unreadable source stays here'});
      expect(jsonDecode(recovery.get('current')!)['version'], 2);
    },
  );

  test(
    'an unavailable backup retains upgrade checkpoint in the main container',
    () async {
      final original = _richState(5);
      final encoded = _encode(original.toJson()..['schemaVersion'] = 1);
      await main.put('current', encoded);
      repository = TableRepository.forTesting(
        openBox: (name) async {
          if (name.endsWith('_previous')) {
            throw StateError('Unavailable backup');
          }
          return Hive.openBox<String>(name);
        },
      );
      expect((await repository.open()).state.toJson(), original.toJson());
      expect(
        main
            .toMap()
            .entries
            .where((e) => e.key.toString().startsWith('before_format_2_'))
            .single
            .value,
        encoded,
      );
      expect(main.get('previous'), encoded);
    },
  );

  test(
    'failed fresh boot never initializes over an unreadable container',
    () async {
      repository = TableRepository.forTesting(
        openBox: (name) async {
          if (name == TableRepository.boxName) {
            throw StateError('Unreadable container');
          }
          return Hive.openBox<String>(name);
        },
      );
      await expectLater(repository.open(), throwsStateError);
      expect(backup.isEmpty, isTrue);
      expect(recovery.isEmpty, isTrue);
    },
  );

  for (var boundary = 1; boundary <= 4; boundary++) {
    test(
      'normal save interruption $boundary retains a complete acknowledged generation',
      () async {
        final original = _richState(6);
        final encoded = _encode(original.toJson(), version: 2);
        await main.put('current', encoded);
        final next = (await repository.open()).state;
        next.session.players.first.life--;
        crash.at = boundary;
        await expectLater(repository.save(next), throwsStateError);
        expect([main.get('current'), backup.get('current')], contains(encoded));
        crash.at = null;
        await Hive.close();
        Hive.init(directory.path);
        final restored = (await (await makeRepository()).open()).state.toJson();
        expect(restored, anyOf(original.toJson(), next.toJson()));
      },
    );
  }
  for (final retainedKey in [
    'before_format_2_retained',
    'quarantine_retained',
  ]) {
    test(
      'retained $retainedKey prevents silent initialization when live records are missing',
      () async {
        final encoded = _encode(_richState(6).toJson()..['schemaVersion'] = 1);
        await backup.put(retainedKey, encoded);
        await expectLater(repository.open(), throwsStateError);
        expect(main.isEmpty, isTrue);
        expect(recovery.isEmpty, isTrue);
        expect(backup.toMap(), {retainedKey: encoded});
      },
    );
  }
}

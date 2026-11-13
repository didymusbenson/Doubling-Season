import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/storage/table_repository.dart';

import 'support/table_fixture.dart';

// Each boundary is before or after a real Hive put/flush. Fail once so the
// existing repository rollback can run. This does not simulate power loss.
class _Faults {
  int calls = 0;
  int? failAt;
  void boundary() {
    calls++;
    if (calls == failAt) throw StateError('Injected preset write failure');
  }

  void arm(int? point) {
    calls = 0;
    failAt = point;
  }
}

class _FaultBox extends Fake implements Box<String> {
  final Box<String> delegate;
  final _Faults faults;
  _FaultBox(this.delegate, this.faults);
  @override
  bool get isEmpty => delegate.isEmpty;
  @override
  String? get(dynamic key, {String? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, String value) async {
    faults.boundary();
    await delegate.put(key, value);
    faults.boundary();
  }

  @override
  Future<void> flush() async {
    faults.boundary();
    await delegate.flush();
    faults.boundary();
  }

  @override
  Future<void> delete(dynamic key) async {
    faults.boundary();
    await delegate.delete(key);
    faults.boundary();
  }
}

TabletState _richState(int count) {
  final state = stateWithTokens([
    sampleToken(
      artworkUrl: 'https://example.test/token.png',
      counters: {'shield': 2},
    ),
  ]);
  while (state.profiles.length < count) {
    final i = state.profiles.length;
    state.profiles.add(SeatProfile(id: 'seat-$i', name: 'Seat $i'));
    state.session.players.add(
      PlayerState(id: 'player-$i', seatId: 'seat-$i', slot: i),
    );
  }
  state.session.players = state.session.players.take(count).toList();
  for (var i = 0; i < count; i++) {
    final p = state.session.players[i];
    p.life = 31 + i;
    p.counters['poison'] = i + 1;
    p.mana['U'] = i + 2;
    state.profiles.firstWhere((s) => s.id == p.seatId).artworkUrl =
        'https://example.test/seat-$i.png';
    if (i != 0) {
      p.tokens.add(
        sampleToken(id: 'seat-token-$i', name: 'Target $i', amount: 7),
      );
    }
  }
  state.session.players.first.tokens.first.extra['artworkDisplayStyle'] =
      'fadeout';
  state.session.players.first.utilities.add(
    UtilityState(
      id: 'source-utility',
      kind: 'custom_tracker',
      name: 'Retained tracker',
      value: 17,
      defaultValue: 3,
      visible: false,
      configuration: {
        'type': 'tracker',
        'isCustom': true,
        'longPressIncrement': 7,
      },
    ),
  );
  state.archives.add(
    GameArchive(
      id: 'untouched-archive',
      label: 'Earlier game',
      savedAt: DateTime.utc(2026),
      session: state.session.copy(),
    ),
  );
  state.library['future'] = {'retained': true};
  return state;
}

class _Harness {
  late Directory directory;
  final faults = _Faults();
  late TableController controller;
  late TabletCatalog catalog;
  PresetService get presets => PresetService(controller, catalog);
  String get source => controller.session.players.first.id;
  String get target => controller.session.players[1].id;
  TableRepository repository() => TableRepository.forTesting(
    openBox: (name) async =>
        _FaultBox(await Hive.openBox<String>(name), faults),
  );
  Future<void> start(int count) async {
    directory = await Directory.systemTemp.createTemp('preset-durable-');
    Hive.init(directory.path);
    final seed = repository();
    await seed.open();
    await seed.save(_richState(count));
    await _open();
    // Ensure unrelated chronological history exists before a setup operation.
    expect(await controller.adjustLife(source, -1), isTrue);
  }

  Future<void> _open() async {
    controller = TableController(repository: repository());
    await controller.initialize();
    expect(controller.ready, isTrue, reason: controller.error);
    catalog = TabletCatalog(controller)..loaded = true;
  }

  Future<void> reopen() async {
    catalog.dispose();
    controller.dispose();
    await Hive.close();
    Hive.init(directory.path);
    faults.arm(null);
    await _open();
  }

  Future<String> save() async =>
      (await presets.save(
            source,
            'Portable setup',
            imageUrl: controller
                .profile(controller.player(source).seatId)
                .artworkUrl,
          ))['id']
          as String;
  Future<void> close() async {
    catalog.dispose();
    controller.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  }
}

Map<String, dynamic> _playerContent(PlayerState p) =>
    p.toJson()..remove('generation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;
  tearDown(() async => h.close());

  for (final count in [2, 6]) {
    for (final append in [false, true]) {
      test(
        '$count seats: ${append ? 'append' : 'replace'} cover and undo survive durable reopen',
        () async {
          h = _Harness();
          await h.start(count);
          final beforeSave = h.controller.state.copy();
          final id = await h.save();
          expect(h.controller.session.toJson(), beforeSave.session.toJson());
          final before = h.controller.state.copy();
          await h.presets.load(h.target, id, append: append, applyImage: true);
          final loaded = h.controller.state.copy();
          final target = h.controller.player(h.target);
          expect(target.tokens.length, append ? 2 : 1);
          final fresh = target.tokens.last;
          expect(
            [
              fresh.amount,
              fresh.tapped,
              fresh.summoningSick,
              fresh.plusOneCounters,
            ],
            [0, 0, 0, 0],
          );
          expect(fresh.counters, isEmpty);
          expect(fresh.extra['artworkDisplayStyle'], 'fadeout');
          expect(target.utilities.last.value, 3);
          expect(target.utilities.last.visible, isFalse);
          expect(
            h.controller.profile(target.seatId).artworkUrl,
            'https://example.test/seat-0.png',
          );
          expect(target.life, before.session.player(h.target).life);
          expect(target.counters, before.session.player(h.target).counters);
          expect(target.mana, before.session.player(h.target).mana);
          for (final player in before.session.players.where(
            (p) => p.id != h.target,
          )) {
            expect(h.controller.player(player.id).toJson(), player.toJson());
            expect(
              h.controller.profile(player.seatId).toJson(),
              before.profiles.firstWhere((s) => s.id == player.seatId).toJson(),
            );
          }
          expect(loaded.decks, before.decks);
          expect(
            loaded.archives.map((a) => a.toJson()),
            before.archives.map((a) => a.toJson()),
          );
          expect(loaded.library, before.library);
          expect(
            loaded.session.history
                .take(before.session.history.length)
                .map((e) => e.toJson()),
            before.session.history.map((e) => e.toJson()),
          );
          await h.reopen();
          expect(h.controller.state.toJson(), loaded.toJson());
          expect(await h.controller.undo(), isTrue);
          expect(
            _playerContent(h.controller.player(h.target)),
            _playerContent(before.session.player(h.target)),
          );
          expect(
            h.controller.state.profiles.map((p) => p.toJson()),
            before.profiles.map((p) => p.toJson()),
          );
          expect(h.controller.state.decks, before.decks);
          final undone = h.controller.state.toJson();
          await h.reopen();
          expect(h.controller.state.toJson(), undone);
        },
      );
    }
  }

  test(
    'later permanent cover choice survives undo of an earlier setup load',
    () async {
      h = _Harness();
      await h.start(2);
      final id = await h.save();
      final before = _playerContent(h.controller.player(h.target));
      await h.presets.load(h.target, id, applyImage: true);
      final seat = h.controller.player(h.target).seatId;
      expect(
        await h.controller.updateState('Change saved appearance', (state) {
          state.profiles.firstWhere((p) => p.id == seat).artworkUrl =
              'https://example.test/later.png';
        }),
        isTrue,
      );
      await h.reopen();
      expect(await h.controller.undo(), isTrue);
      expect(_playerContent(h.controller.player(h.target)), before);
      expect(
        h.controller.profile(seat).artworkUrl,
        'https://example.test/later.png',
      );
      expect(
        h.controller.session.history.last.undoNote,
        contains('appearance was kept'),
      );
      final after = h.controller.state.toJson();
      await h.reopen();
      expect(h.controller.state.toJson(), after);
    },
  );

  for (final operation in ['save', 'replace', 'append', 'undo']) {
    for (var point = 1; point <= 8; point++) {
      test(
        '$operation rolls back one-shot Hive boundary $point, reopens and retries',
        () async {
          h = _Harness();
          await h.start(2);
          final id = operation == 'save' ? null : await h.save();
          if (operation == 'undo') {
            await h.presets.load(h.target, id!, applyImage: true);
          }
          final before = h.controller.state.toJson();
          Future<void> act({required bool failing}) async {
            if (operation == 'undo') {
              expect(await h.controller.undo(), !failing);
            } else if (operation == 'save') {
              if (failing) {
                await expectLater(h.save(), throwsStateError);
              } else {
                await h.save();
              }
            } else {
              final future = h.presets.load(
                h.target,
                id!,
                append: operation == 'append',
                applyImage: true,
              );
              if (failing) {
                await expectLater(future, throwsStateError);
              } else {
                await future;
              }
            }
          }

          h.faults.arm(point);
          await act(failing: true);
          expect(h.faults.calls, greaterThanOrEqualTo(point));
          expect(h.controller.state.toJson(), before);
          await h.reopen();
          expect(h.controller.state.toJson(), before);
          await act(failing: false);
          expect(h.controller.state.toJson(), isNot(equals(before)));
          final after = h.controller.state.toJson();
          await h.reopen();
          expect(h.controller.state.toJson(), after);
        },
      );
    }
  }
}

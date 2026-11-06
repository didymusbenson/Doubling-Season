import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

TabletState populated() {
  final state = TabletState.initial();
  for (final player in state.session.players) {
    player.tokens = [
      sampleToken(
        id: '${player.id}/creature',
        plusOne: 2,
        counters: {'charge': 4},
        artworkUrl: 'https://example.invalid/art.png',
      ),
      sampleToken(
        id: '${player.id}/artifact',
        name: 'Treasure',
        type: 'Artifact — Treasure',
        pt: '',
      ),
      sampleToken(
        id: '${player.id}/both',
        name: 'Golem',
        type: 'Artifact Creature — Golem',
      ),
      sampleToken(
        id: '${player.id}/land',
        name: 'Forest',
        type: 'Land — Forest',
        pt: '',
      ),
      sampleToken(
        id: '${player.id}/emblem',
        name: 'Emblem',
        type: 'Emblem',
        pt: '',
      ),
    ];
    player.tokens.first.extra['future-data'] = {
      'nested': [1, 2, 3],
    };
    player.life = 27;
    player.counters['energy'] = 8;
    player.mana['G'] = 4;
  }
  state.archives.add(
    GameArchive(
      id: 'old',
      label: 'Previous game',
      savedAt: DateTime.utc(2026, 11, 6),
      session: state.session.copy(),
    ),
  );
  return state;
}

Map<String, dynamic> withoutGeneration(PlayerState player) =>
    player.toJson()..remove('generation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final remove in [false, true]) {
    test(
      'combined wipe remove=$remove saves one union and restores all data',
      () async {
        final f = TableFixture(populated());
        addTearDown(f.dispose);
        await f.initialize();
        final before = f.controller.state.copy();
        final selected = {'wipe_creatures', 'wipe_artifacts'};
        await f.board.wipeSelectedEveryone(selected, remove: remove);
        expect(f.controller.session.history, hasLength(1));
        expect(f.controller.session.history.single.commands, hasLength(1));
        expect(
          f.controller.session.history.single.affectedPlayerIds,
          hasLength(4),
        );
        for (final player in f.controller.session.players) {
          final old = before.session.player(player.id);
          expect(player.generation, old.generation + 1);
          if (remove) {
            expect(player.tokens.map((t) => t.id.split('/').last), [
              'land',
              'emblem',
            ]);
          } else {
            expect(player.tokens.map((t) => t.id), old.tokens.map((t) => t.id));
            for (var i = 0; i < player.tokens.length; i++) {
              final expected = old.tokens[i].toJson();
              if (i < 3) {
                expected['amount'] = 0;
                expected['tapped'] = 0;
                expected['summoningSick'] = 0;
              }
              expect(player.tokens[i].toJson(), expected);
            }
          }
          expect(
            withoutGeneration(player)..remove('tokens'),
            withoutGeneration(old)..remove('tokens'),
          );
        }
        expect(
          f.controller.state.profiles.map((p) => p.toJson()).toList(),
          before.profiles.map((p) => p.toJson()).toList(),
        );
        expect(
          f.controller.state.archives.map((a) => a.toJson()).toList(),
          before.archives.map((a) => a.toJson()).toList(),
        );
        final after = f.controller.session.players
            .map((p) => p.toJson())
            .toList();
        await f.board.wipeSelectedEveryone(selected, remove: remove);
        expect(
          f.controller.session.players.map((p) => p.toJson()).toList(),
          after,
          reason: 'Repeated wipes do not change boards or invalidate editors',
        );
        expect(f.controller.session.history, hasLength(1));
        final reopened = TableController(repository: f.repository);
        addTearDown(reopened.dispose);
        await reopened.initialize();
        expect(await reopened.undo(), true);
        expect(reopened.canUndo, false);
        for (final player in reopened.session.players) {
          expect(
            withoutGeneration(player),
            withoutGeneration(before.session.player(player.id)),
          );
        }
      },
    );

    test(
      'combined wipe remove=$remove fails atomically and rejects invalid selections',
      () async {
        final f = TableFixture(populated());
        addTearDown(f.dispose);
        await f.initialize();
        final before = f.controller.state.toJson();
        final stored = f.repository.encoded;
        await expectLater(
          f.board.wipeSelectedEveryone({}),
          throwsArgumentError,
        );
        await expectLater(
          f.board.wipeSelectedEveryone({'wipe_creatures', 'untap'}),
          throwsArgumentError,
        );
        f.repository.failSave = true;
        await expectLater(
          f.board.wipeSelectedEveryone({
            'wipe_creatures',
            'wipe_artifacts',
          }, remove: remove),
          throwsStateError,
        );
        expect(f.controller.state.toJson(), before);
        expect(f.repository.encoded, stored);
      },
    );
  }

  test(
    'all tokens zeroes emblems and lands without deleting their stacks',
    () async {
      final f = TableFixture(populated());
      addTearDown(f.dispose);
      await f.initialize();
      await f.board.wipeSelectedEveryone(
        BoardService.wipeOptions.keys,
        remove: false,
      );
      for (final player in f.controller.session.players) {
        expect(player.tokens, hasLength(5));
        expect(
          player.tokens.every(
            (t) => t.amount == 0 && t.tapped == 0 && t.summoningSick == 0,
          ),
          true,
        );
      }
      expect(f.controller.session.history, hasLength(1));
      expect(await f.controller.undo(), true);
      expect(f.player.tokens.every((t) => t.amount == 3), true);
    },
  );

  testWidgets(
    'wipe categories toggle without mutation; all enables all; zero keeps stacks',
    (tester) async {
      tester.view.physicalSize = const Size(1133, 744);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = TableFixture(populated());
      await f.initialize();
      f.catalog.loaded = true;
      addTearDown(f.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 700,
                child: GameDrawerWorkspace(
                  controller: f.controller,
                  catalog: f.catalog,
                  drawerController: GameDrawerController(),
                  initialPage: WorkspacePage.boardWipes,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = f.controller.state.toJson();
      Finder category(String label) => byControlLabel('Everyone, $label');
      bool selected(String label) =>
          tester.widget<Semantics>(category(label)).properties.selected!;
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('wipe-zero')))
            .onPressed,
        isNull,
      );
      await tap(category('Creatures'));
      await tap(category('Artifacts'));
      expect(selected('Creatures'), true);
      expect(selected('Artifacts'), true);
      await tap(category('Creatures'));
      expect(selected('Creatures'), false);
      expect(selected('Artifacts'), true);
      await tap(category('All tokens'));
      for (final label in BoardService.wipeOptions.values) {
        expect(selected(label), true);
      }
      await tap(category('All tokens'));
      for (final label in BoardService.wipeOptions.values) {
        expect(selected(label), false);
      }
      await tap(category('Creatures'));
      await tap(category('Artifacts'));
      expect(f.controller.state.toJson(), before);
      await tap(find.byKey(const ValueKey('wipe-zero')));
      expect(
        find.text('Set creatures, artifacts to 0 for everyone?'),
        findsOneWidget,
      );
      await tap(find.text('Cancel'));
      expect(selected('Creatures'), true);
      expect(selected('Artifacts'), true);
      expect(f.controller.state.toJson(), before);
      await tap(find.byKey(const ValueKey('wipe-zero')));
      await tap(find.widgetWithText(FilledButton, 'Set to 0'));
      expect(f.player.tokens, hasLength(5));
      expect(f.player.tokens.take(3).every((t) => t.amount == 0), true);
      expect(f.player.tokens.last.amount, 3);
      expect(f.controller.session.history, hasLength(1));
      expect(await f.controller.undo(), true);
      await tester.pumpAndSettle();
      expect(f.player.tokens.every((t) => t.amount == 3), true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('player-modal-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (_captureDirectory == null) return;
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.value}',
      );
      if (await file.exists()) {
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    await Directory(_captureDirectory!).create(recursive: true);
  });

  // Optional captures are Flutter test renderer evidence, not native acceptance.
  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$_captureDirectory/flutter-test-renderer-$name.png',
        ).writeAsBytes(png.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> open(
    WidgetTester tester,
    TableFixture fixture, {
    WorkspacePage page = WorkspacePage.player,
    Size size = const Size(1133, 744),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fixture.catalog.loaded = true;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  fixture.controller,
                  catalog: fixture.catalog,
                  seatId: page == WorkspacePage.dice
                      ? null
                      : fixture.player.seatId,
                  initialPage: page,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close workspace'));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'player panels keep gameplay and contextual setup reachable at $size',
      (tester) async {
        final f = TableFixture();
        await f.initialize();
        addTearDown(f.dispose);
        await open(tester, f, size: size);
        await capture(
          tester,
          'player-life-status-${size.width.toInt()}x${size.height.toInt()}',
        );
        expect(field('Change life by').hitTestable(), findsOneWidget);
        expect(field('Set life total to').hitTestable(), findsOneWidget);
        expect(find.text('Monarch · Off').hitTestable(), findsOneWidget);
        expect(find.text('Summoning sickness').hitTestable(), findsOneWidget);
        // The two fixed panels occupy the same row in both supported orientations.
        expect(
          tester.getTopLeft(find.text('Life · 40')).dy,
          tester.getTopLeft(find.text('Status & trackers')).dy,
        );
        final lifeField = find.byType(TextField).first;
        expect(tester.getSize(lifeField).width, lessThan(430));
        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();
        expect(field('Player name').hitTestable(), findsOneWidget);
        expect(find.text('Search token art').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Commanders'));
        await tester.pumpAndSettle();
        expect(find.text('Add commander').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Saved setups'));
        await tester.pumpAndSettle();
        expect(
          find.text('Save this player’s setup').hitTestable(),
          findsOneWidget,
        );
        expect(find.textContaining('Loading preserves life'), findsOneWidget);
        await tester.tap(find.text('Life & status'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Increase life by 1'));
        await tester.pumpAndSettle();
        expect(f.player.life, 41);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
        await close(tester);
      },
    );
  }

  testWidgets(
    'counter corrections reveal independently, cancel without saving, set and undo exactly',
    (tester) async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await open(tester, f, page: WorkspacePage.counters);
      expect(find.byType(TextField), findsNothing);
      final originalLife = f.player.life;
      for (final counter in ['energy', 'poison', 'experience', 'radiation']) {
        await tester.tap(find.byTooltip('Set $counter total'));
        await tester.pumpAndSettle();
        expect(field('Set total'), findsOneWidget);
        tester.widget<TextField>(field('Set total')).controller!.text = '7';
        await tester.tap(find.byTooltip('Cancel counter correction'));
        await tester.pumpAndSettle();
        expect(f.player.counters[counter] ?? 0, 0);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byTooltip('Set $counter total'));
        await tester.pumpAndSettle();
        tester.widget<TextField>(field('Set total')).controller!.text = '7';
        await tester.tap(find.widgetWithText(OutlinedButton, 'Set'));
        await tester.pumpAndSettle();
        expect(f.player.counters[counter], 7);
        expect(f.player.life, originalLife);
        expect(find.byType(TextField), findsNothing);
        expect(await f.controller.undo(), isTrue);
        await tester.pumpAndSettle();
        expect(f.player.counters[counter] ?? 0, 0);
      }
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'status badges claim monarch atomically and undo restores prior holder',
    (tester) async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      final previous = f.controller.session.players[1].id;
      await f.controller.setMonarch(previous);
      await open(tester, f);
      await tester.tap(find.text('Monarch · Off'));
      await tester.pumpAndSettle();
      expect(f.controller.session.monarchPlayerId, f.playerId);
      expect(find.text('Monarch · On'), findsOneWidget);
      await f.controller.undo();
      await tester.pumpAndSettle();
      expect(f.controller.session.monarchPlayerId, previous);
      expect(find.text('Monarch · Off'), findsOneWidget);
      await tester.tap(find.text('City’s blessing · Off'));
      await tester.pumpAndSettle();
      expect(f.player.citysBlessing, isTrue);
      expect(f.controller.session.players[1].citysBlessing, isFalse);
      expect(find.text('City’s blessing · On'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'same-name self and partner commander trackers keep source identity and life coupling',
    (tester) async {
      final state = TabletState.initial();
      final player = state.session.players.first;
      final other = state.session.players[1];
      state.session.commanders = [
        CommanderSource(
          id: 'self-a',
          ownerPlayerId: player.id,
          name: 'Partner',
        ),
        CommanderSource(
          id: 'self-b',
          ownerPlayerId: player.id,
          name: 'Partner',
        ),
        CommanderSource(
          id: 'other-a',
          ownerPlayerId: other.id,
          name: 'Opponent',
        ),
      ];
      final f = TableFixture(state);
      await f.initialize();
      addTearDown(f.dispose);
      await open(tester, f, page: WorkspacePage.commanderDamage);
      await capture(tester, 'commander-overview-1133x744');
      final first = find.byKey(const ValueKey('commander-tracker-self-a'));
      final partner = find.byKey(const ValueKey('commander-tracker-self-b'));
      final opponent = find.byKey(const ValueKey('commander-tracker-other-a'));
      final firstCard = tester.widget<Card>(first);
      final opponentCard = tester.widget<Card>(opponent);
      expect(
        (firstCard.shape! as RoundedRectangleBorder).side.color,
        Color(f.controller.profile(player.seatId).color),
      );
      expect(
        (opponentCard.shape! as RoundedRectangleBorder).side.color,
        Color(f.controller.profile(other.seatId).color),
      );
      await tester.tap(
        find.descendant(
          of: partner,
          matching: find.byTooltip('Increase Partner commander damage'),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-b'], 1);
      expect(f.player.commanderDamage['self-a'] ?? 0, 0);
      expect(f.player.life, 39);
      await tester.tap(
        find.descendant(
          of: first,
          matching: find.byTooltip('Increase Partner commander damage'),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-a'], 1);
      expect(f.player.life, 38);
      await tester.tap(
        find.descendant(
          of: first,
          matching: find.byTooltip('Decrease Partner commander damage'),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-a'], 0);
      expect(f.player.life, 39);
      await f.controller.undo();
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-a'], 1);
      expect(f.player.life, 38);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'dice fixed options fit and mixed results preserve total at $size',
      (tester) async {
        final f = TableFixture();
        await f.initialize();
        addTearDown(f.dispose);
        await open(tester, f, page: WorkspacePage.dice, size: size);
        for (final die in [4, 6, 8, 10, 12, 20]) {
          expect(find.text('d$die'), findsOneWidget);
          final increase = find.byTooltip('Increase d$die');
          expect(increase.hitTestable(), findsOneWidget);
          expect(tester.getSize(increase).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(increase).height, greaterThanOrEqualTo(48));
        }
        expect(find.text('Roll selected dice').hitTestable(), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        final expectedColumns = size.width > size.height ? 3 : 2;
        final dice = [4, 6, 8, 10, 12, 20];
        expect(
          tester.getTopLeft(find.text('d4')).dy,
          tester.getTopLeft(find.text('d${dice[expectedColumns - 1]}')).dy,
        );
        expect(
          tester.getTopLeft(find.text('d${dice[expectedColumns]}')).dy,
          greaterThan(tester.getTopLeft(find.text('d4')).dy),
        );
        await tester.tap(find.byTooltip('Increase d4'));
        await tester.tap(find.byTooltip('Increase d4'));
        await tester.tap(find.byTooltip('Increase d20'));
        await tester.tap(find.text('Roll selected dice'));
        await tester.pumpAndSettle();
        final results = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('dice-results')),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data!)
            .toList();
        expect(results, hasLength(3));
        expect(results[0], startsWith('2d4: '));
        expect(results[1], startsWith('1d6: '));
        expect(results[2], startsWith('1d20: '));
        var total = 0;
        for (final result in results) {
          final parts = result.split(': ');
          final sides = int.parse(parts.first.split('d').last);
          for (final roll in parts.last.split(' · ').map(int.parse)) {
            expect(roll, inInclusiveRange(1, sides));
            total += roll;
          }
        }
        expect(find.text('Total: $total').hitTestable(), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('dice-results'))).height,
          lessThanOrEqualTo(size.width > size.height ? 120 : 160),
        );
        expect(find.text('Roll selected dice').hitTestable(), findsOneWidget);
        expect(f.controller.session.history, isEmpty);
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'dice-${size.width.toInt()}x${size.height.toInt()}',
        );
        await close(tester);
      },
    );
  }
}

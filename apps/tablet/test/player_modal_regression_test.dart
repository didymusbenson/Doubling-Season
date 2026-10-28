import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/die_outline.dart';
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
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/${font.value}',
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
    int quarterTurns = 0,
    bool asymmetricInsets = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    if (asymmetricInsets) {
      tester.view.padding = const FakeViewPadding(
        left: 44,
        top: 24,
        bottom: 20,
      );
      tester.view.viewPadding = const FakeViewPadding(
        left: 44,
        top: 24,
        bottom: 20,
      );
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
    }
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
                  quarterTurns: quarterTurns,
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
      fixture.repository.failSave = false;
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

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final list = find.byType(ListView).evaluate().isNotEmpty
        ? find.byType(ListView).last
        : find.byType(SingleChildScrollView).last;
    if (target.evaluate().isEmpty) {
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 15 && target.hitTestable().evaluate().isEmpty; i++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
      } else {
        await tester.drag(list, const Offset(0, -180));
      }
      await tester.pumpAndSettle();
    }
  }

  Future<void> enableCounter(WidgetTester tester, String counter) async {
    await reveal(tester, find.text('Add counter'));
    await tester.tap(find.text('Add counter'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Enable $counter'));
    await tester.tap(find.text('Enable $counter'));
    await tester.pumpAndSettle();
  }

  Future<void> undoInHistory(WidgetTester tester, TableFixture fixture) async {
    await close(tester);
    await open(tester, fixture, page: WorkspacePage.history);
    final undo = find.textContaining('Undo latest:');
    await reveal(tester, undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    await close(tester);
  }

  for (var turns = 0; turns < 4; turns++) {
    testWidgets(
      'workspace stays bounded and centered inside safe insets at rotation $turns',
      (tester) async {
        final f = TableFixture();
        await f.initialize();
        addTearDown(f.dispose);
        await open(tester, f, quarterTurns: turns, asymmetricInsets: true);
        final box = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('context-workspace')),
        );
        final rect = MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
        expect(rect.left, greaterThanOrEqualTo(44 + 16 - .01));
        expect(rect.top, greaterThanOrEqualTo(24 + 16 - .01));
        expect(rect.right, lessThanOrEqualTo(1133 - 16 + .01));
        expect(rect.bottom, lessThanOrEqualTo(744 - 20 - 16 + .01));
        expect(box.size.width, lessThanOrEqualTo(720));
        expect(box.size.height, lessThanOrEqualTo(640));
        expect(rect.center.dx, closeTo(44 + (1133 - 44) / 2, .01));
        expect(rect.center.dy, closeTo(24 + (744 - 24 - 20) / 2, .01));
        expect(tester.takeException(), isNull);
        await close(tester);
      },
    );
  }

  testWidgets('Player is distinct and both damage routes include counters', (
    tester,
  ) async {
    final f = TableFixture();
    await f.initialize();
    addTearDown(f.dispose);
    for (final page in [
      WorkspacePage.player,
      WorkspacePage.counters,
      WorkspacePage.commanderDamage,
    ]) {
      await open(tester, f, page: page);
      expect(find.widgetWithText(ChoiceChip, 'Player'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Counters'), findsNothing);
      expect(
        field('Player name'),
        page == WorkspacePage.player ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(
          ValueKey('commander-tracker-default-commander:${f.playerId}'),
        ),
        page != WorkspacePage.player ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Player counters'),
        page != WorkspacePage.player ? findsOneWidget : findsNothing,
      );
      expect(find.byTooltip('Correct life separately'), findsNothing);
      expect(find.text('Correct life'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    }
  });

  for (final size in [const Size(1133, 744), const Size(844, 480)]) {
    testWidgets(
      'failed Close stays open; explicit session draft close reopens and retries at $size',
      (tester) async {
        final f = TableFixture();
        await f.initialize();
        addTearDown(f.dispose);
        await open(tester, f, size: size);
        final original = f.controller.profile(f.player.seatId).name;
        final name = tester.widget<TextField>(field('Player name')).controller!;
        await tester.tap(field('Player name'));
        await tester.pumpAndSettle();
        f.repository.failSave = true;
        name.text = 'Unwritten name';
        await tester.pump();
        await tester.tap(
          find.byTooltip('Close').evaluate().isNotEmpty
              ? find.byTooltip('Close')
              : find.byTooltip('Close workspace'),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close workspace'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(
          find.textContaining('only for this app session'),
          findsOneWidget,
        );
        expect(f.controller.profile(f.player.seatId).name, original);
        expect(
          tester.widget<TextField>(field('Player name')).controller!.text,
          'Unwritten name',
        );
        await tester.tap(find.text('Close and keep draft'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close workspace'), findsNothing);
        expect(f.controller.profile(f.player.seatId).name, original);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('Player name')).controller!.text,
          'Unwritten name',
        );
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        f.repository.failSave = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(f.controller.profile(f.player.seatId).name, 'Unwritten name');
        expect(find.text('Close and keep draft'), findsNothing);
        await close(tester);
        expect(find.byTooltip('Close workspace'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
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
        expect(field('Player name').hitTestable(), findsOneWidget);
        final surface = tester.getSize(
          find.byKey(const ValueKey('context-workspace')),
        );
        expect(surface, Size(size.width == 744 ? 712 : 720, 640));
        await reveal(tester, find.text('Search token art'));
        expect(find.text('Search token art').hitTestable(), findsOneWidget);
        await reveal(tester, find.text('Has partner'));
        expect(find.text('Has partner').hitTestable(), findsOneWidget);
        final saved = find.widgetWithText(OutlinedButton, 'Saved setups');
        await reveal(tester, saved);
        await tester.tap(saved);
        await tester.pumpAndSettle();
        expect(find.text('Save this player’s setup'), findsOneWidget);
        expect(find.textContaining('Loading preserves life'), findsOneWidget);
        expect(find.byTooltip('Back'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(saved.hitTestable(), findsOneWidget); // exact originating scroll
        await close(tester);
        await open(tester, f, page: WorkspacePage.counters, size: size);
        await capture(
          tester,
          'counters-${size.width.toInt()}x${size.height.toInt()}',
        );
        await enableCounter(tester, 'energy');
        await reveal(tester, find.byTooltip('Increase energy'));
        await tester.tap(find.byTooltip('Increase energy'));
        await tester.pumpAndSettle();
        expect(f.player.counters['energy'], 1);
        expect(f.player.life, 40);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
        await close(tester);
      },
    );
  }

  testWidgets(
    'Everyone wipe confirms once, saves all seats and one Undo restores them',
    (tester) async {
      final state = stateWithTokens([sampleToken()]);
      state.session.players[1].tokens.add(sampleToken(id: 'other-token'));
      final f = TableFixture(state);
      await f.initialize();
      addTearDown(f.dispose);
      await open(tester, f, page: WorkspacePage.boardWipes);
      final shell = find.byKey(const ValueKey('context-workspace'));
      final rect = tester.getRect(shell);
      await tester.tap(find.text('Wipe all tokens').first);
      await tester.pumpAndSettle();
      expect(find.text('Wipe all tokens for everyone?'), findsOneWidget);
      await capture(tester, 'everyone-wipe-confirmation');
      expect(tester.getRect(shell), rect);
      expect(f.controller.session.players[0].tokens, isNotEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Wipe all tokens'));
      await tester.pumpAndSettle();
      expect(
        f.controller.session.players.every((player) => player.tokens.isEmpty),
        isTrue,
      );
      expect(f.controller.session.history, hasLength(1));
      expect(find.text('Wipe all tokens').first, findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Board wipes'), findsNothing);
      await undoInHistory(tester, f);
      expect(f.controller.session.players[0].tokens, hasLength(1));
      expect(f.controller.session.players[1].tokens, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty combined popup enables a counter without exposing manual life editing',
    (tester) async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await open(tester, f, page: WorkspacePage.counters);
      expect(f.player.counters.values.every((value) => value == 0), isTrue);
      expect(find.byKey(const ValueKey('commander-workspace')), findsOneWidget);
      expect(field('Set life total to'), findsNothing);
      expect(find.text('Correct life'), findsNothing);
      expect(find.byTooltip('Set energy total'), findsNothing);
      await enableCounter(tester, 'energy');
      expect(f.player.counters['energy'], 0);
      await reveal(tester, find.byTooltip('Set energy total'));
      await tester.tap(find.byTooltip('Set energy total'));
      await tester.pumpAndSettle();
      tester.widget<TextField>(field('Set total')).controller!.text = '27';
      await reveal(tester, find.widgetWithText(OutlinedButton, 'Set'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Set'));
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 27);
      expect(f.player.life, 40);
      expect(find.text('Player counters'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Counters'), findsNothing);
      expect(field('Set life total to'), findsNothing);
      expect(find.text('Correct life'), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

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
        await enableCounter(tester, counter);
        await reveal(tester, find.byTooltip('Set $counter total'));
        await tester.tap(find.byTooltip('Set $counter total'));
        await tester.pumpAndSettle();
        expect(field('Set total'), findsOneWidget);
        tester.widget<TextField>(field('Set total')).controller!.text = '7';
        await reveal(tester, find.byTooltip('Cancel counter correction'));
        await tester.tap(find.byTooltip('Cancel counter correction'));
        await tester.pumpAndSettle();
        expect(f.player.counters[counter] ?? 0, 0);
        expect(find.byType(TextField), findsNothing);
        await reveal(tester, find.byTooltip('Set $counter total'));
        await tester.tap(find.byTooltip('Set $counter total'));
        await tester.pumpAndSettle();
        tester.widget<TextField>(field('Set total')).controller!.text = '7';
        await reveal(tester, find.widgetWithText(OutlinedButton, 'Set'));
        await tester.tap(find.widgetWithText(OutlinedButton, 'Set'));
        await tester.pumpAndSettle();
        expect(f.player.counters[counter], 7);
        expect(f.player.life, originalLife);
        expect(find.byType(TextField), findsNothing);
        await undoInHistory(tester, f);
        expect(f.player.counters[counter] ?? 0, 0);
        await open(tester, f, page: WorkspacePage.counters);
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
      await open(tester, f, page: WorkspacePage.counters);
      await reveal(tester, find.byTooltip('Monarch · Off'));
      await tester.tap(find.byTooltip('Monarch · Off'));
      await tester.pumpAndSettle();
      expect(f.controller.session.monarchPlayerId, f.playerId);
      expect(find.byTooltip('Monarch · On'), findsOneWidget);
      await undoInHistory(tester, f);
      await open(tester, f, page: WorkspacePage.counters);
      expect(f.controller.session.monarchPlayerId, previous);
      expect(find.byTooltip('Monarch · Off'), findsOneWidget);
      await tester.tap(find.byTooltip('City’s blessing · Off'));
      await tester.pumpAndSettle();
      expect(f.player.citysBlessing, isTrue);
      expect(f.controller.session.players[1].citysBlessing, isFalse);
      expect(find.byTooltip('City’s blessing · On'), findsOneWidget);
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
      final selfOwner = tester.widget<DecoratedBox>(
        find.byKey(ValueKey('commander-owner-${player.id}')),
      );
      final opponentOwner = tester.widget<DecoratedBox>(
        find.byKey(ValueKey('commander-owner-${other.id}')),
      );
      expect(
        (selfOwner.decoration as BoxDecoration).border!.top.color,
        Color(f.controller.profile(player.seatId).color).withValues(alpha: .6),
      );
      expect(
        (opponentOwner.decoration as BoxDecoration).border!.top.color,
        Color(f.controller.profile(other.seatId).color).withValues(alpha: .6),
      );
      expect(opponent, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: partner,
          matching: find.byKey(const ValueKey('commander-increase-self-b')),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-b'], 1);
      expect(f.player.commanderDamage['self-a'] ?? 0, 0);
      expect(f.player.life, 39);
      await tester.tap(
        find.descendant(
          of: first,
          matching: find.byKey(const ValueKey('commander-increase-self-a')),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-a'], 1);
      expect(f.player.life, 38);
      await tester.tap(
        find.descendant(
          of: first,
          matching: find.byKey(const ValueKey('commander-decrease-self-a')),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage['self-a'], 0);
      expect(f.player.life, 39);
      await undoInHistory(tester, f);
      await open(tester, f, page: WorkspacePage.commanderDamage);
      expect(f.player.commanderDamage['self-a'], 1);
      expect(f.player.life, 38);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  testWidgets(
    '650x480 dice scrolls controls and all results inside unchanged shell',
    (tester) async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await open(
        tester,
        f,
        page: WorkspacePage.dice,
        size: const Size(650, 480),
      );
      final shell = find.byKey(const ValueKey('context-workspace'));
      final rect = tester.getRect(shell);
      expect(rect, const Rect.fromLTWH(16, 16, 618, 448));
      Future<void> reach(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        expect(tester.getRect(shell), rect);
      }

      for (final die in [4, 6, 8, 10, 12, 20]) {
        final increase = find.byTooltip('Increase d$die');
        await reach(increase);
        expect(tester.getSize(increase).height, greaterThanOrEqualTo(48));
        await tester.tap(increase);
        await tester.pumpAndSettle();
      }
      final roll = find.byKey(const ValueKey('dice-roll-button'));
      await reach(roll);
      await tester.tap(roll);
      await tester.pumpAndSettle();
      final results = tester
          .widgetList<DieOutline>(
            find.descendant(
              of: find.byKey(const ValueKey('dice-results')),
              matching: find.byType(DieOutline),
            ),
          )
          .toList();
      expect(results, hasLength(7)); // One of each plus the default d6.
      var total = 0;
      for (final die in [4, 6, 8, 10, 12, 20]) {
        final count = die == 6 ? 2 : 1;
        expect(
          results.where((result) => result.sides == die),
          hasLength(count),
        );
        for (var index = 0; index < count; index++) {
          final face = find.byKey(ValueKey('dice-result-d$die-$index'));
          await reach(face);
          final result = tester.widget<DieOutline>(face);
          expect(result.value, inInclusiveRange(1, die));
          total += result.value;
        }
      }
      await reach(find.byKey(const ValueKey('dice-summary')));
      expect(find.text('Total: $total'), findsOneWidget);
      final reroll = find.byKey(const ValueKey('dice-reroll-button'));
      await reach(reroll);
      expect(tester.getSize(reroll).height, greaterThanOrEqualTo(48));
      await tester.tap(reroll);
      await tester.pumpAndSettle();
      expect(f.controller.session.history, isEmpty);
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
          expect(find.byKey(ValueKey('dice-count-d$die')), findsOneWidget);
          final increase = find.byTooltip('Increase d$die');
          expect(increase.hitTestable(), findsOneWidget);
          expect(tester.getSize(increase).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(increase).height, greaterThanOrEqualTo(48));
        }
        final roll = find.byKey(const ValueKey('dice-roll-button'));
        expect(roll.hitTestable(), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        final shell = find.byKey(const ValueKey('context-workspace'));
        final rect = tester.getRect(shell);
        expect(rect.size, Size(size.width == 744 ? 712 : 720, 640));
        final expectedColumns = rect.width >= 800
            ? 6
            : rect.width >= 400
            ? 3
            : 2;
        final dice = [4, 6, 8, 10, 12, 20];
        Finder count(int die) => find.byKey(ValueKey('dice-count-d$die'));
        expect(
          tester.getTopLeft(count(4)).dy,
          tester.getTopLeft(count(dice[expectedColumns - 1])).dy,
        );
        if (expectedColumns < dice.length) {
          expect(
            tester.getTopLeft(count(dice[expectedColumns])).dy,
            greaterThan(tester.getTopLeft(count(4)).dy),
          );
        }
        await tester.tap(find.byTooltip('Increase d4'));
        await tester.tap(find.byTooltip('Increase d4'));
        await tester.tap(find.byTooltip('Increase d20'));
        await tester.tap(roll);
        await tester.pumpAndSettle();
        final results = tester
            .widgetList<DieOutline>(
              find.descendant(
                of: find.byKey(const ValueKey('dice-results')),
                matching: find.byType(DieOutline),
              ),
            )
            .toList();
        expect(results, hasLength(4));
        expect(results.map((result) => result.sides), [4, 4, 6, 20]);
        var total = 0;
        for (final result in results) {
          final face = find.byKey(result.key!);
          await tester.ensureVisible(face);
          await tester.pumpAndSettle();
          expect(face.hitTestable(), findsOneWidget);
          expect(result.value, inInclusiveRange(1, result.sides));
          total += result.value;
          expect(tester.getRect(shell), rect);
        }
        final summary = find.byKey(const ValueKey('dice-summary'));
        await tester.ensureVisible(summary);
        await tester.pumpAndSettle();
        expect(find.text('Total: $total').hitTestable(), findsOneWidget);
        final reroll = find.byKey(const ValueKey('dice-reroll-button'));
        await tester.ensureVisible(reroll);
        await tester.pumpAndSettle();
        expect(reroll.hitTestable(), findsOneWidget);
        expect(tester.getSize(reroll).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(shell), rect);
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

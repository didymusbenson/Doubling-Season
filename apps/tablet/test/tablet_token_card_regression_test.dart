import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doubling_season/widgets/mana/mana_icons.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  Future<void> showCard(
    WidgetTester tester,
    TableFixture fixture, {
    bool expanded = false,
    double width = 290,
    VoidCallback? onExpand,
    ValueChanged<WorkspacePage>? onOpenDetailed,
    int quarterTurns = 0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1133, 744));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await fixture.initialize();
    var currentExpanded = expanded;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: StatefulBuilder(
                builder: (context, setState) => ListenableBuilder(
                  listenable: fixture.controller,
                  builder: (context, _) => RotatedBox(
                    quarterTurns: quarterTurns,
                    child: TabletTokenCard(
                      token: fixture.token('source'),
                      player: fixture.player,
                      board: fixture.board,
                      playerName: 'Player 1',
                      quarterTurns: quarterTurns,
                      expanded: currentExpanded,
                      onExpand: () {
                        onExpand?.call();
                        setState(() => currentExpanded = !currentExpanded);
                      },
                      onOpenDetailed: onOpenDetailed ?? (_) {},
                      onInputLock: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
  }

  for (final expanded in [false, true]) {
    testWidgets('name and quantity totals share the first row ($expanded)', (
      tester,
    ) async {
      final fixture = TableFixture(
        stateWithTokens([
          sampleToken(name: 'Elf', amount: 12, tapped: 5, sick: 2),
        ]),
      );
      await showCard(tester, fixture, expanded: expanded);
      final name = tester.getRect(find.text('Elf'));
      final total = tester.getRect(find.text('12'));
      expect(name.overlaps(total), isFalse);
      expect((name.center.dy - total.center.dy).abs(), lessThan(5));
      expect(total.left, greaterThan(name.right));
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long names and large totals remain bounded in a narrow lane', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final fixture = TableFixture(
        stateWithTokens([
          sampleToken(
            name: 'A very long creature token name with many words',
            amount: 999999,
            tapped: 888888,
            sick: 777777,
          ),
        ]),
      );
      await showCard(tester, fixture, width: 220);
      for (final label in [
        '999999 total',
        '111111 ready',
        '888888 tapped',
        '777777 summoning sick',
      ]) {
        final status = find.descendant(
          of: find.byTooltip(
            'Player 1, A very long creature token name with many words, edit total, tapped and summoning sickness',
          ),
          matching: find.bySemanticsLabel(RegExp(RegExp.escape(label))),
        );
        expect(status, findsOneWidget);
        expect(tester.getRect(status).right, lessThanOrEqualTo(220));
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('card taps still expand and collapse without an arrow control', (
    tester,
  ) async {
    final fixture = TableFixture(stateWithTokens([sampleToken()]));
    var expansions = 0;
    await showCard(tester, fixture, onExpand: () => expansions++);
    await tester.tap(find.text('Saproling'));
    await tester.pumpAndSettle();
    expect(expansions, 1);
    expect(find.byTooltip('Choose artwork'), findsOneWidget);
    await tester.tapAt(
      tester.getTopRight(find.byType(TabletTokenCard)) + const Offset(-2, 2),
    );
    await tester.pumpAndSettle();
    expect(expansions, 2);
    expect(find.byTooltip('Choose artwork'), findsNothing);
    expect(fixture.controller.session.history, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty base stats use Mana glyphs and retain inline editing', (
    tester,
  ) async {
    final fixture = TableFixture(
      stateWithTokens([
        sampleToken(name: 'Treasure', pt: '', type: 'Artifact — Treasure'),
      ]),
    );
    await showCard(tester, fixture, expanded: true);
    expect(find.text('P/T'), findsNothing);
    expect(find.byIcon(ManaIcons.power), findsOneWidget);
    expect(find.byIcon(ManaIcons.toughness), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(ManaIcons.power)).icon!.fontFamily,
      'Mana',
    );
    await tester.tap(find.byIcon(ManaIcons.power));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inline:source:pt'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(fixture.token('source').pt, '');
    expect(find.byIcon(ManaIcons.power), findsOneWidget);
    expect(find.byIcon(ManaIcons.toughness), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large totals fit the narrow lane with wide fallback glyphs', (
    tester,
  ) async {
    final fixture = TableFixture(
      stateWithTokens([
        sampleToken(amount: 1000000000, tapped: 888888888, sick: 777777777),
      ]),
    );
    await showCard(tester, fixture, width: 176);
    final total = find.text('1000000000');
    expect(total, findsOneWidget);
    final numberBox = tester.getRect(
      find.ancestor(of: total, matching: find.byType(FittedBox)).first,
    );
    final cardBox = tester.getRect(find.byType(TabletTokenCard));
    expect(numberBox.right, lessThanOrEqualTo(cardBox.right));
    expect(
      find.byTooltip('Add one; hold to add ten').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact direct controls retain holds and clean quick additions',
    (tester) async {
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      var expansions = 0;
      await showCard(tester, fixture, onExpand: () => expansions++);
      final otherPlayer = fixture.controller.session.players[1].toJson();
      final add = find.byTooltip('Add one; hold to add ten');
      await tester.longPress(add);
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 13);
      await tester.tap(find.byTooltip('Tap one; hold to tap all'));
      await tester.pumpAndSettle();
      expect(fixture.token('source').tapped, 2);
      await tester.longPress(find.byTooltip('Untap one; hold to untap all'));
      await tester.pumpAndSettle();
      expect(fixture.token('source').tapped, 0);
      await tester.tap(find.byTooltip('Add +1/+1 counter; hold to add ten'));
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 13);
      expect(fixture.token('source').plusOneCounters, 1);
      expect(fixture.player.tokens.length, 2);
      final clean = fixture.player.tokens.last;
      expect(clean.amount, 1);
      expect(clean.plusOneCounters, 0);
      expect(clean.tapped, 0);
      expect(clean.summoningSick, 1);
      expect(fixture.controller.session.players[1].toJson(), otherPlayer);
      expect(expansions, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    for (final turns in [0, 2]) {
      for (final expanded in [false, true]) {
        testWidgets(
          'token quantity buttons stay inline with distinct compact actions ($platform, $turns, expanded $expanded)',
          (tester) async {
            final fixture = TableFixture(
              stateWithTokens([sampleToken(amount: 20, tapped: 0, sick: 0)]),
            );
            var expansions = 0;
            WorkspacePage? opened;
            await showCard(
              tester,
              fixture,
              expanded: expanded,
              quarterTurns: turns,
              onExpand: () => expansions++,
              onOpenDetailed: (page) => opened = page,
            );
            final otherSeat = fixture.controller.session.players[1].toJson();
            final row = find.byKey(const ValueKey('source-actions'));
            expect(
              find.byKey(const ValueKey('source-quantity-stepper')),
              findsNothing,
            );
            final decrease = find.byKey(
              const ValueKey('source-quantity-decrease'),
            );
            final increase = find.byKey(
              const ValueKey('source-quantity-increase'),
            );
            expect(tester.getSize(decrease), const Size(38, 40));
            expect(tester.getSize(increase), const Size(38, 40));
            expect(
              find.descendant(of: row, matching: decrease),
              findsOneWidget,
            );
            expect(
              find.descendant(of: row, matching: increase),
              findsOneWidget,
            );
            final untap = find.byTooltip('Untap one; hold to untap all');
            expect(tester.getCenter(decrease).dy, tester.getCenter(untap).dy);
            expect(tester.getCenter(increase).dy, tester.getCenter(untap).dy);
            for (final target in [decrease, increase]) {
              final delta = target == decrease ? -1 : 1;
              final size = tester.getSize(target);
              for (final point in [
                const Offset(2, 2),
                Offset(size.width / 2, size.height / 2),
                Offset(size.width - 2, size.height - 2),
              ]) {
                final before = fixture.token('source').amount;
                final box = tester.renderObject<RenderBox>(target);
                await tester.tapAt(box.localToGlobal(point));
                await tester.pumpAndSettle();
                expect(fixture.token('source').amount, before + delta);
              }
            }
            expect(fixture.token('source').amount, 20);
            expect(expansions, 0);
            expect(opened, isNull);
            await tester.tap(find.byTooltip('Tap one; hold to tap all'));
            await tester.pumpAndSettle();
            expect(fixture.token('source').tapped, 1);
            expect(fixture.token('source').amount, 20);
            await tester.tap(
              find.byTooltip(
                'Player 1, Saproling, edit total, tapped and summoning sickness',
              ),
            );
            await tester.pumpAndSettle();
            expect(opened, WorkspacePage.tokenStatus);
            expect(fixture.token('source').amount, 20);
            expect(expansions, 0);
            expect(fixture.controller.session.players[1].toJson(), otherSeat);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }

  testWidgets(
    'token quantity holds remain one-shot and zero taps do not expand',
    (tester) async {
      final fixture = TableFixture(
        stateWithTokens([sampleToken(amount: 3, tapped: 0, sick: 0)]),
      );
      var expansions = 0;
      await showCard(tester, fixture, onExpand: () => expansions++);
      final increase = find.byKey(const ValueKey('source-quantity-increase'));
      final decrease = find.byKey(const ValueKey('source-quantity-decrease'));
      final addBox = tester.renderObject<RenderBox>(increase);
      final addGesture = await tester.startGesture(
        addBox.localToGlobal(const Offset(4, 4)),
      );
      await tester.pump(const Duration(seconds: 2));
      await addGesture.up();
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 13);
      final removeBox = tester.renderObject<RenderBox>(decrease);
      final removeGesture = await tester.startGesture(
        removeBox.localToGlobal(const Offset(4, 4)),
      );
      await tester.pump(const Duration(seconds: 2));
      await removeGesture.up();
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 0);
      final historyAtZero = fixture.controller.session.history.length;
      await tester.tapAt(
        tester
            .renderObject<RenderBox>(decrease)
            .localToGlobal(const Offset(4, 4)),
      );
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 0);
      expect(fixture.controller.session.history.length, historyAtZero);
      expect(expansions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real inline token field shares the keyboard controller and commits scoped text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1133, 744));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      var locked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 290,
                child: ListenableBuilder(
                  listenable: fixture.controller,
                  builder: (context, _) => TabletTokenCard(
                    token: fixture.token('source'),
                    player: fixture.player,
                    board: fixture.board,
                    playerName: 'Player 1',
                    quarterTurns: 0,
                    expanded: true,
                    onExpand: () {},
                    onOpenDetailed: (_) {},
                    onInputLock: (value) => locked = value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final otherSeat = fixture.controller.session.players[1].toJson();
      await tester.tap(find.text('Saproling'));
      await tester.pumpAndSettle();
      expect(locked, isTrue);
      final inline = tester.widget<TextField>(
        find.byKey(const ValueKey('inline:source:name'), skipOffstage: false),
      );
      final keyboard = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(PlayerKeyboardHost),
          matching: find.byType(EditableText),
        ),
      );
      expect(identical(inline.controller, keyboard.controller), isTrue);
      expect(inline.readOnly, isTrue);
      expect(inline.keyboardType, TextInputType.none);
      expect(inline.showCursor, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('z'));
      await tester.pumpAndSettle();
      expect(inline.controller!.text, 'Saprolingz');
      expect(keyboard.controller.selection.extentOffset, 10);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(locked, isFalse);
      expect(fixture.token('source').name, 'Saprolingz');
      expect(fixture.controller.session.players[1].toJson(), otherSeat);
      expect(fixture.controller.session.history.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
  );
}

import 'support/control_finders.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  late TableFixture fixture;

  Future<void> openWorkspace(
    WidgetTester tester,
    WorkspacePage page, {
    Size size = const Size(1133, 744),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fixture.catalog.loaded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  fixture.controller,
                  catalog: fixture.catalog,
                  seatId: fixture.playerId,
                  initialPage: page,
                  itemId: page == WorkspacePage.tokens ? null : 'source',
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
  }

  Future<void> closeWorkspace(WidgetTester tester) async {
    final close = byControlLabel('Close workspace');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close);
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<void> initialize() async {
    fixture = TableFixture(stateWithTokens([sampleToken(plusOne: 2)]));
    await fixture.initialize();
  }

  tearDown(() => fixture.dispose());

  for (final size in [const Size(320, 568), const Size(1133, 744)]) {
    testWidgets(
      'Token search remains usable with separate compact actions at $size',
      (tester) async {
        await initialize();
        await openWorkspace(tester, WorkspacePage.tokens, size: size);
        final search = find.byWidgetPredicate(
          (widget) =>
              widget is PlayerField &&
              widget.label == 'Search tokens, abilities, type, or P/T',
        );
        final searchRect = tester.getRect(search);
        final customRect = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Custom token'),
        );
        expect(searchRect.width, greaterThanOrEqualTo(160));
        if (size.width == 320) {
          expect(customRect.top, greaterThanOrEqualTo(searchRect.bottom));
        } else {
          expect(customRect.center.dy, closeTo(searchRect.center.dy, 2));
        }
        expect(
          searchRect.overlaps(
            tester.getRect(byControlLabel('Close workspace')),
          ),
          isFalse,
        );
        expect(search.hitTestable(), findsOneWidget);
        if (size.width == 320) {
          expect(byControlLabel('Clear token search'), findsNothing);
          tester.widget<PlayerField>(search).controller.text = 'Saproling';
          await tester.pumpAndSettle();
          expect(tester.getSize(search).width, greaterThanOrEqualTo(160));
          expect(byControlLabel('Clear token search'), findsOneWidget);
          await tester.tap(byControlLabel('Clear token search'));
          await tester.pumpAndSettle();
          expect(tester.widget<PlayerField>(search).controller.text, isEmpty);
          expect(byControlLabel('Clear token search'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await closeWorkspace(tester);
      },
    );
  }

  testWidgets('Create exits search only after the save succeeds', (
    tester,
  ) async {
    await initialize();
    final definition = TokenDefinition(
      name: 'UI test Saproling',
      abilities: '',
      pt: '1/1',
      colors: 'G',
      type: 'Creature',
      popularity: 0,
    );
    await fixture.catalog.saveCustom(definition);
    await openWorkspace(tester, WorkspacePage.tokens);
    await tester.tap(find.text('UI test Saproling · 1/1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '3'));
    await tester.pumpAndSettle();
    fixture.repository.failSave = true;
    await tester.tap(find.text('Create tokens'));
    await tester.pumpAndSettle();
    expect(byControlLabel('Close workspace'), findsOneWidget);
    expect(fixture.player.tokens.length, 1);
    fixture.repository.failSave = false;
    await tester.tap(find.text('Create tokens'));
    await tester.pumpAndSettle();
    expect(byControlLabel('Close workspace'), findsNothing);
    expect(fixture.player.tokens.last.name, 'UI test Saproling');
    expect(fixture.player.tokens.last.amount, 3);
    await closeWorkspace(tester);
  });

  testWidgets('Counter number opens exact Set including zero', (tester) async {
    await initialize();
    await openWorkspace(tester, WorkspacePage.tokenCounters);
    await tester.tap(byControlLabel('Edit +1/+1'));
    await tester.pumpAndSettle();
    final field = tester.widget<PlayerField>(
      find.byWidgetPredicate(
        (widget) => widget is PlayerField && widget.label == 'Set +1/+1',
      ),
    );
    field.controller.text = '0';
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(fixture.token('source').plusOneCounters, 0);
    expect(fixture.token('source').amount, 3);
    await closeWorkspace(tester);
  });

  for (final initial in [1000000, 999999999999]) {
    for (final counter in [false, true]) {
      testWidgets(
        'Correct persisted ${counter ? 'counter' : 'total'} $initial above manual-entry bounds',
        (tester) async {
          fixture = TableFixture(
            stateWithTokens([
              sampleToken(amount: initial, counters: {'charge': initial}),
            ]),
          );
          await fixture.initialize();
          final otherSeats = fixture.controller.session.players
              .skip(1)
              .map((player) => player.toJson())
              .toList();
          await openWorkspace(
            tester,
            counter ? WorkspacePage.tokenCounters : WorkspacePage.tokenStatus,
          );
          final label = counter ? 'charge' : 'Total';
          final edit = byControlLabel('Edit $label');
          await tester.ensureVisible(edit);
          await tester.tap(edit);
          await tester.pumpAndSettle();
          final field = tester.widget<PlayerField>(
            find.byWidgetPredicate(
              (widget) => widget is PlayerField && widget.label == 'Set $label',
            ),
          );
          field.controller.text = '7';
          await tester.tap(find.text('Set'));
          await tester.pumpAndSettle();
          final token = fixture.token('source');
          expect(counter ? token.counters['charge'] : token.amount, 7);
          expect(counter ? token.amount : token.counters['charge'], initial);
          expect(fixture.controller.session.history, hasLength(1));
          expect(
            fixture.controller.session.players
                .skip(1)
                .map((player) => player.toJson())
                .toList(),
            otherSeats,
          );
          final reopened = await fixture.repository.open();
          final restored = reopened.state.session
              .player(fixture.playerId)
              .tokens
              .single;
          expect(counter ? restored.counters['charge'] : restored.amount, 7);
          expect(tester.takeException(), isNull);
          await closeWorkspace(tester);
        },
      );
    }
  }

  testWidgets(
    'Total stepper adjusts a large saved total by one without truncation',
    (tester) async {
      fixture = TableFixture(stateWithTokens([sampleToken(amount: 1000001)]));
      await fixture.initialize();
      await openWorkspace(tester, WorkspacePage.tokenStatus);
      await tester.tap(byControlLabel('Decrease Total'));
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 1000000);
      await tester.tap(byControlLabel('Increase Total'));
      await tester.pumpAndSettle();
      expect(fixture.token('source').amount, 1000001);
      expect(tester.takeException(), isNull);
      await closeWorkspace(tester);
    },
  );

  testWidgets('Counter catalog exposes integrated split and add to one', (
    tester,
  ) async {
    await initialize();
    await openWorkspace(tester, WorkspacePage.tokenCounters);
    final search = tester.widget<PlayerField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is PlayerField && widget.label.startsWith('Search counters'),
      ),
    );
    search.controller.text = 'shield';
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Shield'));
    await tester.tap(find.text('Shield'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Split & Add to One'));
    await tester.tap(find.text('Split & Add to One'));
    await tester.pumpAndSettle();
    expect(byControlLabel('Close workspace'), findsNothing);
    expect(fixture.player.tokens.map((token) => token.amount), [2, 1]);
    expect(fixture.player.tokens.first.counters, isEmpty);
    expect(fixture.player.tokens.last.counters['Shield'], 1);
    expect(fixture.player.tokens.last.plusOneCounters, 2);
    expect(fixture.controller.session.history.length, 1);
    await closeWorkspace(tester);
  });

  test(
    'Catalog color filtering retains original exact identity semantics',
    () async {
      await initialize();
      for (final color in ['', 'G', 'GW']) {
        await fixture.catalog.saveCustom(
          TokenDefinition(
            name: 'Test $color',
            abilities: '',
            pt: '1/1',
            colors: color,
            type: 'Creature',
            popularity: 0,
          ),
        );
      }
      expect(fixture.catalog.search('', colors: {'G'}).single.colors, 'G');
      expect(
        fixture.catalog.search('', colors: {'G', 'W'}).single.colors,
        'GW',
      );
      expect(fixture.catalog.search('', colors: {'C'}).single.colors, '');
    },
  );
}

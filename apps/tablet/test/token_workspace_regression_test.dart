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

  final tokenSearch = find.byWidgetPredicate(
    (widget) =>
        widget is PlayerField &&
        widget.label == 'Search tokens, abilities, type, or P/T',
  );
  const customTokenActionKey = ValueKey('custom-token-action');

  for (final size in [
    const Size(320, 568),
    const Size(744, 1133),
    const Size(1133, 744),
  ]) {
    testWidgets(
      'Token search remains usable with separate compact actions at $size',
      (tester) async {
        await initialize();
        await openWorkspace(tester, WorkspacePage.tokens, size: size);
        final search = tokenSearch;
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
        expect(customRect.height, greaterThanOrEqualTo(44));
        expect(searchRect.height, greaterThanOrEqualTo(44));
        expect(byControlLabel('Clear token search'), findsNothing);
        tester.widget<PlayerField>(search).controller.text = 'Saproling';
        await tester.pumpAndSettle();
        expect(tester.getRect(search), searchRect);
        final clear = byControlLabel('Clear token search');
        expect(clear.hitTestable(), findsOneWidget);
        expect(tester.getSize(clear).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(clear).height, greaterThanOrEqualTo(44));
        expect(searchRect.contains(tester.getCenter(clear)), isTrue);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(tester.widget<PlayerField>(search).controller.text, isEmpty);
        expect(clear, findsNothing);
        expect(tester.takeException(), isNull);
        await closeWorkspace(tester);
      },
    );
  }

  for (final size in [
    const Size(744, 1133),
    const Size(1133, 744),
    const Size(844, 390),
  ]) {
    testWidgets('Custom token stays reachable while searching at $size', (
      tester,
    ) async {
      await initialize();
      await openWorkspace(tester, WorkspacePage.tokens, size: size);
      await tester.tap(tokenSearch);
      await tester.pumpAndSettle();
      final short = size.height < 400;
      expect(
        find.byKey(
          ValueKey(
            short ? 'player-focused-keyboard-scroll' : 'player-keyboard-scroll',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('q').hitTestable());
      await tester.pumpAndSettle();
      if (!short) {
        expect(find.textContaining('No matching tokens'), findsOneWidget);
        await tester.tap(byControlLabel('Clear token search'));
        await tester.pumpAndSettle();
        expect(find.text('Done').hitTestable(), findsOneWidget);
        await tester.tap(find.text('q').hitTestable());
        await tester.pumpAndSettle();
      }
      final custom = find.byKey(customTokenActionKey).hitTestable();
      expect(custom, findsOneWidget);
      await tester.tap(custom);
      await tester.pumpAndSettle();
      expect(find.byKey(customTokenActionKey), findsNothing);
      final formHeading = find.text('Custom token');
      expect(formHeading, findsOneWidget);
      final cancel = find.text('Cancel');
      if (cancel.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          cancel,
          100,
          scrollable: find.byType(Scrollable).first,
        );
      } else {
        await tester.ensureVisible(cancel);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.widget<PlayerField>(tokenSearch).controller.text, 'q');
      expect(find.textContaining('No matching tokens'), findsOneWidget);
      expect(fixture.player.tokens.length, 1);
      expect(tester.takeException(), isNull);
      await closeWorkspace(tester);
    });
  }

  testWidgets('Very short compact split still reaches search actions', (
    tester,
  ) async {
    await initialize();
    await openWorkspace(
      tester,
      WorkspacePage.tokens,
      size: const Size(320, 444),
    );
    await tester.tap(tokenSearch);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-keyboard-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final custom = find.byKey(customTokenActionKey);
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    expect(custom.hitTestable(), findsOneWidget);
    await closeWorkspace(tester);
  });

  testWidgets('Phone landscape search retains focus and action above IME', (
    tester,
  ) async {
    await initialize();
    const size = Size(844, 390);
    tester.view.display.size = size;
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.display.reset);
    addTearDown(tester.view.resetViewInsets);
    await openWorkspace(tester, WorkspacePage.tokens, size: size);
    final field = find.descendant(
      of: tokenSearch,
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(field, 'missing');
    await tester.pumpAndSettle();
    final custom = find.byKey(customTokenActionKey);
    expect(custom.hitTestable(), findsOneWidget);
    expect(tester.getRect(custom).bottom, lessThanOrEqualTo(180));
    expect(tester.takeException(), isNull);
    // Hiding the IME leaves the same search value, with no save or form change.
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.widget<PlayerField>(tokenSearch).controller.text, 'missing');
    await closeWorkspace(tester);
  });

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

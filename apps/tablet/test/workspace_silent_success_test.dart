import 'support/control_finders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  late TableFixture fixture;

  setUp(() {
    fixture = TableFixture(stateWithTokens([sampleToken(amount: 3)]));
  });
  tearDown(() => fixture.dispose());

  Future<void> open(WidgetTester tester, WorkspacePage page) async {
    await fixture.initialize();
    fixture.catalog.loaded = true;
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                fixture.controller,
                catalog: fixture.catalog,
                seatId: fixture.playerId,
                initialPage: page,
              ),
              child: const Text('Open workspace'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open workspace'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  void expectSilentSuccess() {
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(MaterialBanner), findsNothing);
    for (final text in [
      'added for',
      'Setup saved to the library.',
      'Setup imported.',
      'Matching token setup imported.',
      'appended to',
      'Setup export completed.',
      'Custom token saved.',
      'Custom rule saved.',
      'Latest action undone.',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('adding a utility changes the board without a success notice', (
    tester,
  ) async {
    await open(tester, WorkspacePage.utilities);
    expect(
      fixture.player.utilities.where((utility) => utility.kind == 'the_ring'),
      isEmpty,
    );
    await tap(tester, find.widgetWithText(ListTile, 'The Ring'));
    final ring = fixture.player.utilities.singleWhere(
      (utility) => utility.kind == 'the_ring',
    );
    expect(ring.visible, isTrue);
    expect(fixture.repository.encoded, contains(ring.id));
    expect(fixture.controller.session.history.last.label, 'Add utility');
    expect(find.byKey(ValueKey('utility-menu-${ring.id}')), findsOneWidget);
    expect(fixture.player.tokens.single.amount, 3);
    expectSilentSuccess();
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('setup save, append and replace show the resulting state only', (
    tester,
  ) async {
    await open(tester, WorkspacePage.presets);
    final name = tester.widget<PlayerField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is PlayerField &&
            widget.label == 'Name for the current setup',
      ),
    );
    name.controller.text = 'Quiet setup';
    await tap(tester, find.text('Save this player’s setup'));
    expect(fixture.controller.state.decks.single['name'], 'Quiet setup');
    expect(fixture.repository.encoded, contains('Quiet setup'));
    expect(fixture.player.tokens.single.amount, 3);
    expectSilentSuccess();

    await tap(tester, find.text('Append'));
    expect(fixture.player.tokens.map((token) => token.amount), [3, 0]);
    expect(
      fixture.controller.session.history.last.label,
      'Append setup: Quiet setup',
    );
    expectSilentSuccess();

    await tap(tester, find.text('Replace board'));
    expect(find.text('Replace Player 1’s setup?'), findsOneWidget);
    await tap(tester, find.text('Replace setup'));
    expect(fixture.player.tokens.single.amount, 0);
    expect(
      fixture.controller.session.history.last.label,
      'Load setup: Quiet setup',
    );
    expect(fixture.controller.state.decks.single['name'], 'Quiet setup');
    expectSilentSuccess();
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
    'failed setup save keeps a contextual error and the unsaved draft',
    (tester) async {
      await open(tester, WorkspacePage.presets);
      final name = tester.widget<PlayerField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is PlayerField &&
              widget.label == 'Name for the current setup',
        ),
      );
      name.controller.text = 'Still here';
      final before = fixture.repository.encoded;
      fixture.repository.failSave = true;
      await tap(tester, find.text('Save this player’s setup'));
      expect(find.textContaining('Simulated storage failure'), findsWidgets);
      expect(name.controller.text, 'Still here');
      expect(fixture.controller.state.decks, isEmpty);
      expect(fixture.repository.encoded, before);
      expectSilentSuccess();
      fixture.repository.failSave = false;
      await tap(tester, find.text('Save this player’s setup'));
      expect(fixture.controller.state.decks.single['name'], 'Still here');
      expect(find.textContaining('Simulated storage failure'), findsNothing);
      expectSilentSuccess();
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, TableFixture fixture) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fixture.catalog.loaded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                fixture.controller,
                catalog: fixture.catalog,
                seatId: fixture.playerId,
                initialPage: WorkspacePage.rules,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets(
    'preset modifiers remain available without advertising custom authoring',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await open(tester, fixture);
      expect(find.text('Your modifier sources'), findsOneWidget);
      expect(find.text('Create a custom rule'), findsNothing);
      expect(find.text('Existing custom effects'), findsNothing);
      expect(find.text('Custom rules'), findsNothing);
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('context-workspace')),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.text('Other players’ global effects'),
        250,
        scrollable: scroll,
      );
      expect(find.text('Create a custom rule'), findsNothing);
      await close(tester);
    },
  );

  testWidgets(
    'saved custom effects stay visible and preserve definitions through toggle, undo, failure and reload',
    (tester) async {
      final state = TabletState.initial();
      final player = state.session.players.first;
      player.rules.add(
        ModifierSource(
          id: 'legacy-custom',
          ownerPlayerId: player.id,
          definitionId: 'custom',
          name: 'Saved multiplier',
          enabled: true,
          count: 1,
          configuration: {
            'triggerType': 'any_token',
            'outcomes': [
              {'outcomeType': 'multiply', 'multiplier': 2},
            ],
            'legacy': 'preserve',
          },
        ),
      );
      final fixture = TableFixture(state);
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final original = jsonEncode(fixture.player.rules.single.toJson());
      await open(tester, fixture);
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('context-workspace')),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.text('Saved multiplier'),
        250,
        scrollable: scroll,
      );
      expect(find.text('Existing custom effects'), findsOneWidget);
      expect(find.text('Edit rule'), findsNothing);
      expect(find.text('Move earlier'), findsNothing);
      expect(find.text('Move later'), findsNothing);
      expect(find.text('Create a custom rule'), findsNothing);
      final toggle = find.ancestor(
        of: find.text('Saved multiplier'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(fixture.player.rules.single.enabled, isFalse);
      expect(fixture.player.rules.single.configuration['legacy'], 'preserve');
      await fixture.controller.undo();
      await tester.pumpAndSettle();
      expect(jsonEncode(fixture.player.rules.single.toJson()), original);
      fixture.repository.failSave = true;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(fixture.player.rules.single.enabled, isTrue);
      expect(fixture.player.rules.single.configuration['legacy'], 'preserve');
      fixture.repository.failSave = false;
      final restored = (await fixture.repository.open()).state;
      expect(
        restored.session.players.first.rules.single.configuration,
        player.rules.single.configuration,
      );
      await close(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

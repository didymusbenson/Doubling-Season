import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/die_outline.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('last actual roll survives reopen and relaunch at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var fixture = TableFixture();
      await fixture.initialize();
      Future<void> mount() async {
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
                    initialPage: WorkspacePage.dice,
                  ),
                  child: const Text('Open dice'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open dice'));
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      int count(int sides) => tester
          .widget<DieOutline>(find.byKey(ValueKey('dice-count-d$sides')))
          .value;
      Future<void> close() => tap(byControlLabel('Close workspace'));
      await mount();
      expect(count(6), 1);
      final fresh = fixture.repository.encoded;
      await tap(byControlLabel('Increase d4'));
      await close();
      expect(fixture.repository.encoded, fresh);
      await tap(find.text('Open dice'));
      expect(count(4), 0);
      await tap(byControlLabel('Increase d4'));
      await tap(byControlLabel('Increase d4'));
      await tap(byControlLabel('Increase d20'));
      await tap(find.byKey(const ValueKey('dice-roll-button')));
      final remembered = {'4': 2, '6': 1, '8': 0, '10': 0, '12': 0, '20': 1};
      expect(fixture.controller.state.settings['lastRolledDice'], remembered);
      expect(fixture.controller.session.history, isEmpty);
      await close();
      await tap(find.text('Open dice'));
      expect(count(4), 2);
      expect(count(20), 1);
      await tap(find.byKey(const ValueKey('dice-clear-button')));
      for (final sides in [4, 6, 8, 10, 12, 20]) {
        expect(count(sides), 0);
      }
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('dice-roll-button')),
            )
            .onPressed,
        isNull,
      );
      expect(fixture.controller.state.settings['lastRolledDice'], remembered);
      await close();
      final encoded = fixture.repository.encoded;
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
      fixture = TableFixture(
        TabletState.fromJson(jsonMap(jsonDecode(encoded))),
      );
      await fixture.initialize();
      await mount();
      expect(count(4), 2);
      expect(count(6), 1);
      expect(count(20), 1);
      expect(tester.takeException(), isNull);
      await tap(find.byKey(const ValueKey('dice-clear-button')));
      await tap(byControlLabel('Increase d8'));
      fixture.repository.failSave = true;
      await tap(find.byKey(const ValueKey('dice-roll-button')));
      expect(fixture.controller.state.settings['lastRolledDice'], remembered);
      expect(find.byKey(const ValueKey('dice-result-d8-0')), findsNothing);
      await close();
      fixture.repository.failSave = false;
      await tap(find.text('Open dice'));
      expect(count(4), 2);
      await tap(find.byKey(const ValueKey('dice-clear-button')));
      await tap(byControlLabel('Increase d8'));
      await tap(find.byKey(const ValueKey('dice-roll-button')));
      expect(fixture.controller.state.settings['lastRolledDice'], {
        '4': 0,
        '6': 0,
        '8': 1,
        '10': 0,
        '12': 0,
        '20': 0,
      });
      await close();
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
  }
}

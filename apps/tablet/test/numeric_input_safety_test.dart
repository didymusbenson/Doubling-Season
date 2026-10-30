import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/input_validation.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  test('bounded parsing rejects partial, pasted, and overflowing numbers', () {
    for (final text in [
      '',
      ' ',
      '-',
      'text',
      '1.5',
      '1e3',
      '3 tokens',
      '1\n2',
      '-1',
      '1000000',
      '9223372036854775808',
      '99999999999999999999999999999999',
    ]) {
      expect(tryWholeNumber(text, min: 0, max: 999999), isNull, reason: text);
    }
    expect(tryWholeNumber(' 00042 ', min: 0, max: 999999), 42);
    expect(tryWholeNumber('0', min: 0, max: 999999), 0);
    expect(tryWholeNumber('999999', min: 0, max: 999999), 999999);
    expect(tryWholeNumber('-27', min: -100, max: 100), -27);
  });

  test(
    'validation guidance never displays exception wrappers or diagnostics',
    () {
      expect(
        inputErrorMessage(const FormatException('Enter a name.')),
        'Enter a name.',
      );
      expect(
        inputErrorMessage(RangeError('Use a smaller quantity.')),
        'Use a smaller quantity.',
      );
      expect(
        inputErrorMessage(StateError('Your draft is kept.')),
        'Your draft is kept.',
      );
      expect(
        inputErrorMessage(Exception('/private/secret diagnostic')),
        'Your change could not be saved. Please try again.',
      );
    },
  );

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is PlayerField && widget.label == label,
  );

  Future<void> open(
    WidgetTester tester,
    TableFixture fixture,
    WorkspacePage page, {
    String? itemId,
    Size size = const Size(1133, 744),
  }) async {
    tester.view.physicalSize = size;
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
                initialPage: page,
                itemId: itemId,
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
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }

  for (final size in [const Size(390, 844), const Size(1133, 744)]) {
    testWidgets(
      'invalid edits retain legacy utility totals on repeated submit at $size',
      (tester) async {
        final state = stateWithTokens([sampleToken()]);
        state.session.players.first.utilities
                .firstWhere((u) => u.kind == 'storm_count')
                .value =
            1000000;
        final fixture = TableFixture(state);
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final utilityId = fixture.player.utilities
            .firstWhere((u) => u.kind == 'storm_count')
            .id;
        await open(
          tester,
          fixture,
          WorkspacePage.utilities,
          itemId: utilityId,
          size: size,
        );
        final value = tester.widget<PlayerField>(field('Set value')).controller;
        final stored = fixture.repository.encoded;
        final set = find.widgetWithText(OutlinedButton, 'Set value');
        value.text = 'invalid paste';
        for (var attempt = 0; attempt < 3; attempt++) {
          await tester.ensureVisible(set);
          await tester.tap(set);
          await tester.pumpAndSettle();
          expect(value.text, '1000000');
          expect(fixture.repository.encoded, stored);
          expect(
            fixture.player.utilities.firstWhere((u) => u.id == utilityId).value,
            1000000,
          );
        }
        // Explicitly entering a new valid value remains possible.
        value.text = '7';
        await tester.tap(set);
        await tester.pumpAndSettle();
        expect(
          fixture.player.utilities.firstWhere((u) => u.id == utilityId).value,
          7,
        );
        await close(tester);
      },
    );

    testWidgets(
      'bad utility values restore clean state without saving at $size',
      (tester) async {
        final state = stateWithTokens([sampleToken()]);
        state.session.players.first.utilities
                .firstWhere((u) => u.kind == 'storm_count')
                .value =
            7;
        final fixture = TableFixture(state);
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final utilityId = fixture.player.utilities
            .firstWhere((u) => u.kind == 'storm_count')
            .id;
        await open(
          tester,
          fixture,
          WorkspacePage.utilities,
          itemId: utilityId,
          size: size,
        );
        final value = tester.widget<PlayerField>(field('Set value')).controller;
        final stored = fixture.repository.encoded;
        final set = find.widgetWithText(OutlinedButton, 'Set value');
        for (final invalid in [
          '',
          '-',
          'bad paste',
          '1.2',
          '-8',
          '1000000',
          '999999999999999999999999',
        ]) {
          value.text = invalid;
          await tester.ensureVisible(set);
          await tester.tap(set);
          await tester.pumpAndSettle();
          expect(value.text, '7', reason: invalid);
          expect(fixture.repository.encoded, stored, reason: invalid);
          expect(find.textContaining('FormatException'), findsNothing);
          expect(find.textContaining('RangeError'), findsNothing);
          expect(tester.takeException(), isNull);
        }
        value.text = '8';
        await tester.tap(set);
        await tester.pumpAndSettle();
        final saved = fixture.player.toJson();
        final historyLength = fixture.controller.session.history.length;
        await tester.tap(set);
        await tester.pumpAndSettle();
        expect(fixture.player.toJson(), saved);
        expect(fixture.controller.session.history.length, historyLength);
        expect(
          fixture.player.utilities.firstWhere((u) => u.id == utilityId).value,
          8,
        );
        await close(tester);
      },
    );

    testWidgets('invalid inline token corrections preserve quantity at $size', (
      tester,
    ) async {
      final fixture = TableFixture(stateWithTokens([sampleToken(amount: 7)]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await open(
        tester,
        fixture,
        WorkspacePage.tokenStatus,
        itemId: 'source',
        size: size,
      );
      final stored = fixture.repository.encoded;
      for (final invalid in [
        '',
        'bad paste',
        '-1',
        '1000000',
        '999999999999999999999999',
      ]) {
        await tester.tap(byControlLabel('Edit Total'));
        await tester.pumpAndSettle();
        final value = tester.widget<PlayerField>(field('Set Total')).controller;
        value.text = invalid;
        await tester.tap(find.widgetWithText(OutlinedButton, 'Set'));
        await tester.pumpAndSettle();
        expect(value.text, '7', reason: invalid);
        expect(fixture.repository.encoded, stored, reason: invalid);
        expect(fixture.token('source').amount, 7);
        expect(find.textContaining('Exception'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await close(tester);
    });
  }

  testWidgets('invalid starting life aborts reset and restores the original', (
    tester,
  ) async {
    final fixture = TableFixture(stateWithTokens([sampleToken()]));
    await fixture.initialize();
    addTearDown(fixture.dispose);
    await open(tester, fixture, WorkspacePage.reset);
    final value = tester.widget<PlayerField>(field('Starting life')).controller;
    final stored = fixture.repository.encoded;
    value.text = '0';
    await tester.tap(find.text('Reset with current configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive & reset with board'));
    await tester.pumpAndSettle();
    expect(value.text, '40');
    expect(fixture.repository.encoded, stored);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('previous value was restored'), findsOneWidget);
    await close(tester);
  });
}

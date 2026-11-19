import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/input_validation.dart';
import 'package:tripling_table/domain/table_state.dart';
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
    for (final custom in [false, true]) {
      for (final count in [21, 30]) {
        testWidgets(
          '${custom ? 'custom' : 'preset'} modifier $count decrements exactly or stays unchanged at $size',
          (tester) async {
            final state = stateWithTokens([sampleToken()]);
            final player = state.session.players.first;
            player.rules.add(
              ModifierSource(
                id: 'legacy-modifier',
                ownerPlayerId: player.id,
                definitionId: custom ? 'custom' : 'token_doubler',
                name: custom ? 'Legacy custom' : 'Token doubler',
                count: count,
                enabled: true,
                configuration: {
                  'triggerType': 'any_token',
                  'outcomes': [
                    {'outcomeType': 'multiply', 'multiplier': 2},
                  ],
                  'legacyMetadata': 'preserve',
                },
              ),
            );
            final fixture = TableFixture(state);
            await fixture.initialize();
            addTearDown(fixture.dispose);
            await open(tester, fixture, WorkspacePage.rules, size: size);
            final stored = fixture.repository.encoded;
            final source = fixture.player.rules.single.toJson();
            final decrease = byControlLabel(
              custom ? 'Decrease Copies' : 'Decrease Token doubler',
            );
            final scroll = find
                .descendant(
                  of: find.byKey(const ValueKey('context-workspace')),
                  matching: find.byType(Scrollable),
                )
                .last;
            await tester.scrollUntilVisible(decrease, 250, scrollable: scroll);
            await Scrollable.ensureVisible(
              tester.element(decrease),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            expect(decrease.hitTestable(), findsOneWidget);
            await tester.tap(decrease);
            await tester.pumpAndSettle();
            if (count == 21) {
              expect(fixture.player.rules.single.count, 20);
              expect(
                fixture.player.rules.single.configuration,
                source['configuration'],
              );
              expect(await fixture.controller.undo(), isTrue);
              await tester.pumpAndSettle();
              expect(fixture.player.rules.single.toJson(), source);
            } else {
              expect(fixture.repository.encoded, stored);
              expect(fixture.player.rules.single.toJson(), source);
              await tester.ensureVisible(decrease);
              await tester.tap(decrease);
              await tester.pumpAndSettle();
              expect(fixture.repository.encoded, stored);
              expect(find.textContaining('RangeError'), findsNothing);
              // Direct-command failures request one acknowledgement on Close.
              await tester.tap(byControlLabel('Close workspace'));
              await tester.pumpAndSettle();
            }
            await close(tester);
          },
        );
      }
    }

    testWidgets(
      'keyboard-free exact entry protects retained totals, cancels, and accepts the full valid range at $size',
      (tester) async {
        final state = stateWithTokens([sampleToken()]);
        final storm = state.session.players.first.utilities.firstWhere(
          (u) => u.kind == 'storm_count',
        );
        storm.value =
            1000000; // Retained values above the manual limit must not be silently clamped.
        final fixture = TableFixture(state);
        await fixture.initialize();
        addTearDown(fixture.dispose);
        await open(
          tester,
          fixture,
          WorkspacePage.utilities,
          itemId: storm.id,
          size: size,
        );
        final stored = fixture.repository.encoded;
        Future<void> hit(Finder f) async {
          await tester.ensureVisible(f);
          await tester.tap(f);
          await tester.pumpAndSettle();
        }

        Finder digit(int n) => find.byKey(ValueKey('utility-digit-$n'));
        final set = find.text('Set value');
        final apply = find.widgetWithText(FilledButton, 'Apply');
        String draft() => tester
            .widget<Text>(find.byKey(const ValueKey('utility-exact-draft')))
            .data!;
        await hit(set);
        expect(find.byType(EditableText), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.widget<FilledButton>(apply).onPressed, isNull);
        for (int i = 0; i < 6; i++) {
          await hit(digit(9));
        }
        expect(draft(), '999999');
        expect(tester.widget<TextButton>(digit(1)).onPressed, isNull);
        expect(fixture.repository.encoded, stored);
        await hit(find.byTooltip('Delete last digit'));
        expect(draft(), '99999');
        await hit(find.text('Clear'));
        expect(tester.widget<FilledButton>(apply).onPressed, isNull);
        await hit(digit(0));
        await hit(digit(7));
        expect(draft(), '7');
        await hit(find.text('Cancel'));
        expect(fixture.repository.encoded, stored);
        await hit(set);
        for (int i = 0; i < 6; i++) {
          await hit(digit(9));
        }
        await hit(apply);
        expect(
          fixture.player.utilities.firstWhere((u) => u.id == storm.id).value,
          999999,
        );
        expect(find.byType(EditableText), findsNothing);
        await hit(set);
        await hit(digit(0));
        await hit(apply);
        expect(
          fixture.player.utilities.firstWhere((u) => u.id == storm.id).value,
          0,
        );
        expect(tester.takeException(), isNull);
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

  testWidgets('starting life uses bounded choices instead of free text', (
    tester,
  ) async {
    final fixture = TableFixture(stateWithTokens([sampleToken()]));
    await fixture.initialize();
    addTearDown(fixture.dispose);
    await open(tester, fixture, WorkspacePage.reset);
    final stored = fixture.repository.encoded;
    expect(field('Starting life'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('starting-life-dial')), findsOneWidget);
    expect(fixture.repository.encoded, stored);
    expect(find.textContaining('Exception'), findsNothing);
    await close(tester);
  });
}

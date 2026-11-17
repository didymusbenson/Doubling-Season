import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  setUp(() async {
    cache = await Directory.systemTemp.createTemp('utility-feedback-');
    Hive.init(cache.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDown(() async {
    await Hive.close();
    await cache.delete(recursive: true);
  });

  Future<TableFixture> show(
    WidgetTester tester, {
    required bool phone,
    Size? size,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize =
        size ?? (phone ? const Size(390, 844) : const Size(744, 1133));
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    for (final player in state.session.players) {
      player.utilities = [
        UtilityState(
          id: 'krenko-${player.id}',
          name: 'Krenko, Mob Boss',
          kind: 'krenko_mob_boss',
          description: 'Nontoken goblins you control',
          value: 7,
          configuration: {'tapIncrement': 1, 'hasAction': true},
        ),
        if (phone)
          UtilityState(
            id: 'squirrel-${player.id}',
            name: 'The Unbeatable Squirrel Girl',
            kind: 'the_unbeatable_squirrel_girl',
            description:
                'Nontoken Squirrels you control (including Squirrel Girl)',
            value: 2,
            configuration: {'tapIncrement': 1, 'hasAction': true},
          ),
        UtilityState(
          id: 'hidden-${player.id}',
          name: 'Retained hidden counter',
          kind: 'custom_tracker',
          description: 'Keep these exact values',
          visible: false,
          value: 37,
          defaultValue: 4,
          colors: 'BG',
          configuration: {'tapIncrement': 3},
        ),
      ];
    }
    final f = TableFixture(state);
    await f.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: TableScreen(
          controller: f.controller,
          enablePhonePresentation: phone,
          compactPlayerOne: phone,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return f;
  }

  for (final phone in [true, false]) {
    testWidgets(
      'utility labels, details and dismiss semantics in ${phone ? 'phone' : 'four-player'} mode',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final f = await show(tester, phone: phone);
        final visibleIds = phone
            ? [f.playerId]
            : f.controller.session.players.map((p) => p.id).toList();
        for (final id in visibleIds) {
          final description = find.byKey(
            ValueKey('utility-description-krenko-$id'),
          );
          expect(description.hitTestable(), findsOneWidget);
          final text = tester.widget<Text>(description);
          expect(text.data, 'Nontoken goblins you control');
          expect(text.maxLines, isNull);
          final row = find.byKey(ValueKey('swipe-utility-krenko-$id'));
          final dismissSemantics = find
              .ancestor(
                of: row,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.onDismiss != null,
                ),
              )
              .first;
          expect(
            tester.getSemantics(dismissSemantics).label,
            contains('Krenko, Mob Boss'),
          );
          expect(
            tester
                .getSemantics(dismissSemantics)
                .getSemanticsData()
                .hasAction(SemanticsAction.dismiss),
            isTrue,
          );
          expect(
            find.byKey(ValueKey('remove-utility-krenko-$id')),
            findsNothing,
          );
          await tester.tap(find.byKey(ValueKey('utility-details-krenko-$id')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('utility-detail-krenko_mob_boss')),
            findsOneWidget,
          );
          await tester.tap(byControlLabel('Close workspace'));
          await tester.pumpAndSettle();
        }
        if (phone) {
          expect(
            find
                .text(
                  'Nontoken Squirrels you control (including Squirrel Girl)',
                )
                .hitTestable(),
            findsOneWidget,
          );
        }
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'phone Utilities opens management when populated and restores hidden values',
    (tester) async {
      final f = await show(tester, phone: true);
      final hidden = f.player.utilities.last;
      final original = hidden.toJson();
      await tester.tap(find.byKey(const ValueKey('phone-action-utilities')));
      await tester.pumpAndSettle();
      expect(find.text('Add a utility'), findsOneWidget);
      final hiddenMenu = find.byKey(ValueKey('utility-menu-${hidden.id}'));
      await tester.ensureVisible(hiddenMenu);
      await tester.tap(hiddenMenu);
      await tester.pumpAndSettle();
      expect(
        find.text('Hidden from the board. Its values are still saved.'),
        findsOneWidget,
      );
      await tester.tap(byControlLabel('Restore to board'));
      await tester.pumpAndSettle();
      final restored = f.player.utilities
          .singleWhere((u) => u.id == hidden.id)
          .toJson();
      expect(restored, {...original, 'visible': true});
      expect(f.controller.session.history.last.label, 'Show utility');
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone swipe preserves other utilities and History restores exact values',
    (tester) async {
      final f = await show(tester, phone: true);
      final before = f.player.utilities.map((u) => u.toJson()).toList();
      final row = find.byKey(ValueKey('swipe-utility-krenko-${f.playerId}'));
      await tester.drag(row, Offset(-tester.getSize(row).width * .8, 0));
      await tester.pumpAndSettle();
      expect(
        f.player.utilities.map((u) => u.toJson()).toList(),
        before.skip(1).toList(),
      );
      expect(f.controller.session.history.last.label, 'Remove utility');
      expect(await f.controller.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(f.player.utilities.map((u) => u.toJson()).toList(), before);
      f.repository.failSave = true;
      await tester.drag(row, Offset(-tester.getSize(row).width * .8, 0));
      await tester.pumpAndSettle();
      expect(f.player.utilities.map((u) => u.toJson()).toList(), before);
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('critical labels wrap at larger phone text size', (tester) async {
    await show(tester, phone: true, size: const Size(320, 700), scale: 1.5);
    final name = find.text('The Unbeatable Squirrel Girl');
    await tester.ensureVisible(name);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(name).maxLines, isNull);
    final description = find.text(
      'Nontoken Squirrels you control (including Squirrel Girl)',
    );
    await tester.ensureVisible(description);
    await tester.pumpAndSettle();
    expect(description.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

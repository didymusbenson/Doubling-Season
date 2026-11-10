import 'dart:io';

import 'package:doubling_season/models/toggle_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/ui/table_screen.dart';

import 'legacy_semantic_mapping_test.dart' as models;
import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy-interaction-');
    Hive.init(directory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final phone in [true, false]) {
    testWidgets(
      'imported one-shot holds and toggle descriptions survive in phone=$phone',
      (tester) async {
        final tracker = models.tracker('life_total')
          ..name = 'Legacy counter'
          ..currentValue = 10
          ..tapIncrement = 2
          ..longPressIncrement = 7;
        final toggle = ToggleWidget(
          widgetId: 'toggle',
          name: 'Legacy status',
          isActive: false,
          colorIdentity: '',
          order: 3,
          createdAt: models.instant,
          onDescription: 'Original active description',
          offDescription: 'Original inactive description',
        );
        final plan = LegacyMigrationConverter().convert(
          models.captureModels(trackers: {1: tracker}, toggles: {2: toggle}),
        );
        expect(plan.blockers, isEmpty);
        final f = TableFixture(plan.state);
        await f.initialize();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone
            ? const Size(390, 844)
            : const Size(1133, 744);
        addTearDown(tester.view.reset);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          f.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: TableScreen(
              controller: f.controller,
              enablePhonePresentation: phone,
              compactPlayerOne: phone,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await showAdaptiveUtilities(tester, playerId: f.playerId);
        final increase = byControlLabel('Increase Legacy counter');
        expect(increase.hitTestable(), findsOneWidget);
        await tester.tap(increase);
        await tester.pumpAndSettle();
        expect(f.player.utilities.first.value, 12);
        final gesture = await tester.startGesture(tester.getCenter(increase));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 3));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          f.player.utilities.first.value,
          19,
          reason:
              'One original long-press step, no acceleration or repeated writes.',
        );
        expect(
          f.player.life,
          40,
          reason:
              'Editable names and built-in origins do not create canonical bindings.',
        );
        expect(find.text('Original inactive description'), findsOneWidget);
        final toggleId = f.player.utilities.last.id;
        await f.board.toggleUtility(f.playerId, toggleId);
        await tester.pumpAndSettle();
        expect(find.text('Original active description'), findsOneWidget);
        expect(find.text('Original inactive description'), findsNothing);
        await f.controller.undo();
        await tester.pumpAndSettle();
        expect(find.text('Original inactive description'), findsOneWidget);

        // Management uses the same original tap/hold amounts as the board.
        final trackerId = f.player.utilities.first.id;
        await tester.tap(find.byKey(ValueKey('utility-details-$trackerId')));
        await tester.pumpAndSettle();
        final detailIncrease = byControlLabel('Increase Value');
        await tester.ensureVisible(detailIncrease);
        await tester.pumpAndSettle();
        final detailGesture = await tester.startGesture(
          tester.getCenter(detailIncrease),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 3));
        await detailGesture.up();
        await tester.pumpAndSettle();
        expect(f.player.utilities.first.value, 26);
        await tester.tap(byControlLabel('Close workspace'));
        await tester.pumpAndSettle();
      },
    );
  }
}

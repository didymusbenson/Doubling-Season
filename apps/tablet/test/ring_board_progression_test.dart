import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/ring_service.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('ring-board-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets('board temptation needs no modal, token or name at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final state = TabletState.initial();
      state.session.players.first.utilities.clear();
      final fixture = TableFixture(state);
      await fixture.initialize();
      fixture.catalog.loaded = true;
      await fixture.board.addUtility(fixture.playerId, RingService.kind);
      final utilityId = fixture.player.utilities.single.id;
      UtilityState utility() => fixture.player.utilities.single;
      utility().artworkUrl = null;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: fixture.controller),
        ),
      );
      await tester.pumpAndSettle();
      final life = fixture.player.life;
      final history = fixture.controller.session.history.length;
      final tempt = find.byKey(ValueKey('ring-tempt-$utilityId'));
      await tester.ensureVisible(tempt);
      await tester.pumpAndSettle();
      expect(tempt.hitTestable(), findsOneWidget);
      await tester.tap(tempt);
      await tester.pumpAndSettle();
      expect(utility().value, 1);
      expect(RingService.bearer(utility()), isEmpty);
      expect(fixture.player.tokens, isEmpty);
      expect(fixture.player.life, life);
      expect(fixture.controller.session.history.length, history + 1);
      expect(find.byKey(const ValueKey('context-workspace')), findsNothing);
      expect(
        find.byKey(const ValueKey('utility-detail-the_ring')),
        findsNothing,
      );
      expect(
        find.text('Name your Ring-bearer or choose No creatures.'),
        findsNothing,
      );

      await RingService(fixture.controller).correct(
        fixture.playerId,
        utilityId,
        temptations: 1,
        bearer: 'Physical creature',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(tempt);
      await tester.pumpAndSettle();
      await tester.tap(tempt);
      await tester.pumpAndSettle();
      expect(utility().value, 2);
      expect(RingService.bearer(utility()), 'Physical creature');
      expect(fixture.player.tokens, isEmpty);
      expect(find.byKey(const ValueKey('context-workspace')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

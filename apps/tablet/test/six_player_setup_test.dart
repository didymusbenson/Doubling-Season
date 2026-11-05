import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final count in [5, 6]) {
    for (final width in [300.0, 440.0]) {
      testWidgets(
        '$count-player setup fits $width drawer and starts the game',
        (tester) async {
          final f = TableFixture();
          await f.initialize();
          f.catalog.loaded = true;
          addTearDown(f.dispose);
          tester.view.physicalSize = const Size(1133, 744);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: tableTheme(Brightness.dark),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: 700,
                    child: GameDrawerWorkspace(
                      controller: f.controller,
                      catalog: f.catalog,
                      drawerController: GameDrawerController(),
                      initialPage: WorkspacePage.reset,
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final choice in [2, 3, 4, 5, 6]) {
            final target = byControlLabel('$choice players');
            expect(target, findsOneWidget);
            expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
          }
          await tester.tap(byControlLabel('$count players'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Semantics>(byControlLabel('$count players'))
                .properties
                .selected,
            isTrue,
          );
          expect(find.byKey(const ValueKey('reset-empty-seat')), findsNothing);
          expect(f.controller.session.players, hasLength(4));
          await tester.ensureVisible(find.text('Keep seats'));
          await tester.tap(find.text('Keep seats'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Start game'));
          await tester.tap(find.text('Start game'));
          await tester.pumpAndSettle();
          expect(f.controller.session.players, hasLength(count));
          expect(f.controller.state.archives, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

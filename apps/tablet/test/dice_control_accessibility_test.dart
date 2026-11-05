import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/die_outline.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

double contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [248.0, 300.0, 440.0, 760.0]) {
      testWidgets('dice buttons are clear and usable at $width $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = TableFixture();
        await fixture.initialize();
        fixture.catalog.loaded = true;
        addTearDown(fixture.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: tableTheme(brightness),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: 700,
                  child: GameDrawerWorkspace(
                    controller: fixture.controller,
                    catalog: fixture.catalog,
                    drawerController: GameDrawerController(),
                    initialPage: WorkspacePage.dice,
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scheme = tableTheme(brightness).colorScheme;
        for (final sides in [4, 6, 8, 10, 12, 20]) {
          for (final increase in [false, true]) {
            final action = byControlLabel(
              '${increase ? 'Increase' : 'Decrease'} d$sides',
            );
            final bounds = tester.getSize(action);
            expect(bounds.width, greaterThanOrEqualTo(48));
            expect(bounds.height, greaterThanOrEqualTo(48));
            final surface = tester.widget<Material>(
              find.byKey(
                ValueKey('dice-${increase ? 'increase' : 'decrease'}-d$sides'),
              ),
            );
            final enabled = increase || sides == 6;
            expect(
              surface.color,
              enabled ? scheme.primary : scheme.surfaceContainerHighest,
            );
            final icon = tester.widget<Icon>(
              find.descendant(of: action, matching: find.byType(Icon)),
            );
            expect(icon.size, 28);
            expect(
              contrast(icon.color!, surface.color!),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              tester.widget<Semantics>(action).properties.enabled,
              enabled,
            );
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            expect(action.hitTestable(), findsOneWidget);
          }
        }
        final plus = byControlLabel('Increase d4');
        final minus = byControlLabel('Decrease d4');
        await tester.ensureVisible(plus);
        await tester.pumpAndSettle();
        expect(tester.getRect(plus).left - tester.getRect(minus).right, 8);
        await tester.tap(minus);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DieOutline>(find.byKey(const ValueKey('dice-count-d4')))
              .value,
          0,
        );
        await tester.tap(plus);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DieOutline>(find.byKey(const ValueKey('dice-count-d4')))
              .value,
          1,
        );
        expect(
          tester
              .widget<Material>(find.byKey(const ValueKey('dice-decrease-d4')))
              .color,
          scheme.primary,
        );
        await tester.tap(minus);
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(minus).properties.enabled, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

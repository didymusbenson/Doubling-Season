import 'support/control_finders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/ui/support_sheet.dart';
import 'package:tripling_table/ui/table_theme.dart';

void main() {
  for (var turns = 0; turns < 4; turns++) {
    testWidgets('support shell fits safe viewport at rotation $turns', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1133, 744);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        left: 44,
        top: 24,
        bottom: 20,
      );
      addTearDown(tester.view.reset);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  opened++;
                  showTableSupport(context, quarterTurns: turns);
                },
                child: const SizedBox.expand(child: Text('Open support')),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();
      final box = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('table-modal-surface')),
      );
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      expect(
        box.size,
        turns.isOdd ? const Size(668, 640) : const Size(720, 640),
      );
      expect(rect.left, greaterThanOrEqualTo(44 + 16 - .01));
      expect(rect.right, lessThanOrEqualTo(1133 - 16 + .01));
      expect(rect.top, greaterThanOrEqualTo(24 + 16 - .01));
      expect(rect.bottom, lessThanOrEqualTo(744 - 20 - 16 + .01));
      expect(rect.center.dx, closeTo((44 + 1133) / 2, .001));
      expect(rect.center.dy, closeTo((24 + 744 - 20) / 2, .001));
      final close = byControlLabel('Close support');
      expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(44));
      expect(close.hitTestable(), findsOneWidget);
      expect(find.textContaining('Support is optional'), findsOneWidget);
      expect(
        find.textContaining('Support purchases aren’t available'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(byControlLabel('Close support'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}

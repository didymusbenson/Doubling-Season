import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/ui/support_sheet.dart';

void main() {
  for (var turns = 0; turns < 4; turns++) {
    testWidgets('support shell centers in full viewport at rotation $turns', (
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
      expect(rect.width, closeTo(1133 * .75, .01));
      expect(rect.height, closeTo(744 * .75, .01));
      expect(rect.center.dx, closeTo(1133 / 2, .001));
      expect(rect.center.dy, closeTo(744 / 2, .001));
      expect(find.textContaining('Support is optional'), findsOneWidget);
      expect(
        find.textContaining('Support purchases aren’t available'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byTooltip('Close support'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}

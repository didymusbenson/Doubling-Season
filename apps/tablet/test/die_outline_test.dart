import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/die_outline.dart';
import 'package:tripling_table/ui/table_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (await file.exists()) {
        await (FontLoader(
          'sans-serif',
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  for (final brightness in Brightness.values) {
    test('text and outer outlines meet contrast in $brightness', () {
      final theme = tableTheme(brightness);
      final scheme = theme.colorScheme;
      for (final surface in [
        theme.scaffoldBackgroundColor,
        scheme.surface,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ]) {
        expect(contrast(scheme.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(3),
        );
        expect(contrast(scheme.primary, surface), greaterThanOrEqualTo(3));
      }
    });
    testWidgets(
      'all dice render readable zero and selected results in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(700, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = ValueKey('dice-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: tableTheme(brightness),
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final sides in [4, 6, 8, 10, 12, 20])
                            DieOutline(
                              sides: sides,
                              value: 0,
                              semanticsLabel: 'D$sides quantity 0',
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final sides in [4, 6, 8, 10, 12, 20])
                            DieOutline(
                              sides: sides,
                              value: sides,
                              selected: true,
                              semanticsLabel: 'D$sides result $sides',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final sides in [4, 6, 8, 10, 12, 20]) {
          expect(find.text('D$sides'), findsNWidgets(2));
        }
        expect(find.text('0'), findsNWidgets(6));
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.painter)
            .whereType<DieOutlinePainter>()
            .toList();
        expect(painters, hasLength(12));
        for (final painter in painters) {
          expect(
            contrast(painter.outline, painter.surface),
            greaterThanOrEqualTo(3),
          );
        }
        expect(
          painters.first.outline,
          tableTheme(brightness).colorScheme.onSurfaceVariant,
        );
        expect(
          painters.last.outline,
          tableTheme(brightness).colorScheme.primary,
        );
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['DICE_CAPTURE_DIR'];
        if (directory != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            await Directory(directory).create(recursive: true);
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$directory/die-outlines-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
  testWidgets('quantity and result have one explicit accessible context each', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            container: true,
            label: 'Dice group',
            child: Column(
              children: [
                const Text('Selected dice and results'),
                Row(
                  children: const [
                    DieOutline(
                      sides: 6,
                      value: 2,
                      semanticsLabel: 'D6 quantity 2',
                    ),
                    DieOutline(
                      sides: 6,
                      value: 5,
                      semanticsLabel: 'D6 rolled result 5',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('D6 quantity 2'), findsOneWidget);
    expect(find.bySemanticsLabel('D6 rolled result 5'), findsOneWidget);
    expect(find.bySemanticsLabel('D6'), findsNothing);
    final quantity = tester.getSemantics(find.byType(DieOutline).first);
    final result = tester.getSemantics(find.byType(DieOutline).last);
    expect(quantity.id, isNot(result.id));
    expect(quantity.label, 'D6 quantity 2');
    expect(result.label, 'D6 rolled result 5');
    expect(quantity.rect.width, greaterThan(0));
    expect(quantity.rect.height, greaterThan(0));
    expect(result.rect.width, greaterThan(0));
    expect(result.rect.height, greaterThan(0));
    expect(find.byType(InkWell), findsNothing);
    semantics.dispose();
  });
  testWidgets('large quantities stay within die at increased text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(body: DieOutline(sides: 4, value: 1000)),
      ),
    );
    final number = tester.getRect(find.byKey(const ValueKey('die-value')));
    final shape = tester.getRect(find.byType(CustomPaint).last);
    expect(shape.contains(number.topLeft), isTrue);
    expect(shape.contains(number.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'grouped result hides visual denomination but retains accessible context',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DieOutline(
              sides: 20,
              value: 17,
              showDenomination: false,
              semanticsLabel: 'D20 rolled result 17',
            ),
          ),
        ),
      );
      expect(find.text('D20'), findsNothing);
      expect(find.byKey(const ValueKey('die-denomination')), findsNothing);
      expect(find.text('17'), findsOneWidget);
      expect(find.bySemanticsLabel('D20 rolled result 17'), findsOneWidget);
      expect(tester.getSize(find.byType(DieOutline)), const Size(76, 76));
      semantics.dispose();
    },
  );
}

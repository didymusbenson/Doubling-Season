import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/half_stepper.dart';

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    for (final turns in [0, 2]) {
      testWidgets(
        'full local halves step exactly once at edges and value on $platform turns=$turns',
        (tester) async {
          var value = 20;
          var edits = 0;
          late StateSetter rebuild;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      return RotatedBox(
                        quarterTurns: turns,
                        child: SizedBox(
                          width: 324,
                          child: HalfStepper(
                            label: 'Test quantity',
                            value: '$value',
                            decreaseKey: const ValueKey('decrease'),
                            increaseKey: const ValueKey('increase'),
                            editKey: const ValueKey('edit'),
                            onDecrease: value == 0
                                ? null
                                : () => setState(() => value--),
                            onIncrease: () => setState(() => value++),
                            onEdit: () => edits++,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          final decrease = find.byKey(const ValueKey('decrease'));
          final increase = find.byKey(const ValueKey('increase'));
          final left = tester.renderObject<RenderBox>(decrease);
          final right = tester.renderObject<RenderBox>(increase);
          expect(left.size, const Size(140, 44));
          expect(right.size, const Size(140, 44));
          for (final point in [
            const Offset(1, 1),
            const Offset(139, 1),
            const Offset(2, 42),
            const Offset(138, 42),
            const Offset(70, 22),
          ]) {
            final previous = value;
            await tester.tapAt(left.localToGlobal(point));
            await tester.pump();
            expect(value, previous - 1);
            await tester.tapAt(right.localToGlobal(point));
            await tester.pump();
            expect(value, previous);
          }
          expect(
            edits,
            0,
            reason:
                'Stepping through the displayed value must not invoke editing.',
          );
          await tester.tap(find.byKey(const ValueKey('edit')));
          await tester.pump();
          expect(edits, 1);
          expect(value, 20);
          rebuild(() => value = 0);
          await tester.pump();
          await tester.tapAt(left.localToGlobal(const Offset(138, 22)));
          await tester.pump();
          expect(value, 0);
          expect(edits, 1);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }

  testWidgets(
    'disabled half consumes parent card gesture and exposes disabled semantics',
    (tester) async {
      var parentTaps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkWell(
              onTap: () => parentTaps++,
              child: const SizedBox(
                width: 240,
                height: 44,
                child: HalfStepper(
                  label: 'At zero',
                  value: '0',
                  decreaseKey: ValueKey('zero'),
                  onDecrease: null,
                  onIncrease: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('zero')));
      await tester.pump();
      expect(parentTaps, 0);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('zero'))),
        matchesSemantics(
          label: 'At zero, decrease',
          value: '0',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('repeat hold stops on release, interaction epoch and disposal', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    var epoch = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SizedBox(
                width: 240,
                height: 44,
                child: HalfStepper(
                  label: 'Repeating',
                  value: '0',
                  interactionEpoch: epoch,
                  increaseKey: const ValueKey('hold'),
                  onDecrease: null,
                  onIncrease: () => taps++,
                  onIncreaseHold: () => holds++,
                ),
              );
            },
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(holds, 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(holds, 3);
    rebuild(() => epoch++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(holds, 3);
    await gesture.up();
    await tester.pump();
    expect(taps, 0, reason: 'A hold must not add a trailing tap.');
    final released = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(holds, 4);
    await released.up();
    await tester.pump(const Duration(milliseconds: 900));
    expect(holds, 4);
    final disposed = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(holds, 5);
    await tester.pumpWidget(const SizedBox());
    await disposed.up();
    await tester.pump(const Duration(milliseconds: 900));
    expect(holds, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-shot hold remains one-shot and never taps', (tester) async {
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 44,
            child: HalfStepper(
              label: 'Once',
              value: '0',
              increaseKey: const ValueKey('once'),
              onDecrease: null,
              onIncrease: () => taps++,
              onIncreaseHold: () => holds++,
              holdRepeatInterval: null,
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('once'))),
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pump();
    expect(holds, 1);
    expect(taps, 0);
  });

  testWidgets(
    'pressed ink paints the whole half above artwork without changing its other half',
    (tester) async {
      const boundaryKey = ValueKey('ink-capture');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: Colors.blue,
                  child: SizedBox(
                    width: 240,
                    height: 44,
                    child: HalfStepper(
                      label: 'Ink',
                      value: '',
                      onDecrease: () {},
                      onIncrease: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>> pixel(int x, int y) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset = (y * image.width + x) * 4;
            return bytes.buffer.asUint8List(offset, 4).toList();
          } finally {
            image.dispose();
          }
        }))!;
      }

      final leftBefore = await pixel(110, 4);
      final rightBefore = await pixel(230, 4);
      final box = tester.renderObject<RenderBox>(find.byKey(boundaryKey));
      final gesture = await tester.startGesture(
        box.localToGlobal(const Offset(10, 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      expect(await pixel(110, 4), isNot(leftBefore));
      expect(await pixel(230, 4), rightBefore);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}

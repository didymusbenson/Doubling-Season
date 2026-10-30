import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

const _capture = ValueKey('ink-paint-capture');

class _Pixels {
  final ByteData data;
  final int width, height;
  _Pixels(this.data, this.width, this.height);
}

Future<_Pixels> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = _Pixels(data!, image.width, image.height);
    image.dispose();
    return pixels;
  }))!;
}

Rect _relative(WidgetTester tester, Finder child, Finder ancestor) {
  final box = tester.renderObject<RenderBox>(child);
  return MatrixUtils.transformRect(
    box.getTransformTo(tester.renderObject<RenderBox>(ancestor)),
    Offset.zero & box.size,
  );
}

int _changed(_Pixels before, _Pixels after, Rect area) {
  var changed = 0;
  for (var y = area.top.ceil(); y < area.bottom.floor(); y++) {
    for (var x = area.left.ceil(); x < area.right.floor(); x++) {
      if (x < 0 || y < 0 || x >= before.width || y >= before.height) continue;
      final index = (y * before.width + x) * 4;
      if (before.data.getUint32(index) != after.data.getUint32(index)) {
        changed++;
      }
    }
  }
  return changed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalogDirectory;
  late String artwork;
  setUpAll(() async {
    catalogDirectory = await Directory.systemTemp.createTemp('life-ink-');
    Hive.init(catalogDirectory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFD66A), BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(32, 0, 32, 64),
      Paint()..color = const Color(0xFF183A70),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    artwork =
        'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
    image.dispose();
    picture.dispose();
  });
  tearDownAll(() async {
    await Hive.close();
    await catalogDirectory.delete(recursive: true);
  });

  for (final turns in [0, 1, 2, 3]) {
    for (final mode in ['press', 'hover', 'focus']) {
      testWidgets('$mode ink excludes translucent overlays at rotation $turns', (
        tester,
      ) async {
        var changes = 0;
        final oldStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = oldStrategy,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              splashFactory: InkRipple.splashFactory,
              highlightColor: Colors.red.withValues(alpha: .6),
              hoverColor: Colors.blue.withValues(alpha: .6),
              focusColor: Colors.green.withValues(alpha: .6),
            ),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: _capture,
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: SizedBox(
                      width: 240,
                      height: 140,
                      child: Material(
                        color: Colors.amber,
                        child: Stack(
                          children: [
                            HalfStepper(
                              label: 'Life',
                              value: '40',
                              height: 140,
                              decreaseKey: const ValueKey('decrease'),
                              increaseKey: const ValueKey('increase'),
                              inkExclusions: const [
                                Rect.fromLTWH(20, 90, 80, 44),
                                Rect.fromLTWH(104, 90, 60, 44),
                              ],
                              onDecrease: () => changes--,
                              onIncrease: () => changes++,
                            ),
                            for (final (key, rect) in [
                              ('ledger', const Rect.fromLTWH(20, 90, 80, 44)),
                              ('summary', const Rect.fromLTWH(104, 90, 60, 44)),
                            ])
                              Positioned.fromRect(
                                rect: rect,
                                child: IgnorePointer(
                                  child: ColoredBox(
                                    key: ValueKey(key),
                                    color: Colors.white.withValues(alpha: .25),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final half = find.byKey(const ValueKey('decrease'));
        final halfBox = tester.renderObject<RenderBox>(half);
        final point = halfBox.localToGlobal(const Offset(30, 60));
        final before = await _pixels(tester);
        TestGesture? pointer;
        if (mode == 'press') {
          pointer = await tester.startGesture(point);
        } else if (mode == 'hover') {
          pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
          await pointer.addPointer(location: Offset.zero);
          await pointer.moveTo(point);
        } else {
          final mouseRegion = find
              .descendant(of: half, matching: find.byType(MouseRegion))
              .first;
          Focus.of(tester.element(mouseRegion)).requestFocus();
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        final after = await _pixels(tester);
        for (final key in ['ledger', 'summary']) {
          expect(
            _changed(
              before,
              after,
              _relative(
                tester,
                find.byKey(ValueKey(key)),
                find.byKey(_capture),
              ).deflate(1),
            ),
            0,
            reason: '$mode must leave every overlay interior pixel unchanged.',
          );
        }
        expect(
          _changed(
            before,
            after,
            Offset.zero &
                Size(before.width.toDouble(), before.height.toDouble()),
          ),
          greaterThan(100),
          reason: 'Life feedback must still paint outside the exclusions.',
        );
        if (mode == 'hover') {
          await pointer!.removePointer();
        } else if (mode == 'press') {
          await pointer!.cancel();
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        await tester.pumpAndSettle();
        // Paint holes never change the half's gesture region. These synthetic
        // overlays ignore input, so direct hits through both holes still work.
        for (final point in [
          const Offset(25, 110),
          const Offset(110, 110),
          const Offset(102, 120),
          const Offset(20, 138),
        ]) {
          await tester.tapAt(halfBox.localToGlobal(point));
        }
        expect(changes, -4);
        expect(find.byType(Tooltip), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final seats in [2, 3, 4]) {
      for (final active in [false, true]) {
        testWidgets(
          'actual $seats-seat overlays match ink at $size active=$active',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            final state = TabletState.initial();
            state.session.players = state.session.players.take(seats).toList();
            if (active) {
              for (final player in state.session.players) {
                player.counters = {'energy': 4, 'poison': 2};
                player.citysBlessing = true;
                state.profiles
                        .firstWhere((p) => p.id == player.seatId)
                        .artworkUrl =
                    artwork;
              }
              final owner = state.session.players.last;
              state.session.commanders = [
                CommanderSource(
                  id: 'partner-a',
                  ownerPlayerId: owner.id,
                  name: 'Partner A',
                ),
                CommanderSource(
                  id: 'partner-b',
                  ownerPlayerId: owner.id,
                  name: 'Partner B',
                ),
              ];
            }
            final fixture = TableFixture(state);
            await fixture.initialize();
            await tester.pumpWidget(
              RepaintBoundary(
                key: _capture,
                child: MaterialApp(
                  theme: tableTheme(
                    active ? Brightness.dark : Brightness.light,
                  ),
                  home: TableScreen(controller: fixture.controller),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (active) {
              final context = tester.element(find.byType(TableScreen));
              await tester.runAsync(
                () => Future.wait(
                  tester
                      .widgetList<Image>(find.byType(Image))
                      .map((image) => precacheImage(image.image, context)),
                ),
              );
              await tester.pumpAndSettle();
            }
            for (final player in fixture.controller.session.players) {
              if (active) {
                final context = tester.element(find.byType(TableScreen));
                await tester.runAsync(
                  () => Future.wait(
                    tester
                        .widgetList<Image>(find.byType(Image))
                        .map((image) => precacheImage(image.image, context)),
                  ),
                );
                await tester.pump(const Duration(milliseconds: 200));
                await tester.pumpAndSettle();
              }
              final surface = find.byKey(ValueKey('${player.id}-life-surface'));
              final stepperFinder = find.descendant(
                of: surface,
                matching: find.byType(HalfStepper),
              );
              final stepper = tester.widget<HalfStepper>(stepperFinder);
              final ledger = find.byKey(
                ValueKey('${player.id}-commander-ledger'),
              );
              final summary = find.byKey(
                ValueKey('${player.id}-life-counter-summary'),
              );
              final overlays = [ledger, if (active) summary];
              expect(stepper.inkExclusions.length, overlays.length);
              for (var i = 0; i < overlays.length; i++) {
                expect(
                  stepper.inkExclusions[i],
                  _relative(tester, overlays[i], stepperFinder),
                );
              }
              if (!active) expect(summary, findsNothing);
              final increasing = player.slot.isOdd;
              final expectedLife = increasing ? 41 : 39;
              final half = find.byKey(
                ValueKey(
                  '${player.id}-life-${increasing ? 'increase' : 'decrease'}',
                ),
              );
              final box = tester.renderObject<RenderBox>(half);
              final before = await _pixels(tester);
              final press = await tester.startGesture(
                box.localToGlobal(Offset(10, box.size.height - 3)),
              );
              await tester.pump(const Duration(milliseconds: 100));
              await tester.pump(const Duration(milliseconds: 180));
              final after = await _pixels(tester);
              for (final overlay in overlays) {
                expect(
                  _changed(
                    before,
                    after,
                    _relative(tester, overlay, find.byKey(_capture)).deflate(1),
                  ),
                  0,
                  reason: 'Ink must not alter overlay pixels.',
                );
              }
              expect(
                _changed(
                  before,
                  after,
                  _relative(tester, surface, find.byKey(_capture)),
                ),
                greaterThan(0),
                reason: 'Actual life surface must still show pressed ink.',
              );
              await press.up();
              await tester.pumpAndSettle();
              expect(
                fixture.controller.player(player.id).life,
                expectedLife,
                reason: 'Bottom padding stays inside the life hit region.',
              );
              await tester.tap(ledger);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('commander-workspace')),
                findsOneWidget,
              );
              expect(
                fixture.controller.player(player.id).life,
                expectedLife,
                reason: 'Overlay tap must not also change life.',
              );
              final close = find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.label == 'Close workspace',
                  )
                  .last;
              await tester.tap(close);
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            fixture.dispose();
          },
        );
      }
    }
  }
}

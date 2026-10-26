import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalog;
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('shared-controls-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
      for (final f in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${f.value}',
        );
        await (FontLoader(
          f.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });
  Future<TableFixture> show(
    WidgetTester tester,
    Size size,
    int seats, {
    int empty = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    }
    if (seats == 3) state.session.players.removeAt(empty);
    for (final p in state.session.players) {
      p.tokens = [
        for (var i = 0; i < 4; i++)
          sampleToken(
            id: '${p.id}-$i',
            name: 'Scute Swarm $i',
            abilities:
                'Landfall — Whenever a land you control enters, create a 1/1 green Insect creature token. If you control six or more lands, create a token that is a copy of Scute Swarm instead.',
          ),
      ];
    }
    final f = TableFixture(state);
    await f.initialize();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: f.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    });
    return f;
  }

  Rect localRect(WidgetTester tester, Finder child, Finder ancestor) {
    final box = tester.renderObject<RenderBox>(child);
    final parent = tester.renderObject<RenderBox>(ancestor);
    return MatrixUtils.transformRect(
      box.getTransformTo(parent),
      Offset.zero & box.size,
    );
  }

  for (final size in [
    const Size(744, 1133),
    const Size(1133, 744),
    const Size(1024, 768),
  ]) {
    for (final seats in [2, 3, 4]) {
      for (final empty in seats == 3 ? [0, 1, 2, 3] : [0]) {
        testWidgets(
          '$seats seats empty$empty $size shared clearance and signed delta',
          (tester) async {
            final f = await show(tester, size, seats, empty: empty);
            final hub = find.byKey(const ValueKey('central-game-controls'));
            final table = find.byKey(const ValueKey('table-surface'));
            expect(tester.getRect(hub).center, tester.getRect(table).center);
            final dice = find.byKey(const ValueKey('shared-dice'));
            final day = find.byKey(const ValueKey('shared-day-night'));
            for (final control in [dice, day]) {
              expect(tester.getSize(control), const Size(44, 44));
              expect(control.hitTestable(), findsOneWidget);
              expect(
                tester.getRect(control).overlaps(tester.getRect(hub)),
                isFalse,
              );
            }
            for (final p in f.controller.session.players) {
              final surface = find.byKey(ValueKey('${p.id}-life-surface'));
              final number = find.byKey(ValueKey('${p.id}-life-number'));
              final ledger = find.byKey(ValueKey('${p.id}-commander-ledger'));
              final name = find.byKey(ValueKey('${p.id}-player-name'));
              for (final control in [dice, day]) {
                for (final content in [number, ledger, name]) {
                  expect(
                    tester.getRect(control).overlaps(tester.getRect(content)),
                    isFalse,
                  );
                }
              }
              final signs = find.descendant(
                of: surface,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Icon &&
                      (w.icon == Icons.add || w.icon == Icons.remove),
                ),
              );
              for (final icon in signs.evaluate()) {
                for (final control in [dice, day]) {
                  expect(
                    tester
                        .getRect(find.byWidget(icon.widget))
                        .overlaps(tester.getRect(control)),
                    isFalse,
                  );
                }
              }
              final center = localRect(tester, number, surface).center.dx;
              // Adding shared controls must not push the established life total
              // away from its old center: only the name/ledger footer grows.
              expect(
                localRect(tester, number, surface).center.dy,
                closeTo((tester.getSize(surface).height - 26) / 2 - 14, .01),
              );
              await f.controller.adjustLife(p.id, -1);
              await tester.pump();
              Finder deltaText() => find.descendant(
                of: find.byKey(ValueKey('${p.id}-life-delta')),
                matching: find.byType(Text),
              );
              for (final control in [dice, day]) {
                expect(
                  tester.getRect(deltaText()).overlaps(tester.getRect(control)),
                  isFalse,
                );
              }
              final clipWidget = tester.widget<ClipPath>(
                find.byKey(ValueKey('${p.id}-life-clip')),
              );
              final clip = clipWidget.clipper!.getClip(tester.getSize(surface));
              final deltaBounds = localRect(tester, deltaText(), surface);
              for (final corner in [
                deltaBounds.topLeft,
                deltaBounds.topRight,
                deltaBounds.bottomLeft,
                deltaBounds.bottomRight,
              ]) {
                expect(
                  clip.contains(corner),
                  isTrue,
                  reason:
                      'Delta must be entirely outside shared-control clearance.',
                );
              }

              expect(
                localRect(tester, deltaText(), surface).right,
                lessThanOrEqualTo(localRect(tester, number, surface).left),
              );
              expect(
                localRect(tester, number, surface).center.dx,
                closeTo(center, .01),
              );
              await f.controller.adjustLife(p.id, 2);
              await tester.pump();
              for (final control in [dice, day]) {
                expect(
                  tester.getRect(deltaText()).overlaps(tester.getRect(control)),
                  isFalse,
                );
              }
              expect(
                localRect(tester, deltaText(), surface).left,
                greaterThanOrEqualTo(localRect(tester, number, surface).right),
              );
              expect(
                localRect(tester, number, surface).center.dx,
                closeTo(center, .01),
              );
              expect(
                tester.getRect(deltaText()).overlaps(tester.getRect(ledger)),
                isFalse,
              );
            }
            if (captures != null && empty == 0) {
              await tester.pump();
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('capture')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$captures/shared-$seats-${size.width.toInt()}x${size.height.toInt()}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'Day/Night cycles, hold clears once, undo restores, dice opens directly',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4);
      final day = find.byKey(const ValueKey('shared-day-night'));
      final original = f.controller.session.players.map((p) => p.life).toList();
      for (final expected in ['day', 'night', 'day']) {
        await tester.tap(day);
        await tester.pumpAndSettle();
        expect(f.controller.session.dayNight, expected);
      }
      final before = f.controller.session.history.length;
      await tester.longPress(day);
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'neither');
      expect(f.controller.session.history.length, before + 1);
      await tester.longPress(day);
      await tester.pumpAndSettle();
      expect(f.controller.session.history.length, before + 1);
      await f.controller.undo();
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'day');
      expect(
        f.controller.session.players.map((p) => p.life).toList(),
        original,
      );
      await tester.tap(find.byKey(const ValueKey('shared-dice')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed Day/Night save preserves state and history, then retry works',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4);
      final before = f.controller.session.history.length;
      f.repository.failSave = true;
      await tester.tap(find.byKey(const ValueKey('shared-day-night')));
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'neither');
      expect(f.controller.session.history.length, before);
      expect(f.controller.error, isNotNull);
      f.repository.failSave = false;
      await tester.tap(find.byKey(const ValueKey('shared-day-night')));
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'day');
      final reloaded = await f.repository.open();
      expect(reloaded.state.session.dayNight, 'day');
    },
  );
  testWidgets('rapid Day/Night taps resolve in command order', (tester) async {
    final f = await show(tester, const Size(1133, 744), 4);
    final control = find.byKey(const ValueKey('shared-day-night'));
    final ink = tester.widget<InkWell>(
      find.ancestor(of: control, matching: find.byType(InkWell)).first,
    );
    ink.onTap!();
    ink.onTap!();
    await tester.pumpAndSettle();
    expect(f.controller.session.dayNight, 'night');
    expect(f.controller.session.history.length, 2);
    await f.controller.undo();
    await tester.pumpAndSettle();
    expect(f.controller.session.dayNight, 'day');
  });
  testWidgets(
    'hide utility confirmation uses fixed frame and consumes dismissal',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 2);
      await tester.tap(find.byTooltip('Storm').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide Storm'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('table-modal-surface'))),
        const Size(849.75, 558),
      );
      final lives = f.controller.session.players.map((p) => p.life).toList();
      await tester.tapAt(const Offset(20, 350));
      await tester.pumpAndSettle();
      expect(find.text('Hide Storm?'), findsNothing);
      expect(f.controller.session.players.map((p) => p.life).toList(), lives);
      expect(
        f.controller.session.players.every(
          (p) => p.utilities.firstWhere((u) => u.kind == 'storm_count').visible,
        ),
        isTrue,
      );
    },
  );
}

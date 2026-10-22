import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

// Optional evidence uses the Flutter widget renderer, not a release browser.
final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('capacity-renderer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolatedCatalog;
  setUpAll(() async {
    isolatedCatalog = await Directory.systemTemp.createTemp(
      'tablet-layout-catalog-',
    );
    Hive.init(isolatedCatalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (_captureDirectory != null) {
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.value}',
        );
        if (await file.exists()) {
          await (FontLoader(
            font.key,
          )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
      }
      await Directory(_captureDirectory!).create(recursive: true);
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await isolatedCatalog.delete(recursive: true);
  });

  TabletState tableFor(int seats) {
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    }
    if (seats == 3) state.session.players.removeAt(0);
    return state;
  }

  Future<TableFixture> showTable(
    WidgetTester tester,
    Size size,
    TabletState state,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    // Include iPad safe-area space: fitting only edge-to-edge web content
    // would miss the original mini-landscape clipping regression.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    final fixture = TableFixture(state);
    await fixture.initialize();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: fixture.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        '$seats seats at $size expose every default mana control without scrolling',
        (tester) async {
          final fixture = await showTable(tester, size, tableFor(seats));
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(seats));
          expect(find.text('Mana pool').hitTestable(), findsNWidgets(seats));
          for (final player in fixture.controller.session.players) {
            final name = fixture.controller.profile(player.seatId).name;
            expect(
              find.text(name),
              findsOneWidget,
              reason: 'Seat identity belongs in the life counter.',
            );
            for (final type in PlayerState.manaColors) {
              for (final action in ['add', 'spend']) {
                final target = find.byKey(
                  ValueKey('${player.id}-mana-$type-$action'),
                );
                expect(
                  target.hitTestable(),
                  findsOneWidget,
                  reason:
                      '$name $type $action must be visible without moving the lane.',
                );
                final bounds = tester.getRect(target);
                expect(bounds.top, greaterThanOrEqualTo(24));
                expect(bounds.bottom, lessThanOrEqualTo(size.height - 20));
              }
            }
          }
        },
      );
    }
  }

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final seats in [2, 3, 4]) {
      for (final partners in [false, true]) {
        testWidgets(
          '$seats seats at $size retain default utility capacity with ${partners ? 'partners' : 'one source'}',
          (tester) async {
            final state = tableFor(seats);
            final owners = partners
                ? state.session.players
                : [state.session.players.last];
            state.session.commanders = [
              for (final owner in owners)
                for (var n = 0; n < (partners ? 2 : 1); n++)
                  CommanderSource(
                    id: '${owner.id}-$n',
                    ownerPlayerId: owner.id,
                    name: n == 0 ? 'Partner A' : 'Partner B',
                  ),
            ];
            final fixture = await showTable(tester, size, state);
            for (final player in fixture.controller.session.players) {
              final seat = find.byKey(ValueKey(player.id));
              final life = find.descendant(
                of: seat,
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_LifePanel',
                ),
              );
              final lifeText = find.descendant(
                of: life,
                matching: find.text('40'),
              );
              expect(
                tester.widget<Text>(lifeText).style!.fontSize,
                48,
                reason: 'Commander capacity must preserve life legibility.',
              );
              final utilities = tester.widget<ReorderableListView>(
                find.descendant(
                  of: seat,
                  matching: find.byType(ReorderableListView),
                ),
              );
              expect(
                utilities.scrollController!.position.maxScrollExtent,
                lessThanOrEqualTo(
                  1,
                ), // At most a subpixel decorative border tail.
                reason:
                    'Default Storm and all mana controls must fit with sources.',
              );
              final trackers = find.byKey(
                ValueKey('${player.id}-commander-trackers'),
              );
              final sourceList = tester.widget<ListView>(
                find.descendant(of: trackers, matching: find.byType(ListView)),
              );
              final compact = tester.getSize(trackers).height == 44;
              var sourceIndex = 0;
              Rect screenBounds(Finder finder) {
                final box = tester.renderObject<RenderBox>(finder);
                return Rect.fromPoints(
                  box.localToGlobal(Offset.zero),
                  box.localToGlobal(box.size.bottomRight(Offset.zero)),
                );
              }

              for (final source in fixture.controller.session.commanders) {
                sourceList.controller!.jumpTo(
                  (sourceIndex++ * (compact ? 144.0 : 154.0)).clamp(
                    0,
                    sourceList.controller!.position.maxScrollExtent,
                  ),
                );
                await tester.pumpAndSettle();
                final chip = find.byKey(
                  ValueKey('${player.id}-commander-${source.id}'),
                );
                final chipBounds = screenBounds(chip);
                final viewport = screenBounds(trackers);
                expect(
                  chipBounds.left,
                  greaterThanOrEqualTo(viewport.left - .01),
                );
                expect(
                  chipBounds.right,
                  lessThanOrEqualTo(viewport.right + .01),
                );
                final owner = fixture.controller.session.players.firstWhere(
                  (p) => p.id == source.ownerPlayerId,
                );
                final identity = fixture.controller.profile(owner.seatId);
                final add = find.byTooltip(
                  '${fixture.controller.profile(player.seatId).name}, increase damage from ${source.name} (${identity.name})',
                );
                expect(add.hitTestable(), findsOneWidget);
                expect(tester.getSize(add).width, greaterThanOrEqualTo(44));
                expect(tester.getSize(add).height, greaterThanOrEqualTo(44));
              }
              sourceList.controller!.jumpTo(0);
              await tester.pumpAndSettle();
              for (final color in PlayerState.manaColors) {
                for (final action in ['add', 'spend']) {
                  final control = find.byKey(
                    ValueKey('${player.id}-mana-$color-$action'),
                  );
                  expect(control.hitTestable(), findsOneWidget);
                  final bounds = tester.getRect(control);
                  expect(bounds.top, greaterThanOrEqualTo(24));
                  expect(bounds.bottom, lessThanOrEqualTo(size.height - 20));
                  expect(
                    bounds.height,
                    closeTo(48, .01),
                    reason: 'Mana targets keep their original height.',
                  );
                }
              }
            }
            expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(seats));
            expect(tester.takeException(), isNull);
            if (_captureDirectory != null &&
                partners &&
                (seats != 3 || size.width == 1133)) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(_captureKey),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                try {
                  final png = (await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  ))!;
                  await File(
                    '$_captureDirectory/flutter-test-renderer-capacity-${seats}p-${size.width.toInt()}x${size.height.toInt()}-partners.png',
                  ).writeAsBytes(png.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
          },
        );
      }
    }
  }

  testWidgets(
    'mini landscape mana spending stays on board and preserves other seats',
    (tester) async {
      final fixture = await showTable(
        tester,
        const Size(1133, 744),
        tableFor(4),
      );
      final player = fixture.controller.session.players.first;
      final add = find.byKey(ValueKey('${player.id}-mana-W-add'));
      final spend = find.byKey(ValueKey('${player.id}-mana-W-spend'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 1);
      await tester.longPress(add);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 11);
      await tester.tap(spend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 10);
      await tester.longPress(spend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 0);
      for (final other in fixture.controller.session.players.skip(1)) {
        expect(other.mana['W'] ?? 0, 0);
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portrait Storm uses a named icon and exposes its full title when expanded',
    (tester) async {
      await showTable(tester, const Size(744, 1133), tableFor(4));
      final storm = find.byTooltip('Storm');
      expect(storm.hitTestable(), findsNWidgets(4));
      expect(
        find.descendant(of: storm, matching: find.byIcon(Icons.bolt_outlined)),
        findsNWidgets(4),
      );
      expect(find.text('Storm'), findsNothing);
      await tester.tap(storm.last);
      await tester.pumpAndSettle();
      expect(find.text('Storm').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow portrait lane bounds large utility and mana values', (
    tester,
  ) async {
    final state = tableFor(4);
    for (final player in state.session.players) {
      player.utilities.first.value = 999999;
      player.counters['poison'] = 999999;
      for (final type in PlayerState.manaColors) {
        player.mana[type] = 999999;
      }
    }
    await showTable(tester, const Size(744, 1133), state);
    expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}

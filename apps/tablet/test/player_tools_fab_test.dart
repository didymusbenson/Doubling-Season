import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

final _captureDirectory = Platform.environment['FAB_CAPTURE_DIR'];
const _captureKey = ValueKey('fab-capture');

void main() {
  late Directory catalog;
  setUp(() {
    if (_captureDirectory != null) debugDisableShadows = false;
  });
  tearDown(() => debugDisableShadows = true);
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('player-tools-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (_captureDirectory == null) return;
    await Directory(_captureDirectory!).create(recursive: true);
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
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<TableFixture> mount(
    WidgetTester tester,
    int count,
    Size size, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = TableFixture();
    await fixture.initialize();
    await fixture.controller.resetGame(keepBoard: false, playerCount: count);
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        builder: (context, child) => RepaintBoundary(
          key: _captureKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: TableScreen(controller: fixture.controller),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      if (byControlLabel('Close workspace').evaluate().isNotEmpty) {
        await tester.tap(byControlLabel('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_captureDirectory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final count in [2, 4, 6]) {
    for (final size in [
      const Size(650, 480),
      const Size(1133, 744),
      const Size(744, 1133),
      const Size(1700, 1100),
    ]) {
      testWidgets(
        '$count players $size have anchored player-facing action menus',
        (tester) async {
          final fixture = await mount(tester, count, size);
          for (final player in fixture.controller.session.players) {
            await showAdaptiveUtilities(tester, playerId: player.id);
            final fab = find.byKey(ValueKey('${player.id}-utility-tools'));
            final area = find.byKey(ValueKey('${player.id}-utility-section'));
            final fabBox = tester.renderObject<RenderBox>(fab);
            final areaBox = tester.renderObject<RenderBox>(area);
            final local = fabBox.localToGlobal(Offset.zero, ancestor: areaBox);
            expect(
              local.dx + fabBox.size.width,
              closeTo(areaBox.size.width - 12, .01),
            );
            final fabBounds = tester.getRect(fab);
            final history = fixture.controller.session.history.length;
            await tester.tap(fab);
            await tester.pumpAndSettle();
            expect(find.text('Player tools'), findsNothing);
            expect(
              find.byKey(const ValueKey('context-workspace')),
              findsNothing,
            );
            final utilities = find.byKey(
              ValueKey('${player.id}-manage-utilities'),
            );
            final customize = find.byKey(
              ValueKey('${player.id}-player-details'),
            );
            final close = find.byKey(ValueKey('${player.id}-close-tools-menu'));
            expect(utilities.hitTestable(), findsOneWidget);
            expect(customize.hitTestable(), findsOneWidget);
            expect(close.hitTestable(), findsOneWidget);
            expect(tester.getRect(close).left, closeTo(fabBounds.left, .01));
            expect(tester.getRect(close).top, closeTo(fabBounds.top, .01));
            expect(tester.getRect(close).width, closeTo(fabBounds.width, .01));
            expect(
              tester.getRect(close).height,
              closeTo(fabBounds.height, .01),
            );
            expect(
              tester.getRect(utilities).overlaps(tester.getRect(customize)),
              isFalse,
            );
            expect(tester.getRect(customize).overlaps(fabBounds), isFalse);
            for (final action in [utilities, customize]) {
              final rect = tester.getRect(action);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
              expect(rect.bottom, lessThanOrEqualTo(size.height));
            }
            final labelBox = tester.renderObject<RenderBox>(
              find.text('Player customization'),
            );
            final direction =
                labelBox.localToGlobal(const Offset(10, 0)) -
                labelBox.localToGlobal(Offset.zero);
            final turns = fixture.controller.session.quarterTurnsFor(player);
            expect(direction.dx, turns == 2 ? lessThan(0) : greaterThan(0));
            expect(fab.hitTestable(), findsNothing);
            if (player == fixture.controller.session.players.first) {
              await capture(
                tester,
                'menu-${count}p-${size.width.toInt()}x${size.height.toInt()}',
              );
            } else if (count == 4 &&
                size == const Size(1133, 744) &&
                turns == 2) {
              await capture(tester, 'menu-top-facing-${player.seatId}');
            }
            // Dismiss at a real gameplay target. It must not alter game state.
            final blocked = [
              tester.getRect(utilities),
              tester.getRect(customize),
              tester.getRect(close),
            ];
            final lifeTargets = [
              for (final seat in fixture.controller.session.players)
                for (final direction in ['increase', 'decrease'])
                  tester.getRect(
                    find.byKey(ValueKey('${seat.id}-life-$direction')),
                  ),
            ];
            final outside = lifeTargets
                .expand(
                  (rect) => [
                    rect.center,
                    Offset(rect.left + 6, rect.top + 6),
                    Offset(rect.right - 6, rect.bottom - 6),
                  ],
                )
                .firstWhere(
                  (point) => blocked.every((rect) => !rect.contains(point)),
                );
            await tester.tapAt(outside);
            await tester.pumpAndSettle();
            expect(close, findsNothing);
            expect(fixture.controller.session.history.length, history);
            expect(player.life, 40);
          }
          expect(tester.takeException(), isNull);
          debugDisableShadows = true;
        },
      );
    }
  }

  testWidgets(
    'repeated menus launch actions for the owning player and close on resize',
    (tester) async {
      final fixture = await mount(tester, 4, const Size(1133, 744));
      final player = fixture.controller.session.players.firstWhere(
        (p) => fixture.controller.session.quarterTurnsFor(p) == 2,
      );
      final id = player.id;
      await openPlayerTools(tester, playerId: id);
      await tester.tap(find.byKey(ValueKey('$id-manage-utilities')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('utility-picker-heading')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('$id-close-tools-menu')), findsNothing);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      await openPlayerTools(tester, playerId: id);
      await tester.tap(find.byKey(ValueKey('$id-player-details')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('context-workspace')), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'Has partner'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Has partner'));
      await tester.pumpAndSettle();
      expect(fixture.controller.session.hasPartner(id), isTrue);
      expect(
        fixture.controller.session.players
            .where((p) => p.id != id)
            .every((p) => !fixture.controller.session.hasPartner(p.id)),
        isTrue,
      );
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      await openPlayerTools(tester, playerId: id);
      tester.view.physicalSize = const Size(744, 1133);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('$id-close-tools-menu')), findsNothing);
      await openPlayerTools(tester, playerId: id);
      await tester.tap(find.byKey(ValueKey('$id-close-tools-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('$id-close-tools-menu')), findsNothing);
      expect(tester.takeException(), isNull);
      debugDisableShadows = true;
    },
  );

  testWidgets('safe insets and lifecycle changes preserve menu bounds', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(
      left: 48,
      top: 24,
      right: 32,
      bottom: 20,
    );
    final fixture = await mount(tester, 4, const Size(1133, 744));
    for (final player in fixture.controller.session.players) {
      await openPlayerTools(tester, playerId: player.id);
      for (final suffix in ['manage-utilities', 'player-details']) {
        final rect = tester.getRect(
          find.byKey(ValueKey('${player.id}-$suffix')),
        );
        expect(rect.left, greaterThanOrEqualTo(48));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.right, lessThanOrEqualTo(1101));
        expect(rect.bottom, lessThanOrEqualTo(724));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('${player.id}-close-tools-menu')),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('normal lanes scroll green mana halves clear of floating tools', (
    tester,
  ) async {
    final fixture = await mount(tester, 4, const Size(1133, 744));
    for (final player in fixture.controller.session.players) {
      await showAdaptiveUtilities(tester, playerId: player.id);
      for (final action in ['add', 'spend']) {
        final target = find.byKey(ValueKey('${player.id}-mana-G-$action'));
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        expect(
          tester
              .getRect(target)
              .overlaps(
                tester.getRect(
                  find.byKey(ValueKey('${player.id}-utility-tools')),
                ),
              ),
          isFalse,
        );
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          fixture.controller.player(player.id).mana['G'],
          action == 'add' ? 1 : 0,
        );
      }
    }
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('large text keeps action menu reachable', (tester) async {
    final fixture = await mount(tester, 6, const Size(650, 480), scale: 2);
    final id = fixture.controller.session.players.first.id;
    await openPlayerTools(tester, playerId: id);
    expect(
      find.byKey(ValueKey('$id-manage-utilities')).hitTestable(),
      findsOneWidget,
    );
    final customize = find.byKey(ValueKey('$id-player-details'));
    await tester.ensureVisible(customize);
    await tester.pumpAndSettle();
    expect(customize.hitTestable(), findsOneWidget);
    await capture(tester, 'menu-large-text');
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
  });
}

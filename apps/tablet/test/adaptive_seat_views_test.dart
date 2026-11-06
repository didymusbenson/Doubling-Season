import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/seat_layout_policy.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';

import 'support/table_fixture.dart';

const captureKey = ValueKey('adaptive-table-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('adaptive-table-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final path =
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}';
        await (FontLoader(
          font.key,
        )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$captures/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<TableFixture> mount(WidgetTester tester, int count, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    await f.controller.resetGame(keepBoard: false, playerCount: count);
    for (final p in f.controller.session.players) {
      p.tokens = [
        for (var n = 0; n < 7; n++)
          sampleToken(id: '${p.id}-token-$n', name: 'Saproling ${n + 1}'),
      ];
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: f.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      f.dispose();
    });
    return f;
  }

  test('local view policy uses seat width and accessible text size', () {
    expect(SeatLayoutPolicy.useLocalViews(width: 519), isTrue);
    expect(SeatLayoutPolicy.useLocalViews(width: 520), isFalse);
    expect(SeatLayoutPolicy.useLocalViews(width: 565), isFalse);
    expect(
      SeatLayoutPolicy.useLocalViews(
        width: 565,
        textScaler: TextScaler.linear(1.3),
      ),
      isTrue,
    );
  });

  for (final count in [4, 5, 6]) {
    for (final size in [
      const Size(1133, 744),
      const Size(744, 1133),
      const Size(650, 480),
      const Size(1700, 1100),
    ]) {
      testWidgets('$count seats at $size choose by actual space and retain life', (
        tester,
      ) async {
        final f = await mount(tester, count, size);
        await capture(
          tester,
          'adaptive-${count}p-${size.width.toInt()}x${size.height.toInt()}-tokens',
        );
        for (final row in f.controller.session.seatRows) {
          final expectedWidth =
              (size.width - (row.length - 1) * 8) / row.length;
          for (final p in row.whereType<PlayerState>()) {
            final seat = find.byKey(ValueKey(p.id));
            expect(tester.getSize(seat).width, closeTo(expectedWidth, .01));
            final local = SeatLayoutPolicy.useLocalViews(width: expectedWidth);
            final tabs = find.byKey(ValueKey('${p.id}-local-view-tabs'));
            expect(tabs, local ? findsOneWidget : findsNothing);
            final life = find.byKey(ValueKey('${p.id}-life-surface'));
            expect(life.hitTestable(), findsOneWidget);
            final name = find.byKey(ValueKey('${p.id}-player-name'));
            final nameBox = tester.renderObject<RenderBox>(name);
            final dx =
                nameBox.localToGlobal(const Offset(10, 0)) -
                nameBox.localToGlobal(Offset.zero);
            expect(
              dx.dx.sign,
              f.controller.session.quarterTurnsFor(p) == 2 ? -1 : 1,
            );
            if (local) {
              expect(tester.getSize(tabs).height, 44);
              await tester.tap(find.byKey(ValueKey('${p.id}-utilities-tab')));
              await tester.pumpAndSettle();
              expect(
                find.byKey(ValueKey('${p.id}-utility-tools')).hitTestable(),
                findsOneWidget,
              );
              expect(life.hitTestable(), findsOneWidget);
            }
          }
        }
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'adaptive-${count}p-${size.width.toInt()}x${size.height.toInt()}-utilities',
        );
      });
    }
  }

  testWidgets(
    'switching is seat-local, nonhistorical and retains token state and scroll',
    (tester) async {
      final f = await mount(tester, 6, const Size(1133, 744));
      final p = f.controller.session.players.first;
      final other = f.controller.session.players.last;
      final lane = find.byKey(ValueKey('${p.id}-token-lane'));
      final list = find.descendant(
        of: lane,
        matching: find.byType(ReorderableListView),
      );
      final scroll = tester.widget<ReorderableListView>(list).scrollController!;
      scroll.jumpTo(120);
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      final history = f.controller.session.history.length;
      await tester.tap(find.byKey(ValueKey('${p.id}-utilities-tab')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('${other.id}-token-lane')).hitTestable(),
        findsOneWidget,
      );
      expect(lane.hitTestable(), findsNothing);
      await tester.tap(find.byKey(ValueKey('${p.id}-tokens-tab')));
      await tester.pumpAndSettle();
      expect(scroll.offset, offset);
      expect(f.controller.session.history.length, history);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final card = find
          .descendant(of: lane, matching: find.byType(TabletTokenCard))
          .first;
      tester.widget<TabletTokenCard>(card).onExpand();
      await tester.pumpAndSettle();
      final element = tester.element(card);
      await tester.tap(find.byKey(ValueKey('${p.id}-utilities-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('${p.id}-tokens-tab')));
      await tester.pumpAndSettle();
      expect(tester.element(card), same(element));
      expect(tester.widget<TabletTokenCard>(card).expanded, isTrue);
      // Reparenting from a local view into a split lane keeps the actual token
      // state object, including recovery drafts, rather than rebuilding a clone.
      tester.view.physicalSize = const Size(1700, 1100);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('${p.id}-local-view-tabs')), findsNothing);
      expect(tester.element(card), same(element));
      expect(tester.widget<TabletTokenCard>(card).expanded, isTrue);
      tester.view.physicalSize = const Size(1133, 744);
      await tester.pumpAndSettle();
      expect(tester.element(card), same(element));
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [5, 6]) {
    testWidgets('$count-player drawer stays usable and close consumes tap', (
      tester,
    ) async {
      final f = await mount(tester, count, const Size(1133, 744));
      final p = f.controller.session.players.first;
      final before = f.controller.session.history.length;
      await tester.tap(find.byKey(const ValueKey('central-game-controls')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('table-drawer-layer')), findsOneWidget);
      await capture(tester, 'adaptive-${count}p-drawer');
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(ValueKey('${p.id}-dismiss-drawer')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('table-drawer-layer')), findsNothing);
      expect(f.controller.session.history.length, before);
      expect(tester.takeException(), isNull);
    });
  }
}

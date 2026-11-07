import 'dart:io';
import 'dart:ui' as ui;

import 'package:doubling_season/widgets/counter_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  setUpAll(() async {
    if (captures == null) return;
    await Directory(captures).create(recursive: true);
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
      );
      await (FontLoader(
        font.key,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
  });

  Future<void> showCard(
    WidgetTester tester, {
    bool expanded = false,
    int counters = 5,
    double width = 400,
    double textScale = 1,
    int turns = 0,
    bool longName = false,
    Map<String, int>? extraCounters,
    ValueChanged<WorkspacePage>? onOpen,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    final f = TableFixture(
      stateWithTokens([
        sampleToken(
          name: longName ? 'A very long Zombie creature token name' : 'Zombie',
          type: 'Creature — Zombie',
          pt: '2/2',
          colors: 'B',
          amount: 1,
          tapped: 0,
          plusOne: counters,
          counters: extraCounters,
        ),
      ]),
    );
    await f.initialize();
    var isExpanded = expanded;
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const ValueKey('token-header-capture'),
              child: RotatedBox(
                quarterTurns: turns,
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (context, setState) => ListenableBuilder(
                        listenable: f.controller,
                        builder: (context, _) => TabletTokenCard(
                          token: f.token('source'),
                          player: f.player,
                          board: f.board,
                          playerName: 'Player 1',
                          quarterTurns: turns,
                          expanded: isExpanded,
                          onExpand: () =>
                              setState(() => isExpanded = !isExpanded),
                          onOpenDetailed: onOpen ?? (_) {},
                          onInputLock: (_) {},
                        ),
                      ),
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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('token-header-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$captures/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final expanded in [false, true]) {
    for (final counters in [0, 5]) {
      testWidgets('header spacing expanded=$expanded counters=$counters', (
        tester,
      ) async {
        await showCard(tester, expanded: expanded, counters: counters);
        await capture(tester, '${expanded ? 'expanded' : 'compact'}-$counters');
        final name = tester.getRect(byControlLabel('Player 1, Zombie, Name'));
        final status = tester.getRect(
          byControlLabel(
            'Player 1, Zombie, edit total, tapped and summoning sickness',
          ),
        );
        final nameText = find.text('Zombie');
        final totalText = find
            .descendant(
              of: byControlLabel(
                'Player 1, Zombie, edit total, tapped and summoning sickness',
              ),
              matching: find.text('1'),
            )
            .first;
        double baseline(Finder finder) =>
            tester.getTopLeft(finder).dy +
            tester
                .renderObject<RenderBox>(finder)
                .getDryBaseline(
                  tester.renderObject<RenderBox>(finder).constraints,
                  TextBaseline.alphabetic,
                )!;
        expect(
          (baseline(nameText) - baseline(totalText)).abs(),
          // The status icon may establish its row baseline just above the
          // text's own baseline; keep the visible labels within two pixels.
          lessThanOrEqualTo(2),
        );
        expect(name.overlaps(status), isFalse);
        if (counters > 0) {
          final pill = tester.getRect(find.byType(CounterPillView));
          final type = tester.getRect(byControlLabel('Player 1, Zombie, Type'));
          expect(pill.top - name.bottom, greaterThanOrEqualTo(4));
          expect(type.top - pill.bottom, greaterThanOrEqualTo(4));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final expanded in [false, true]) {
    for (final width in [180.0, 290.0, 400.0]) {
      testWidgets('large counter text fits expanded=$expanded width=$width', (
        tester,
      ) async {
        await showCard(
          tester,
          expanded: expanded,
          width: width,
          textScale: 1.8,
        );
        await capture(
          tester,
          'large-${expanded ? 'expanded' : 'compact'}-${width.toInt()}',
        );
        final pill = tester.getRect(find.byType(CounterPillView));
        final text = tester.getRect(find.text('+1/+1'));
        expect(text.top, greaterThanOrEqualTo(pill.top));
        expect(text.bottom, lessThanOrEqualTo(pill.bottom));
        expect(pill.height, greaterThan(32));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('counter controls and repeated expansion retain their commands', (
    tester,
  ) async {
    final opened = <WorkspacePage>[];
    await showCard(tester, onOpen: opened.add);
    await tester.tap(find.byType(CounterPillView));
    await tester.pumpAndSettle();
    await tester.tap(byControlLabel('Manage counters'));
    await tester.pumpAndSettle();
    expect(opened, [WorkspacePage.tokenCounters, WorkspacePage.tokenCounters]);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Zombie'));
      await tester.pumpAndSettle();
      expect(byControlLabel('Choose artwork'), findsOneWidget);
      await tester.tapAt(
        tester.getTopRight(find.byType(TabletTokenCard)) + const Offset(-2, 2),
      );
      await tester.pumpAndSettle();
      expect(byControlLabel('Choose artwork'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('overflow counters scroll without losing the manage action', (
    tester,
  ) async {
    final opened = <WorkspacePage>[];
    await showCard(
      tester,
      width: 180,
      extraCounters: {
        'Shield': 12,
        'A long custom counter': 999999,
        'Flying': 1,
      },
      onOpen: opened.add,
    );
    final scroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(scroll, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(byControlLabel('Manage counters').hitTestable(), findsOneWidget);
    await tester.tap(byControlLabel('Manage counters'));
    await tester.pumpAndSettle();
    expect(opened, [WorkspacePage.tokenCounters]);
    expect(tester.takeException(), isNull);
  });

  for (final turns in [0, 1, 2, 3]) {
    testWidgets('long header stays bounded facing $turns', (tester) async {
      await showCard(
        tester,
        width: 220,
        longName: true,
        turns: turns,
        expanded: true,
      );
      await capture(tester, 'long-name-facing-$turns');
      expect(byControlLabel('Manage counters').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

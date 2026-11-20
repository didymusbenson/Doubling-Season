import 'support/control_finders.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

// Optional captures are Flutter test renderer evidence, not native acceptance.
final _captureDirectory = kIsWeb
    ? null
    : Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('utility-capture');

void main() {
  setUpAll(() async {
    if (_captureDirectory == null) return;
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/${font.value}',
      );
      if (await file.exists()) {
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    await Directory(_captureDirectory!).create(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$_captureDirectory/flutter-test-renderer-utility-$name.png',
        ).writeAsBytes(png.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<void> reachable(
    WidgetTester tester,
    Finder target, {
    String? reason,
  }) async {
    expect(target, findsOneWidget, reason: reason);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget, reason: reason);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reachable(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> showUtility(
    WidgetTester tester,
    TableFixture fixture,
    UtilityState utility,
    Size size, {
    int quarterTurns = 0,
    double textScale = 1,
    VoidCallback? onBackgroundTap,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    addTearDown(() async {
      if (byControlLabel('Close workspace').evaluate().isNotEmpty) {
        await tap(tester, byControlLabel('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
    fixture.catalog.loaded = true;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () {
                    onBackgroundTap?.call();
                    showTableWorkspace(
                      context,
                      fixture.controller,
                      catalog: fixture.catalog,
                      seatId: fixture.playerId,
                      initialPage: WorkspacePage.utilities,
                      itemId: utility.id,
                      quarterTurns: quarterTurns,
                    );
                  },
                  child: const Text('Open utility'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Open utility'));
    await tester.pumpAndSettle();
    final frame = tester.getSize(
      find.byKey(const ValueKey('context-workspace')),
    );
    final bounds = TableModalFrame.localSize(
      Size(size.width, size.height - 44),
      quarterTurns,
    );
    expect(frame.width, lessThanOrEqualTo(bounds.width));
    expect(frame.height, lessThanOrEqualTo(bounds.height));
  }

  for (final (size, turns, scale) in [
    (const Size(1366, 1024), 0, 1.0),
    (const Size(1133, 744), 2, 1.0),
    (const Size(744, 1133), 0, 1.0),
    (const Size(390, 844), 0, 1.0),
    (const Size(320, 640), 0, 1.5),
    (const Size(744, 375), 0, 1.0),
    (const Size(650, 600), 1, 1.25),
  ]) {
    testWidgets(
      'Disa mana tiles show every live control without scrolling at $size, rotation $turns, text $scale',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final utility = fixture.player.utilities.firstWhere(
          (u) => u.kind == 'mana_pool',
        );
        fixture.player.mana['W'] = 123456789;
        fixture.player.manaLocks.add('W');
        utility.artworkUrl =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
        utility.configuration['artworkOptions'] = [
          {
            'url': utility.artworkUrl,
            'artist': 'Christopher Rush',
            'set': 'LEA',
          },
        ];
        await showUtility(
          tester,
          fixture,
          utility,
          size,
          quarterTurns: turns,
          textScale: scale,
        );
        final body = find.byKey(const ValueKey('utility-detail-mana_pool'));
        expect(
          find.descendant(of: body, matching: find.byType(Scrollable)),
          findsNothing,
        );
        expect(
          find.text(
            'Manual mana. Empty preserves locked colors; conversion moves every color.',
          ),
          findsNothing,
        );
        expect(
          find.text('Tap either half for ±1; hold for ±10.'),
          findsNothing,
        );
        expect(find.byTooltip('Edit artwork').hitTestable(), findsOneWidget);
        expect(find.text('Christopher Rush').hitTestable(), findsOneWidget);

        final white = find.byKey(const ValueKey('utility-mana-W'));
        final blue = find.byKey(const ValueKey('utility-mana-U'));
        final black = find.byKey(const ValueKey('utility-mana-B'));
        final box = tester.renderObject<RenderBox>(body);
        final first = box.globalToLocal(tester.getCenter(white));
        final second = box.globalToLocal(tester.getCenter(blue));
        final third = box.globalToLocal(tester.getCenter(black));
        expect(first.dy, closeTo(second.dy, .01));
        expect(second.dx, greaterThan(first.dx));
        if (size.height > 375) {
          expect(third.dx, closeTo(first.dx, .01));
          expect(third.dy, greaterThan(first.dy));
        }

        final decoration =
            tester.widget<Container>(white).decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFFF9FAF4));
        expect((decoration.border! as Border).top.width, 2.5);
        await capture(
          tester,
          'disa-mana-${size.width.toInt()}x${size.height.toInt()}',
        );
        for (final name in [
          'White',
          'Blue',
          'Black',
          'Red',
          'Green',
          'Colorless',
        ]) {
          for (final label in [
            'Increase $name mana',
            'Decrease $name mana',
            'Increase $name mana by ten',
            'Decrease $name mana by ten',
            '${name == 'White' ? 'Unlock' : 'Lock'} $name mana for Empty',
            'Convert all mana to $name',
          ]) {
            final control = byControlLabel(label);
            expect(control.hitTestable(), findsOneWidget, reason: label);
            final shape = tester.getSize(control);
            expect(shape.width, greaterThanOrEqualTo(43.5), reason: label);
            expect(shape.height, greaterThanOrEqualTo(43.5), reason: label);
          }
        }
        final empty = find.widgetWithText(
          OutlinedButton,
          size.width == 320 ? 'Empty' : 'Empty unlocked mana',
        );
        expect(empty.hitTestable(), findsOneWidget);
        if (size.width == 320) {
          expect(
            byControlLabel('Empty unlocked mana').hitTestable(),
            findsOneWidget,
          );
          final buttonBounds = tester.getRect(empty);
          final textBounds = tester.getRect(find.text('Empty'));
          expect(buttonBounds.contains(textBounds.topLeft), isTrue);
          expect(textBounds.bottom, lessThanOrEqualTo(buttonBounds.bottom));
        }
        expect(tester.takeException(), isNull);
        await tap(tester, byControlLabel('Close workspace'));
      },
    );
  }
}

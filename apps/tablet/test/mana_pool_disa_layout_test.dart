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

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(390, 844),
    const Size(320, 640),
  ]) {
    testWidgets(
      'Disa mana tiles preserve WU BR GC layout and controls at $size',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final utility = fixture.player.utilities.firstWhere(
          (u) => u.kind == 'mana_pool',
        );
        fixture.player.mana['W'] = 123456789;
        fixture.player.manaLocks.add('W');
        await showUtility(tester, fixture, utility, size);
        final white = find.byKey(const ValueKey('utility-mana-W'));
        final blue = find.byKey(const ValueKey('utility-mana-U'));
        final black = find.byKey(const ValueKey('utility-mana-B'));
        expect(tester.getTopLeft(white).dy, tester.getTopLeft(blue).dy);
        expect(tester.getTopLeft(white).dx, tester.getTopLeft(black).dx);
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
            await reachable(tester, byControlLabel(label));
          }
        }
        await reachable(tester, find.text('Empty unlocked mana'));
        expect(tester.takeException(), isNull);
        await tap(tester, byControlLabel('Close workspace'));
      },
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';
import 'support/control_finders.dart';

void main() {
  final directory = Platform.environment['TABLET_CAPTURE_DIR'];
  setUp(() {
    if (directory != null) debugDisableShadows = false;
  });
  tearDown(() => debugDisableShadows = true);
  setUpAll(() async {
    if (directory == null) return;
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.value}',
      );
      await (FontLoader(
        font.key,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
    await Directory(directory).create(recursive: true);
  });
  for (final entry in [
    ('phone', const Size(390, 844), 0),
    ('compact-phone', const Size(320, 568), 0),
    ('large-text', const Size(744, 1133), 0),
    ('small-tablet', const Size(1133, 744), 0),
    ('side-player', const Size(1133, 744), 1),
    ('large-tablet', const Size(1366, 1024), 2),
    ('short-modal', const Size(667, 375), 0),
  ]) {
    testWidgets('summary fits ${entry.$1} and scrolls to variable power', (
      tester,
    ) async {
      tester.view.physicalSize = entry.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = TableFixture(
        stateWithTokens([
          sampleToken(amount: 12, tapped: 3, sick: 2),
          sampleToken(
            id: 'artifact',
            name: 'Treasure',
            pt: '',
            type: 'Artifact — Treasure',
            amount: 8,
          ),
          sampleToken(id: 'variable', name: 'Elemental', pt: '*/*', amount: 4),
        ]),
      );
      await f.initialize();
      addTearDown(f.dispose);
      f.catalog.loaded = true;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('summary-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: tableTheme(
              entry.$1 == 'large-text' ? Brightness.light : Brightness.dark,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(entry.$1 == 'large-text' ? 2 : 1),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTableWorkspace(
                    context,
                    f.controller,
                    catalog: f.catalog,
                    seatId: f.playerId,
                    initialPage: WorkspacePage.tokenSummary,
                    quarterTurns: entry.$3,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Board summary'), findsOneWidget);
      final summaryBody = find.text(
        'Only this player’s tokens. Zero stacks and emblems are excluded.',
      );
      // The close control must reserve space only for the heading, not the body.
      final modalSize = tester.getSize(
        find.byKey(const ValueKey('context-workspace')),
      );
      expect(
        tester.getSize(summaryBody).width,
        closeTo(modalSize.width - 40, 0.1),
      );
      if (directory != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('summary-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            '$directory/summary-${entry.$1}.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('4 × Elemental (*/*)'));
      await tester.pumpAndSettle();
      expect(find.text('4 × Elemental (*/*)').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      debugDisableShadows = true;
    });
  }
}

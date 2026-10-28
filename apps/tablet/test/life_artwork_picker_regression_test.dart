import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/life_artwork_picker.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'support/table_fixture.dart';

const pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  Future<TableFixture> open(
    WidgetTester tester,
    int turns, {
    Future<void> Function(String)? validate,
  }) async {
    final fixture = TableFixture();
    await fixture.initialize();
    await fixture.controller.modifyLibrary((s) {
      s.library['customTokens'] = [
        {
          'name': 'Soldier',
          'pt': '1/1',
          'type': 'Creature',
          'artwork': [
            {'url': pixel, 'set': 'FIRST', 'artist': 'Artist A'},
            {'url': pixel, 'set': 'SECOND', 'artist': 'Artist B'},
          ],
        },
        {'name': 'Artless', 'artwork': []},
      ];
    });
    fixture.catalog.loaded = true;
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                useSafeArea: false,
                builder: (_) => LifeArtworkPicker(
                  catalog: fixture.catalog,
                  seatName: 'Alice',
                  quarterTurns: turns,
                  validate: validate ?? (_) async {},
                  importArtwork: () async => pixel,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return fixture;
  }

  for (final turns in [0, 1, 2, 3]) {
    testWidgets(
      'life art search, variants and keyboard face seat $turns without board writes',
      (tester) async {
        final fixture = await open(tester, turns);
        final before = fixture.controller.state.toJson().toString();
        expect(find.text('Soldier'), findsOneWidget);
        expect(find.text('Artless'), findsNothing);
        final rotation = tester.widget<RotatedBox>(
          find
              .ancestor(
                of: find.text('Alice · life artwork'),
                matching: find.byType(RotatedBox),
              )
              .first,
        );
        expect(rotation.quarterTurns, turns);
        final surface = find.byKey(const ValueKey('life-artwork-modal'));
        final shell = tester.renderObject<RenderBox>(surface);
        final rect = MatrixUtils.transformRect(
          shell.getTransformTo(null),
          Offset.zero & shell.size,
        );
        expect(
          shell.size,
          turns.isOdd ? const Size(692, 640) : const Size(720, 640),
        );
        expect(rect.left, greaterThanOrEqualTo(16 - .01));
        expect(rect.right, lessThanOrEqualTo(1024 - 16 + .01));
        expect(rect.top, greaterThanOrEqualTo(24 + 16 - .01));
        expect(rect.bottom, lessThanOrEqualTo(768 - 20 - 16 + .01));
        expect(rect.center.dx, closeTo(512, .01));
        expect(rect.center.dy, closeTo(386, .01));
        final restingSize = shell.size;
        await tester.tap(find.byType(PlayerField));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface), restingSize);
        expect(find.text('Done'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface), restingSize);
        await tester.tap(find.text('Soldier'));
        await tester.pumpAndSettle();
        expect(find.text('FIRST'), findsOneWidget);
        expect(find.text('Artist A'), findsOneWidget);
        expect(find.text('SECOND'), findsOneWidget);
        await tester.tap(find.text('SECOND'));
        await tester.pumpAndSettle();
        expect(find.text('Use artwork'), findsOneWidget);
        expect(find.byType(TableArtwork), findsWidgets);
        expect(tester.takeException(), isNull);
        expect(fixture.controller.state.toJson().toString(), before);
        await tester.tap(find.byTooltip('Close artwork search'));
        await tester.pumpAndSettle();
        expect(fixture.controller.state.toJson().toString(), before);
      },
    );
  }

  testWidgets(
    'pending validation has stable dialog bounds; failure retains candidate and reports inline',
    (tester) async {
      final pending = Completer<void>();
      await open(tester, 2, validate: (_) => pending.future);
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(LifeArtworkPicker));
      await tester.tap(find.text('FIRST'));
      await tester.pump();
      expect(tester.getRect(find.byType(LifeArtworkPicker)), before);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.completeError(StateError('Image unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Image unavailable'), findsOneWidget);
      expect(find.text('Use artwork'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}

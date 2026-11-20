import 'support/control_finders.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/life_artwork_picker.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'support/table_fixture.dart';

const pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAUCAIAAABj86gYAAAAJklEQVR4nGNQCJhLU8QwasGoBaMWDAcLYnpu0hSNWjBqwagFPTcB5MhrLu8vxaYAAAAASUVORK5CYII=';
const secondPixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAUCAIAAABj86gYAAAAJklEQVR4nGPodHajKWIYtWDUglELhoMFR+ubaIpGLRi1YNSC+iYAJLZ3riPtzwcAAAAASUVORK5CYII=';

const captureKey = ValueKey('life-art-capture');
final capturePath = kIsWeb ? null : Platform.environment['LIFE_ART_CAPTURE'];
void main() {
  setUpAll(() async {
    if (capturePath == null) return;
    await Directory(capturePath!).create(recursive: true);
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
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (capturePath == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$capturePath/$name.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<TableFixture> open(
    WidgetTester tester,
    int turns, {
    Size size = const Size(1024, 768),
    Future<void> Function(String)? validate,
    ValueChanged<String?>? onResult,
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
            {'url': secondPixel, 'set': 'SECOND', 'artist': 'Artist B'},
          ],
        },
        {'name': 'Artless', 'artwork': []},
      ];
    });
    fixture.catalog.loaded = true;
    tester.view.physicalSize = size;
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
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    useSafeArea: false,
                    builder: (_) => LifeArtworkPicker(
                      catalog: fixture.catalog,
                      seatName: 'Alice',
                      quarterTurns: turns,
                      validate: validate ?? (_) async {},
                      importArtwork: () async => pixel,
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return fixture;
  }

  for (final (size, turns) in [
    (const Size(1133, 744), 2),
    (const Size(744, 1133), 0),
    (const Size(320, 640), 0),
  ]) {
    testWidgets('art flow visual checkpoint at $size', (tester) async {
      await open(tester, turns, size: size);
      final prefix = '${size.width.toInt()}x${size.height.toInt()}';
      await capture(tester, '$prefix-search');
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();
      await capture(tester, '$prefix-printings');
      await tester.ensureVisible(find.text('SECOND'));
      await tester.tap(find.text('SECOND'));
      await tester.pumpAndSettle();
      await capture(tester, '$prefix-preview');
      expect(find.text('Use artwork'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'back walks through printings, retains query and returns the exact selected artwork',
    (tester) async {
      String? result;
      await open(
        tester,
        0,
        size: const Size(320, 640),
        onResult: (value) => result = value,
      );
      final query = tester
          .widget<PlayerField>(find.byType(PlayerField))
          .controller;
      query.text = 'Sold';
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SECOND'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsNothing);
      expect(find.text('Artist B'), findsOneWidget);
      await tester.tap(byControlLabel('Back to artwork printings'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsOneWidget);
      expect(find.text('Use artwork'), findsNothing);
      await tester.tap(byControlLabel('Back to token art search'));
      await tester.pumpAndSettle();
      expect(query.text, 'Sold');
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SECOND'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use artwork'));
      await tester.pumpAndSettle();
      expect(result, secondPixel);
    },
  );

  testWidgets(
    'native phone keyboard leaves token result and search field reachable',
    (tester) async {
      tester.view.display.size = const Size(320, 640);
      tester.view.display.devicePixelRatio = 1;
      addTearDown(tester.view.display.resetSize);
      addTearDown(tester.view.display.resetDevicePixelRatio);
      await open(tester, 0, size: const Size(320, 640));
      final search = find.byType(TextField);
      expect(search, findsOneWidget);
      await tester.tap(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 288);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(search, 'Sold');
      await tester.pumpAndSettle();
      await capture(tester, '320x640-native-keyboard-inset');
      expect(search.hitTestable(), findsOneWidget);
      expect(find.text('Soldier').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom image import has its own preview and can return to search',
    (tester) async {
      String? result;
      await open(
        tester,
        0,
        size: const Size(320, 640),
        onResult: (value) => result = value,
      );
      await tester.tap(find.text('Import custom image'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsNothing);
      expect(find.text('Use artwork').hitTestable(), findsOneWidget);
      await tester.tap(byControlLabel('Back to token art search'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerField), findsOneWidget);
      await tester.tap(find.text('Import custom image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use artwork'));
      await tester.pumpAndSettle();
      expect(result, pixel);
    },
  );

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
        await tester.tap(byControlLabel('Close artwork search'));
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

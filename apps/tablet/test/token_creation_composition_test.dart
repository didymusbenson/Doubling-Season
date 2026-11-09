import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

const _image =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAABgCAIAAABaGO0eAAABbElEQVR4nO3bWw0CQRQEUcQgggRjmEMHdrCwPHaq73QlJWBun9/dy/V+M7AL/oLyBBCgOwEE6E4AAboTQIDuBBCgOwEE6E4AAboTQIDuBBDgcK/n43j4a/cB+Gj3cRK5AD/uPkUiFODv68caxAGcNH0sQxbAgvXTDFIAlk2fxhABgKwfYsADgOsnGMAA+Pq4AQmA755gIEArAL54iAEDgG+dYyBAHwC+cpTBagB83zQDAQTIa1sAfNlAAwEEiGxDAHzTTAMBBEhNAAEEEEAAAQQQQAABBBBAAAEEEEAAAaYCzDJYtokAAkS2J8AUg5WDCCBAXjsD5BssXsOvo8n1BWgFyDRAdvAfMXJ9AboBcgzABfxTnlw/AoA1wG+PAKAM8KuDABYz4JeGAqwxwG+MBjiVAb9rDMAZBvhFwwD+JYG/fzzAdxL4azcE2DIBBOhOAAG6E0CA7gQQoDsBBOhOAAG6E0CA7gQQoDsB4N7vK09igIP+QwAAAABJRU5ErkJggg==';
const _capture = ValueKey('creation-capture');

void main() {
  late TableFixture fixture;
  late String opaqueCardImage;
  setUp(() => fixture = TableFixture());
  tearDown(() => fixture.dispose());

  setUpAll(() async {
    // Match the catalog JPEG's dimensions and opaque white corner matte.
    // Keep a white interior panel to prove that only the corners are clipped.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const source = Rect.fromLTWH(0, 0, 672, 936);
    canvas.drawRect(source, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(source, const Radius.circular(28)),
      Paint()..color = const Color(0xff202020),
    );
    canvas.drawRect(
      const Rect.fromLTWH(200, 300, 272, 336),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(672, 936);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    opaqueCardImage =
        'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
    image.dispose();
    picture.dispose();
    Directory sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory(
      '${sdk.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      sdk = sdk.parent;
    }
    for (final font in {
      'Roboto': 'Roboto-Regular.ttf',
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(
            File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.value}',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1133, 744),
    int turns = 0,
    bool nativeInput = false,
    double scale = 1,
    bool artwork = true,
    String? imageUrl,
    Brightness brightness = Brightness.dark,
    String artist = 'Noah Bradley',
    String abilities = '{2}, Sacrifice this token: Draw a card.',
  }) async {
    await fixture.initialize();
    fixture.catalog.loaded = true;
    await fixture.catalog.saveCustom(
      TokenDefinition(
        name: 'Clue',
        pt: '',
        type: 'Artifact — Clue',
        colors: '',
        abilities: abilities,
        popularity: 0,
        artwork: artwork
            ? [
                ArtworkVariant(
                  set: 'TEST',
                  url:
                      imageUrl ??
                      (Platform.environment['TABLET_CREATION_ART'] == null
                          ? _image
                          : 'data:image/jpeg;base64,${base64Encode(File(Platform.environment['TABLET_CREATION_ART']!).readAsBytesSync())}'),
                  artist: artist,
                ),
              ]
            : [],
      ),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    if (nativeInput) {
      tester.view.display.size = size;
      tester.view.display.devicePixelRatio = 1;
      addTearDown(tester.view.display.reset);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _capture,
        child: MaterialApp(
          theme: tableTheme(brightness).copyWith(
            textTheme: tableTheme(
              brightness,
            ).textTheme.apply(fontFamily: 'Roboto'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  fixture.controller,
                  catalog: fixture.catalog,
                  seatId: fixture.playerId,
                  quarterTurns: turns,
                ),
                child: const Text('Open tokens'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open tokens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clue'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['TABLET_CAPTURE_DIR'];
    if (dir == null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_capture),
    );
    await tester.runAsync(() async {
      await Directory(dir).create(recursive: true);
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'creation fits content, contains card and places credit underneath',
    (tester) async {
      await open(tester);
      final shell = tester.getRect(
        find.byKey(const ValueKey('context-workspace')),
      );
      final back = tester.getRect(
        find.byKey(const ValueKey('creation-back-to-search')),
      );
      final art = tester.getRect(
        find.byKey(const ValueKey('creation-token-artwork')),
      );
      final credit = tester.getRect(
        find.byKey(const ValueKey('creation-artwork-credit')),
      );
      final create = tester.getRect(
        find.widgetWithText(FilledButton, 'Create tokens'),
      );
      expect(back.width, lessThan(220));
      expect(back.height, greaterThanOrEqualTo(48));
      expect(shell.height, lessThan(520));
      expect(shell.bottom - create.bottom, lessThan(32));
      expect(art.width / art.height, closeTo(5 / 7, .001));
      expect(
        tester
            .widget<TableArtwork>(
              find.byKey(const ValueKey('creation-token-artwork')),
            )
            .fit,
        BoxFit.contain,
      );
      expect(credit.top, greaterThan(art.bottom));
      expect(credit.bottom, lessThan(shell.bottom));
      expect(find.text('Noah Bradley'), findsOneWidget);
      expect(find.text('Create tokens').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'creation-landscape');
      await close(tester);
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [const Size(1133, 744), const Size(390, 844)]) {
      testWidgets(
        '${brightness.name} ${size.width} card corners reveal the modal surface',
        (tester) async {
          await open(
            tester,
            size: size,
            imageUrl: opaqueCardImage,
            brightness: brightness,
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          final art = tester.getRect(
            find.byKey(const ValueKey('creation-token-artwork')),
          );
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_capture),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              Color at(Offset point) {
                final offset =
                    (point.dy.floor() * image.width + point.dx.floor()) * 4;
                return Color.fromARGB(
                  bytes.getUint8(offset + 3),
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                );
              }

              final surface = at(art.topLeft + const Offset(-3, 2));
              for (final corner in [
                art.topLeft + const Offset(1, 1),
                art.topRight + const Offset(-2, 1),
                art.bottomLeft + const Offset(1, -2),
                art.bottomRight + const Offset(-2, -2),
              ]) {
                expect(at(corner), surface, reason: 'Unclipped corner $corner');
              }
              // Clipping must not remove real white card content or crop it.
              expect(at(art.center), Colors.white);
            } finally {
              image.dispose();
            }
          });
          expect(tester.takeException(), isNull);
          await close(tester);
        },
      );
    }
  }

  testWidgets('keyboard opens and returns to compact form with draft intact', (
    tester,
  ) async {
    await open(tester);
    final field = find.byWidgetPredicate(
      (w) => w is PlayerField && w.label == 'Quantity before modifiers',
    );
    final height = tester
        .getSize(find.byKey(const ValueKey('context-workspace')))
        .height;
    await tester.tap(field);
    await tester.pumpAndSettle();
    final controller = tester.widget<PlayerField>(field).controller;
    controller.text = '4';
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(controller.text, '4');
    expect(
      tester.getSize(find.byKey(const ValueKey('context-workspace'))).height,
      closeTo(height, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Create tokens'));
    await tester.pumpAndSettle();
    expect(fixture.player.tokens.single.amount, 4);
    expect(find.byKey(const ValueKey('context-workspace')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scene in [
    ('narrow', const Size(390, 844), 0, 1.0),
    ('short', const Size(844, 390), 0, 1.0),
    ('rotated', const Size(1133, 744), 1, 1.0),
    ('large-text', const Size(1133, 744), 0, 2.0),
    ('native-phone', const Size(390, 844), 0, 1.0),
    ('native-landscape', const Size(844, 390), 0, 1.0),
  ]) {
    testWidgets('${scene.$1} retains reachable creation and dismissal', (
      tester,
    ) async {
      await open(
        tester,
        size: scene.$2,
        turns: scene.$3,
        nativeInput: scene.$1.startsWith('native'),
        scale: scene.$4,
        artist: 'A very long illustrator credit that must wrap naturally',
      );
      final field = find.byWidgetPredicate(
        (w) => w is PlayerField && w.label == 'Quantity before modifiers',
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      final controller = tester.widget<PlayerField>(field).controller;
      await tester.tap(field);
      await tester.pumpAndSettle();
      controller.text = '3';
      if (scene.$1.startsWith('native')) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
      }
      expect(find.text('Done').last.hitTestable(), findsOneWidget);
      await tester.tap(find.text('Done').last);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(controller.text, '3');
      final create = find.text('Create tokens');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      expect(create.hitTestable(), findsOneWidget);
      expect(byControlLabel('Close workspace').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'creation-${scene.$1}');
      await close(tester);
    });
  }

  testWidgets('back restores search and repeated selection stays compact', (
    tester,
  ) async {
    await open(tester, artwork: false);
    expect(find.byKey(const ValueKey('creation-artwork-credit')), findsNothing);
    final height = tester
        .getSize(find.byKey(const ValueKey('context-workspace')))
        .height;
    await tester.tap(find.text('Back to search'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('context-workspace'))).height,
      640,
    );
    await tester.tap(find.text('Clue'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('context-workspace'))).height,
      height,
    );
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}

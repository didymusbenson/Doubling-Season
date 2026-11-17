import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

// A tall local white artwork fixture fills even expanded cards with test fonts,
// exposing dark readability strips without a network/GPU/font-specific golden.
const _art =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAEACAIAAAA1MGEZAAAAs0lEQVR4nO3LIRKAUACFQOX+d/4250VsBjbDfc65vuBTfTU4yO7VYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WCgqtFgoKrRYKCq0WD8cHgAo3ME/Wpf4YAAAAAASUVORK5CYII=';
const _captureKey = ValueKey('pt-backplate-render');

class _Pixels {
  _Pixels(this.width, this.height, this.bytes);
  final int width, height;
  final ByteData bytes;

  List<int> at(Offset point) {
    final x = point.dx.floor();
    final y = point.dy.floor();
    expect(x, inInclusiveRange(0, width - 1));
    expect(y, inInclusiveRange(0, height - 1));
    final index = (y * width + x) * 4;
    return List.generate(4, (channel) => bytes.getUint8(index + channel));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];

  setUpAll(() async {
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    if (captureDirectory == null) return;
    await Directory(captureDirectory).create(recursive: true);
    // Real UI fonts for human-reviewed captures; pixel assertions also work
    // with Flutter's default test font when captures are not requested.
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
  });

  Finder badge() => byControlLabel('Base power and toughness');

  Future<void> settleArtwork(WidgetTester tester) async {
    // Saves may rebuild the data-URI provider while an earlier frame decodes.
    // Finish only once the provider decoded here is still the rendered one.
    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.pump();
      final artwork = find.byType(Image);
      if (artwork.evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
      expect(artwork, findsOneWidget);
      final provider = tester.widget<Image>(artwork).image;
      await tester.runAsync(
        () => precacheImage(provider, tester.element(artwork)),
      );
      await tester.pumpAndSettle();
      if (tester.widget<Image>(artwork).image == provider) {
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        return;
      }
    }
    fail('Artwork provider kept changing before it could finish decoding.');
  }

  Future<void> showCard(
    WidgetTester tester,
    TableFixture fixture, {
    required bool phone,
    bool expanded = false,
    int turns = 0,
  }) async {
    final viewport = phone ? const Size(390, 844) : const Size(1133, 744);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    tester.view.display.size = viewport;
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    await fixture.initialize();
    var isExpanded = expanded;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: RotatedBox(
                quarterTurns: turns,
                child: SizedBox(
                  width: phone ? 390 : 260,
                  child: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (context, setState) => ListenableBuilder(
                        listenable: fixture.controller,
                        builder: (context, _) => TabletTokenCard(
                          token: fixture.token('source'),
                          player: fixture.player,
                          board: fixture.board,
                          playerName: 'Player 1',
                          quarterTurns: turns,
                          expanded: isExpanded,
                          onExpand: () =>
                              setState(() => isExpanded = !isExpanded),
                          onOpenDetailed: (_) {},
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
    await settleArtwork(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
  }

  Future<_Pixels> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final pending = boundary.toImage(pixelRatio: 1);
    return (await tester.runAsync(() async {
      final image = await pending;
      try {
        final bytes = (await image.toByteData())!;
        if (captureDirectory != null) {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await File('$captureDirectory/$name.png').writeAsBytes(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        }
        return _Pixels(image.width, image.height, bytes);
      } finally {
        image.dispose();
      }
    }))!;
  }

  Future<List<List<int>>> edgePixels(
    WidgetTester tester,
    String name, {
    bool expectSettledArtwork = true,
  }) async {
    final pixels = await capture(tester, name);
    final box = tester.renderObject<RenderBox>(badge());
    final boundary = tester.renderObject<RenderBox>(find.byKey(_captureKey));
    final size = box.size;
    if (expectSettledArtwork && find.byType(Image).evaluate().isNotEmpty) {
      final card = tester.renderObject<RenderBox>(find.byType(TabletTokenCard));
      final artPoint = card.localToGlobal(
        Offset(9, card.size.height / 2),
        ancestor: boundary,
      );
      expect(
        pixels.at(artPoint),
        [255, 255, 255, 255],
        reason:
            'The decoded white artwork must actually paint behind the card.',
      );
    }
    // Sample within the complete rounded hit area, including the five-pixel
    // outer padding. The old inner-only orange badge leaves these positions dark.
    final probes = <String, Offset>{
      'left strip': Offset(2, size.height / 2),
      'right strip': Offset(size.width - 3, size.height / 2),
      'top left corner': const Offset(3, 3),
      'top right corner': Offset(size.width - 4, 3),
      'bottom left corner': Offset(3, size.height - 4),
      'bottom right corner': Offset(size.width - 4, size.height - 4),
    };
    final records = <Map<String, Object>>[];
    final result = <List<int>>[];
    for (final probe in probes.entries) {
      final point = box.localToGlobal(probe.value, ancestor: boundary);
      final rgba = pixels.at(point);
      result.add(rgba);
      records.add({
        'probe': probe.key,
        'x': point.dx,
        'y': point.dy,
        'rgba': rgba,
      });
    }
    if (captureDirectory != null) {
      await tester.runAsync(
        () => File('$captureDirectory/$name.pixels.json').writeAsString(
          jsonEncode({
            'badgeWidth': size.width,
            'badgeHeight': size.height,
            'probes': records,
          }),
        ),
      );
    }
    return result;
  }

  void expectOrange(List<List<int>> pixels) {
    final orange = Colors.orange.shade800.toARGB32();
    final expected = [
      (orange >> 16) & 255,
      (orange >> 8) & 255,
      orange & 255,
      255,
    ];
    for (var probe = 0; probe < pixels.length; probe++) {
      for (var channel = 0; channel < 4; channel++) {
        expect(
          pixels[probe][channel],
          closeTo(expected[channel], 2),
          reason:
              'The full modified P/T backplate must be orange: '
              'edge/corner probe $probe, RGBA channel $channel.',
        );
      }
    }
  }

  final cases = [
    (
      name: 'phone-art-collapsed-2-2',
      phone: true,
      art: true,
      expanded: false,
      turns: 0,
      pt: '1/1',
      plus: 1,
      minus: 0,
      counters: <String, int>{},
      value: '2/2',
    ),
    (
      name: 'phone-art-expanded-negative',
      phone: true,
      art: true,
      expanded: true,
      turns: 0,
      pt: '1/1',
      plus: 0,
      minus: 3,
      counters: <String, int>{},
      value: '-2/-2',
    ),
    (
      name: 'phone-no-art-collapsed-wide',
      phone: true,
      art: false,
      expanded: false,
      turns: 0,
      pt: '99/199',
      plus: 1,
      minus: 0,
      counters: <String, int>{},
      value: '100/200',
    ),
    (
      name: 'phone-no-art-expanded-symbolic',
      phone: true,
      art: false,
      expanded: true,
      turns: 0,
      pt: '*/1+*',
      plus: 0,
      minus: 0,
      counters: <String, int>{'+1/+0': 1},
      value: '*+1/1+*',
    ),
    (
      name: 'tablet-art-rotated-2-2',
      phone: false,
      art: true,
      expanded: false,
      turns: 2,
      pt: '1/1',
      plus: 1,
      minus: 0,
      counters: <String, int>{},
      value: '2/2',
    ),
    (
      name: 'tablet-art-sideways-expanded',
      phone: false,
      art: true,
      expanded: true,
      turns: 1,
      pt: '12/9',
      plus: 0,
      minus: 0,
      counters: <String, int>{'+0/+1': 1},
      value: '12/10',
    ),
    (
      name: 'tablet-no-art-sideways-wide',
      phone: false,
      art: false,
      expanded: false,
      turns: 3,
      pt: '1000/1000',
      plus: 1,
      minus: 0,
      counters: <String, int>{},
      value: '1001/1001',
    ),
    (
      name: 'tablet-no-art-rotated-expanded-zero',
      phone: false,
      art: false,
      expanded: true,
      turns: 2,
      pt: '1/1',
      plus: 0,
      minus: 1,
      counters: <String, int>{},
      value: '0/0',
    ),
  ];
  for (final scene in cases) {
    testWidgets('complete P/T mask ${scene.name}', (tester) async {
      final fixture = TableFixture(
        stateWithTokens([
          sampleToken(
            name: 'Thopter',
            type: 'Artifact Creature — Thopter',
            colors: '',
            abilities: 'Flying',
            pt: scene.pt,
            plusOne: scene.plus,
            minusOne: scene.minus,
            counters: scene.counters,
            artworkUrl: scene.art ? _art : null,
          ),
        ]),
      );
      await showCard(
        tester,
        fixture,
        phone: scene.phone,
        expanded: scene.expanded,
        turns: scene.turns,
      );
      expect(find.text(scene.value), findsOneWidget);
      expectOrange(await edgePixels(tester, scene.name));
      expect(tester.takeException(), isNull);
    });
  }

  for (final art in [false, true]) {
    testWidgets('neutral P/T restores its pixels and footprint (art $art)', (
      tester,
    ) async {
      final fixture = TableFixture(
        stateWithTokens([
          sampleToken(
            name: 'Thopter',
            pt: '1/1',
            artworkUrl: art ? _art : null,
          ),
        ]),
      );
      await showCard(tester, fixture, phone: true);
      final originalSize = tester.getSize(badge());
      final scale = find.descendant(
        of: badge(),
        matching: find.byType(ScaleTransition),
      );
      final originalAnimation = tester.widget<ScaleTransition>(scale).scale;
      final ptWidget = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_PowerToughness',
      );
      final originalState = tester.state(ptWidget);
      final neutral = await edgePixels(tester, 'neutral-art-$art-before');
      await fixture.board.setCounter(fixture.playerId, 'source', '+1/+1', 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      expect(tester.state(ptWidget), same(originalState));
      expect(
        tester.widget<ScaleTransition>(scale).scale,
        same(originalAnimation),
      );
      expect(originalAnimation.value, greaterThan(1));
      expectOrange(
        await edgePixels(
          tester,
          'neutral-art-$art-first-counter-pop',
          expectSettledArtwork: false,
        ),
      );
      await settleArtwork(tester);
      expect(tester.getSize(badge()), originalSize);
      expectOrange(await edgePixels(tester, 'neutral-art-$art-modified'));
      await fixture.board.setCounter(fixture.playerId, 'source', '+1/+1', 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      expect(tester.state(ptWidget), same(originalState));
      expect(
        tester.widget<ScaleTransition>(scale).scale,
        same(originalAnimation),
      );
      expect(originalAnimation.value, greaterThan(1));
      await capture(tester, 'neutral-art-$art-last-counter-pop');
      await settleArtwork(tester);
      expect(tester.getSize(badge()), originalSize);
      expect(await edgePixels(tester, 'neutral-art-$art-restored'), neutral);
      await fixture.board.setCounter(fixture.playerId, 'source', '+1/+1', 1);
      await fixture.board.setCounter(fixture.playerId, 'source', '-1/-1', 1);
      await settleArtwork(tester);
      expect(find.text('1/1'), findsOneWidget);
      expect(fixture.token('source').plusOneCounters, 0);
      expect(fixture.token('source').minusOneCounters, 0);
      expect(tester.getSize(badge()), originalSize);
      expect(await edgePixels(tester, 'neutral-art-$art-cancelled'), neutral);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('full P/T badge retains expand and native edit targets', (
    tester,
  ) async {
    final fixture = TableFixture(
      stateWithTokens([
        sampleToken(name: 'Thopter', pt: '1/1', plusOne: 1, artworkUrl: _art),
      ]),
    );
    await showCard(tester, fixture, phone: true);
    await tester.tap(badge());
    await tester.pumpAndSettle();
    expect(
      tester.widget<TabletTokenCard>(find.byType(TabletTokenCard)).expanded,
      isTrue,
    );
    await tester.tap(badge());
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('native-inline-editor'));
    expect(input, findsOneWidget);
    await tester.enterText(input, '2/3');
    await tester.tap(find.byKey(const ValueKey('native-keyboard-done')));
    await settleArtwork(tester);
    expect(fixture.token('source').pt, '2/3');
    expect(fixture.token('source').plusOneCounters, 1);
    expect(find.text('3/4'), findsOneWidget);
    expectOrange(await edgePixels(tester, 'phone-edited-base-stats'));
    expect(tester.takeException(), isNull);
  });
}

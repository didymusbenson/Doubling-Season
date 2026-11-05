import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/services/tablet_media_store.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
const _inline = 'data:image/png;base64,$_png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  late String uploaded;
  const remote = 'https://example.test/reorder-stable.png';
  const replacement = 'https://example.test/reorder-replacement.png';
  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('artwork-reorder-');
    Hive.init(storage.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    final bytes = base64Decode(_png);
    uploaded = await TabletMediaStore.save(bytes);
    final cache = await Directory('${storage.path}/artwork_cache').create();
    await File(
      '${cache.path}/${md5.convert(utf8.encode(remote))}.jpg',
    ).writeAsBytes(bytes);
    await File(
      '${cache.path}/${md5.convert(utf8.encode(replacement))}.jpg',
    ).writeAsBytes(bytes);
    await TableArtwork.validatedBytes(remote);
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await Hive.close();
    await storage.delete(recursive: true);
  });

  void expectPainted(WidgetTester tester, {int? count}) {
    final artwork = find.byType(TableArtwork);
    if (count != null) expect(artwork, findsNWidgets(count));
    for (final element in artwork.evaluate()) {
      final images = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(RawImage),
      );
      expect(
        images,
        findsOneWidget,
        reason: 'Every visible art keeps its image.',
      );
      expect(tester.widget<RawImage>(images).image, isNotNull);
    }
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AnimatedOpacity && widget.opacity == 0,
      ),
      findsNothing,
      reason: 'A loaded image must not restart a hidden-to-visible fade.',
    );
  }

  Future<void> warmArtwork(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    for (final element in find.byType(Image).evaluate()) {
      await tester.runAsync(
        () => precacheImage((element.widget as Image).image, element),
      );
    }
    await tester.pumpAndSettle();
  }

  for (final kind in ['inline', 'uploaded', 'remote']) {
    testWidgets('$kind art survives first-frame proxy and remount', (
      tester,
    ) async {
      final source = switch (kind) {
        'uploaded' => uploaded,
        'remote' => remote,
        _ => _inline,
      };
      Widget view({bool proxy = false, int generation = 0}) => MaterialApp(
        home: Row(
          children: [
            for (var i = 0; i < (proxy ? 2 : 1); i++)
              SizedBox(
                key: ValueKey('$generation-$i'),
                width: 100,
                height: 100,
                child: TableArtwork(url: source),
              ),
          ],
        ),
      );
      await tester.pumpWidget(view());
      await warmArtwork(tester);
      expectPainted(tester, count: 1);
      final bytes =
          (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
      await tester.pumpWidget(view(proxy: true));
      expectPainted(tester, count: 2); // Do not settle away the regression.
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(identical((image.image as MemoryImage).bytes, bytes), isTrue);
      }
      await tester.pumpWidget(view(generation: 1));
      expectPainted(tester, count: 1);
      expect(
        identical(
          (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
          bytes,
        ),
        isTrue,
      );
      await tester.pumpWidget(view(generation: 2));
      expectPainted(tester, count: 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changing uploaded source never retains the preceding image', (
    tester,
  ) async {
    Widget view(String source) => MaterialApp(
      home: SizedBox(width: 100, height: 100, child: TableArtwork(url: source)),
    );
    await tester.pumpWidget(view(uploaded));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expectPainted(tester, count: 1);
    await tester.pumpWidget(view('tablet-art:missing-selection'));
    expect(find.byType(Image), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(TabletMediaStore.peek(uploaded), isNotNull);
  });

  testWidgets('changing remote source does not retain old snapshot data', (
    tester,
  ) async {
    Widget view(String source) => MaterialApp(
      home: SizedBox(width: 100, height: 100, child: TableArtwork(url: source)),
    );
    await tester.pumpWidget(view(remote));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expectPainted(tester, count: 1);
    final previous =
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    await tester.runAsync(() async {
      await tester.pumpWidget(view(replacement));
      expect(find.byType(Image), findsNothing);
      final bytes = await TableArtwork.validatedBytes(replacement);
      await precacheImage(
        MemoryImage(bytes),
        tester.element(find.byType(TableArtwork)),
      );
    });
    await tester.pumpAndSettle();
    expectPainted(tester, count: 1);
    final current =
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    expect(identical(current, previous), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final seat in [0, 1]) {
    testWidgets(
      'seat ${seat + 1} art stays painted throughout repeated real reorder',
      (tester) async {
        tester.view.physicalSize = const Size(1133, 744);
        tester.view.devicePixelRatio = 1;
        tester.view.display.size = const Size(1133, 744);
        tester.view.display.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(tester.view.display.reset);
        final state = TabletState.initial();
        for (var p = 0; p < state.session.players.length; p++) {
          state.session.players[p].tokens = [
            for (var i = 0; i < 2; i++)
              sampleToken(
                id: 'p$p-t$i',
                name: 'P$p image $i',
                type: '',
                artworkUrl: uploaded,
              ),
          ];
        }
        final fixture = TableFixture(state);
        await fixture.initialize();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: tableTheme(Brightness.dark),
            home: TableScreen(controller: fixture.controller),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expectPainted(tester, count: 8);
        final id = fixture.controller.session.players[seat].id;
        for (var repeat = 0; repeat < 2; repeat++) {
          final player = fixture.controller.player(id);
          final oldIds = player.tokens.map((t) => t.id).toList();
          final first = find.text(player.tokens.first.name);
          final second = find.text(player.tokens.last.name);
          final start = tester.getCenter(first);
          final direction = seat == 1 ? -1.0 : 1.0;
          final destination = Offset(
            start.dx,
            tester.getCenter(second).dy + direction * 24,
          );
          final gesture = await tester.startGesture(start);
          await tester.pump(const Duration(milliseconds: 600));
          expectPainted(tester);
          for (var step = 1; step <= 30; step++) {
            await gesture.moveTo(Offset.lerp(start, destination, step / 30)!);
            await tester.pump(const Duration(milliseconds: 16));
            expectPainted(tester);
          }
          await gesture.up();
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expectPainted(tester);
          }
          await tester.pumpAndSettle();
          expect(
            fixture.controller.player(id).tokens.map((t) => t.id),
            oldIds.reversed,
          );
          expectPainted(tester, count: 8);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

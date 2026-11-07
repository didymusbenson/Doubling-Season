import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/monarch_crown.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

const _captureKey = ValueKey('monarch-capture');

Rect _localRect(WidgetTester tester, Finder child, Finder ancestor) {
  final box = tester.renderObject<RenderBox>(child);
  return MatrixUtils.transformRect(
    box.getTransformTo(tester.renderObject<RenderBox>(ancestor)),
    Offset.zero & box.size,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  late Directory catalog;
  late String art;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('monarch-life-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 200),
      Paint()..color = const Color(0xFFF8E8B8),
    );
    canvas.drawCircle(
      const Offset(130, 100),
      90,
      Paint()..color = const Color(0xFF324767),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    art = 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
    image.dispose();
    picture.dispose();
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(
                '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<TableFixture> mount(
    WidgetTester tester, {
    int count = 4,
    Size size = const Size(1133, 744),
    Brightness brightness = Brightness.dark,
    int turns = 0,
    bool artwork = false,
    bool reducedMotion = false,
    double textScale = 1,
    bool statuses = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    await f.controller.resetGame(keepBoard: false, playerCount: count);
    for (final p in f.controller.session.players) {
      if (artwork) f.controller.profile(p.seatId).artworkUrl = art;
      p.tokens = [
        sampleToken(id: '${p.id}-token', name: 'Saproling', plusOne: 2),
        sampleToken(id: '${p.id}-soldier', name: 'Soldier', colors: 'W'),
      ];
      if (statuses) {
        p.citysBlessing = true;
        p.counters = {'energy': 12, 'poison': 3, 'experience': 7};
        p.utilities.add(
          UtilityState(
            id: '${p.id}-initiative',
            kind: 'initiative',
            name: 'The Initiative',
            isActive: true,
          ),
        );
      }
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tableTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: RotatedBox(
            quarterTurns: turns,
            child: TableScreen(controller: f.controller),
          ),
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

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final context = tester.element(find.byType(TableScreen));
    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .toList();
    await tester.runAsync(
      () => Future.wait(providers.map((p) => precacheImage(p, context))),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$captures/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final count in [2, 3, 4, 5, 6]) {
    for (final size in [
      const Size(1133, 744),
      const Size(744, 1133),
      const Size(1366, 1024),
    ]) {
      for (final brightness in Brightness.values) {
        testWidgets('crown follows each of $count seats at $size $brightness', (
          tester,
        ) async {
          final f = await mount(
            tester,
            count: count,
            size: size,
            brightness: brightness,
          );
          for (final player in f.controller.session.players) {
            final surface = find.byKey(ValueKey('${player.id}-life-surface'));
            final total = find.byKey(ValueKey('${player.id}-life-number'));
            final before = _localRect(tester, total, surface);
            expect(await f.controller.setMonarch(player.id), isTrue);
            await tester.pumpAndSettle();
            final crown = find.byKey(ValueKey('${player.id}-monarch-crown'));
            expect(
              find.byWidgetPredicate((w) => w is MonarchCrown && w.worn),
              findsOneWidget,
            );
            expect(crown, findsOneWidget);
            expect(
              _localRect(tester, total, surface),
              before,
              reason: 'Claiming Monarch must not resize or shift life.',
            );
            final bounds = _localRect(tester, crown, surface);
            final lifeBounds = Offset.zero & tester.getSize(surface);
            expect(lifeBounds.contains(bounds.topLeft), isTrue);
            expect(lifeBounds.contains(bounds.bottomRight), isTrue);
            expect(bounds.center.dx, lessThan(before.center.dx));
            expect(bounds.center.dy, lessThan(before.center.dy));
            expect(bounds.bottom, greaterThan(before.top));
            final ledger = find.byKey(
              ValueKey('${player.id}-commander-ledger'),
            );
            expect(
              bounds.overlaps(_localRect(tester, ledger, surface)),
              isFalse,
            );
            final name = find.byKey(ValueKey('${player.id}-player-name'));
            expect(bounds.overlaps(_localRect(tester, name, surface)), isFalse);
            final summary = find.byKey(
              ValueKey('${player.id}-life-counter-summary'),
            );
            expect(
              find.descendant(of: summary, matching: find.byType(MonarchCrown)),
              findsNothing,
            );
            final stepper = tester.widget<HalfStepper>(
              find.descendant(of: surface, matching: find.byType(HalfStepper)),
            );
            expect(stepper.value, contains('Monarch'));
            final beforeLife = f.controller.player(player.id).life;
            await tester.tapAt(tester.getCenter(crown));
            await tester.pumpAndSettle();
            expect(
              f.controller.player(player.id).life,
              beforeLife - 1,
              reason: 'A decorative crown must not steal the life tap.',
            );
            expect(f.controller.session.monarchPlayerId, player.id);
            await tester.tap(ledger);
            await tester.pumpAndSettle();
            expect(byControlLabel('Monarch, On'), findsOneWidget);
            await tester.tap(byControlLabel('Close workspace'));
            await tester.pumpAndSettle();
            expect(
              f.controller.player(player.id).life,
              beforeLife - 1,
              reason: 'Closing the status editor must consume its tap.',
            );
            expect(tester.takeException(), isNull);
          }
          await f.controller.setMonarch(f.playerId);
          await tester.pumpAndSettle();
          await capture(
            tester,
            'monarch-${count}p-${size.width.toInt()}x${size.height.toInt()}-${brightness.name}',
          );
        });
      }
    }
  }

  testWidgets(
    'Monarch-only claim removes duplicate badge, clears and undoes durably',
    (tester) async {
      final f = await mount(tester, statuses: false);
      final p = f.playerId;
      final ledger = find.byKey(ValueKey('$p-commander-ledger'));
      await tester.tap(ledger);
      await tester.pumpAndSettle();
      await tester.tap(byControlLabel('Monarch, Off'));
      await tester.pumpAndSettle();
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('$p-life-counter-summary')), findsNothing);
      expect(find.byKey(ValueKey('$p-monarch-crown')), findsOneWidget);
      final surface = find.byKey(ValueKey('$p-life-surface'));
      expect(
        _localRect(tester, ledger, surface).center.dx,
        closeTo(tester.getSize(surface).width / 2, .01),
      );
      await tester.tap(ledger);
      await tester.pumpAndSettle();
      await tester.longPress(byControlLabel('Monarch, On'));
      await tester.pumpAndSettle();
      expect(f.controller.session.monarchPlayerId, isNull);
      expect(find.byKey(ValueKey('$p-monarch-crown')), findsNothing);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      expect(await f.controller.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('$p-monarch-crown')), findsOneWidget);
      expect((await f.repository.open()).state.session.monarchPlayerId, p);
      f.repository.failSave = true;
      expect(await f.controller.setMonarch(null), isFalse);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('$p-monarch-crown')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final turns in [0, 1]) {
    testWidgets(
      'long signed totals, artwork, scaling and reduced motion at rotation $turns',
      (tester) async {
        final f = await mount(
          tester,
          count: 6,
          size: const Size(768, 1024),
          turns: turns,
          artwork: true,
          reducedMotion: true,
          textScale: 1.5,
        );
        for (final value in [0, -9, 999, -99999]) {
          for (final p in f.controller.session.players) {
            expect(
              await f.controller.updateState('Set test life and Monarch', (s) {
                s.session.monarchPlayerId = p.id;
                s.session.players.firstWhere((v) => v.id == p.id).life = value;
              }),
              isTrue,
            );
            await tester.pumpAndSettle();
            final crown = find.byKey(ValueKey('${p.id}-monarch-crown'));
            final animation = tester.widget<TweenAnimationBuilder<double>>(
              crown,
            );
            expect(animation.duration, Duration.zero);
            final surface = find.byKey(ValueKey('${p.id}-life-surface'));
            final bounds = _localRect(tester, crown, surface);
            expect(bounds.width, greaterThan(0));
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.top, greaterThanOrEqualTo(0));
            expect(
              bounds.bottom,
              lessThan(tester.getSize(surface).height - 50),
            );
            expect(tester.takeException(), isNull);
          }
        }
        await capture(tester, 'monarch-long-artwork-rotation$turns');
      },
    );
  }
}

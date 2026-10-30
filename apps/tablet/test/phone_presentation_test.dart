import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_presentation.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  setUp(() async {
    cache = await Directory.systemTemp.createTemp('phone-presentation-');
    Hive.init(cache.path);
  });
  tearDown(() async {
    await Hive.close();
    await cache.delete(recursive: true);
  });

  test(
    'presentation uses physical device size, not a narrow tablet window',
    () {
      bool mode(
        Size display,
        Size window, {
        bool web = false,
        bool preview = false,
      }) => TablePresentation.compact(
        display: display,
        window: window,
        web: web,
        webPhonePreview: preview,
      );
      expect(mode(const Size(390, 844), const Size(390, 844)), isTrue);
      expect(mode(const Size(844, 390), const Size(844, 390)), isTrue);
      expect(mode(const Size(834, 1194), const Size(390, 844)), isFalse);
      expect(mode(const Size(820, 1000), const Size(820, 1000)), isFalse);
      expect(
        mode(const Size(1440, 900), const Size(390, 844), web: true),
        isFalse,
      );
      expect(
        mode(
          const Size(1440, 900),
          const Size(390, 844),
          web: true,
          preview: true,
        ),
        isTrue,
      );
      expect(
        mode(
          const Size(1440, 900),
          const Size(900, 800),
          web: true,
          preview: true,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'fixed Player 1 view has one body and C controls without changing N',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = TabletState.initial();
      final id = state.session.players.first.id;
      state.session.players.first.tokens.add(sampleToken(id: 'phone-token'));
      final f = TableFixture(state);
      await f.initialize();
      addTearDown(f.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TableScreen(
            controller: f.controller,
            enablePhonePresentation: true,
            compactPlayerOne: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('phone-player-one')), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('phone-player-one-scroll')),
        findsOneWidget,
      );
      for (final name in ['more', 'utilities', 'add-token']) {
        expect(
          find.byKey(ValueKey('phone-action-$name')).hitTestable(),
          findsOneWidget,
        );
      }
      expect(f.controller.session.players.length, 4);
      final before = f.controller.player(id).life;
      await tester.tap(find.byKey(ValueKey('$id-life-increase')));
      await tester.pumpAndSettle();
      expect(f.controller.player(id).life, before + 1);
      expect(
        f.controller.session.players.skip(1).every((p) => p.life == before),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('phone-action-more')));
      await tester.pumpAndSettle();
      expect(find.text('Game history & undo'), findsOneWidget);
      expect(find.text('Player 1 settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('posture change closes More and preserves session and board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    addTearDown(f.dispose);
    final session = f.controller.session.id;
    final players = f.controller.session.players.map((p) => p.id).toList();
    bool compact = true;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return TableScreen(
              controller: f.controller,
              enablePhonePresentation: true,
              compactPlayerOne: compact,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('phone-action-more')));
    await tester.pumpAndSettle();
    change(() => compact = false);
    tester.view.physicalSize = const Size(1133, 744);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-more-menu')), findsNothing);
    expect(f.controller.session.id, session);
    expect(f.controller.session.players.map((p) => p.id).toList(), players);
    change(() => compact = true);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('phone-action-more')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('phone-more-menu')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('posture keyboard dismissal retains text without committing it', (
    tester,
  ) async {
    final text = TextEditingController(text: 'Unfinished name');
    addTearDown(text.dispose);
    int commits = 0;
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    final result = showPlayerKeyboardEditor(
      host,
      title: 'Player 1 token name',
      value: text.text,
      controller: text,
      onChanged: (_) {},
      onCommit: (_) async {
        commits++;
      },
    );
    await tester.pumpAndSettle();
    final close = dismissPlayerKeyboardForPresentationChange();
    await tester.pumpAndSettle();
    await close;
    expect(await result, isFalse);
    expect(commits, 0);
    expect(text.text, 'Unfinished name');
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('phone content and C pod fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await f.board.addUtility(f.playerId, 'mana_pool');
      await f.board.addUtility(f.playerId, 'storm_count');
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: TableScreen(
              controller: f.controller,
              enablePhonePresentation: true,
              compactPlayerOne: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['more', 'utilities', 'add-token']) {
        final finder = find.byKey(ValueKey('phone-action-$name'));
        expect(finder.hitTestable(), findsOneWidget);
        final rect = tester.getRect(finder);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      await tester.tap(find.byKey(const ValueKey('phone-action-more')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['PHONE_CAPTURE_DIR'];
      if (directory != null) {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await tester.runAsync(() async {
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/phone-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
    });
  }
}

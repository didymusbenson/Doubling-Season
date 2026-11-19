import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/features/ring_service.dart';
import 'package:tripling_table/ui/ring_inline.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';
import 'support/control_finders.dart';

final captureDirectory = Platform.environment['UTILITY_PICKER_CAPTURES'];
const captureKey = ValueKey('utility-picker-capture');

Future<void> capture(WidgetTester tester, String name) async {
  if (captureDirectory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        '$captureDirectory/$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    if (captureDirectory == null) return;
    await Directory(captureDirectory!).create(recursive: true);
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
  testWidgets(
    'Ring shows cumulative rules through and beyond four temptations',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final utility = UtilityState(
        id: 'ring',
        kind: 'the_ring',
        name: 'The Ring',
      );
      var taps = 0;
      for (final count in [0, 1, 2, 3, 4, 5, 2, 0]) {
        utility.value = count;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 180,
                  child: RingInline(utility: utility, onTempt: () => taps++),
                ),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('ring-next-ability-ring')),
          count == 0 ? findsOneWidget : findsNothing,
        );
        for (var i = 0; i < 4; i++) {
          expect(
            find.byKey(ValueKey('ring-active-ability-ring-$i')),
            i < count.clamp(0, 4) ? findsOneWidget : findsNothing,
          );
          if (i < count.clamp(0, 4)) {
            expect(
              find.text('${i + 1}. ${RingService.reminders[i]}'),
              findsOneWidget,
            );
          }
        }
        expect(
          find.textContaining(RegExp(r'^\d+ temptations?$')),
          findsNothing,
        );
        expect(find.text('Tempt'), findsOneWidget);
        expect(find.text('Next temptation'), findsNothing);
        final tempt = find.byKey(const ValueKey('ring-tempt-ring'));
        await tester.ensureVisible(tempt);
        expect(tester.getSemantics(tempt).label, 'Tempt');
        await tester.tap(tempt);
        expect(tester.takeException(), isNull);
      }
      expect(taps, 8);
      semantics.dispose();
    },
  );

  Future<TableFixture> open(
    WidgetTester tester, {
    Size size = const Size(1133, 744),
    double scale = 1,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    f.catalog.loaded = true;
    addTearDown(() async {
      final close = byControlLabel('Close workspace');
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(brightness),
        builder: (context, child) => RepaintBoundary(
          key: captureKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                f.controller,
                catalog: f.catalog,
                seatId: f.playerId,
                initialPage: WorkspacePage.utilities,
              ),
              child: const Text('Open utilities'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open utilities'));
    await tester.pumpAndSettle();
    return f;
  }

  Finder toggle(String id) => find.byKey(ValueKey('utility-toggle-$id'));
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  void search(WidgetTester tester, String query) {
    tester
            .widget<PlayerField>(
              find.byKey(const ValueKey('utility-picker-search')),
            )
            .controller
            .text =
        query;
  }

  testWidgets(
    'one toggle list keeps hidden configuration and seat state through reload',
    (tester) async {
      final f = await open(tester);
      final otherId = f.controller.session.players.last.id;
      await f.board.addUtility(otherId, RingService.kind);
      final other = f.controller.player(otherId).toJson();
      expect(find.text('Add a utility'), findsNothing);
      search(tester, 'ring');
      await tester.pumpAndSettle();
      final beforeY = tester.getTopLeft(toggle('the_ring')).dy;
      await tap(tester, toggle('the_ring'));
      final ringId = f.player.utilities.last.id;
      expect(tester.getTopLeft(toggle(ringId)).dy, beforeY);
      expect(tester.widget<Switch>(toggle(ringId)).value, isTrue);
      await RingService(
        f.controller,
      ).tempt(f.playerId, ringId, bearer: 'Frodo');
      await f.board.setUtility(
        f.playerId,
        ringId,
        name: 'My precious',
        description: 'Saved notes',
        configuration: {
          'custom': {'keep': true},
        },
      );
      await tester.pumpAndSettle();
      final before = f.player.utilities.last.toJson();
      await tap(tester, toggle(ringId));
      expect(f.player.utilities.last.toJson(), {...before, 'visible': false});
      expect(f.board.isUtilityVisible(f.player.utilities.last), isFalse);
      expect(tester.widget<Switch>(toggle(ringId)).value, isFalse);
      await tap(tester, toggle(ringId));
      expect(f.player.utilities.last.toJson(), before);
      expect(f.controller.player(otherId).toJson(), other);
      final reopened = TableController(repository: f.repository);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.player(f.playerId).utilities.last.toJson(), before);
      expect(tester.takeException(), isNull);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Utilities restores a filtered scrolled picker without changing the selected seat',
    (tester) async {
      final f = await open(tester, size: const Size(540, 460));
      search(tester, 'a');
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .widget<ListView>(find.byType(ListView).first)
          .controller!
          .position;
      expect(position().maxScrollExtent, greaterThan(0));
      position().jumpTo(position().maxScrollExtent);
      await tester.pumpAndSettle();
      final offset = position().pixels;
      final other = f.controller.session.players[1].toJson();
      final row = find
          .byWidgetPredicate(
            (w) => w is ListTile && w.key.toString().contains('utility-open-'),
          )
          .hitTestable()
          .last;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('utility-panel-title')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('utility-back')));
      expect(
        tester
            .widget<PlayerField>(
              find.byKey(const ValueKey('utility-picker-search')),
            )
            .controller
            .text,
        'a',
      );
      expect(position().pixels, closeTo(offset, 1));
      expect(f.controller.session.players[1].toJson(), other);
      await tap(tester, byControlLabel('Close workspace'));
    },
  );

  testWidgets(
    'picker row opens hidden controls without switching on the board',
    (tester) async {
      final f = await open(tester);
      search(tester, 'The Ring');
      await tester.pumpAndSettle();
      expect(find.text('Hidden from board'), findsNothing);
      expect(find.text('Shown on board'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(byControlLabel('Show The Ring on board'), findsOneWidget);

      await tap(tester, find.byKey(const ValueKey('utility-open-the_ring')));
      final ring = f.player.utilities.singleWhere(
        (u) => u.kind == RingService.kind,
      );
      expect(ring.visible, isFalse);
      expect(find.byKey(const ValueKey('utility-picker-search')), findsNothing);

      await tap(tester, find.byKey(const ValueKey('utility-back')));
      expect(tester.widget<Switch>(toggle(ring.id)).value, isFalse);
      await tap(tester, toggle(ring.id));
      expect(
        f.player.utilities.singleWhere((u) => u.id == ring.id).visible,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('utility-picker-search')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tap(tester, byControlLabel('Close workspace'));
    },
  );

  testWidgets(
    'Ring defaults to card art and only replaces the old built-in artwork',
    (tester) async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await f.board.addUtility(f.playerId, RingService.kind);
      final ring = f.player.utilities.singleWhere(
        (u) => u.kind == RingService.kind,
      );
      expect(ring.artworkUrl, RingService.artworkUrl);
      expect(Uri.parse(ring.artworkUrl!).path, startsWith('/art/'));
      expect(
        (ring.configuration['artworkOptions'] as List).single['artist'],
        'Veli Nyström',
      );

      const old =
          'https://cards.scryfall.io/large/front/7/2/'
          '7215460e-8c06-47d0-94e5-d1832d0218af.jpg';
      final restored = UtilityState.fromJson({
        ...ring.toJson(),
        'artworkUrl': old,
      });
      expect(restored.displayedArtworkUrl, RingService.artworkUrl);
      expect(restored.toJson()['artworkUrl'], old);
      expect(
        UtilityState.fromJson({
          ...restored.toJson(),
          'kind': 'custom',
        }).displayedArtworkUrl,
        old,
      );

      restored.artworkUrl = 'tablet-art:custom-art';
      expect(restored.displayedArtworkUrl, 'tablet-art:custom-art');
      restored.artworkUrl = null;
      expect(restored.displayedArtworkUrl, isNull);
    },
  );

  testWidgets(
    'search applies to every saved or available utility without changing order',
    (tester) async {
      final f = await open(tester);
      await f.board.addUtility(f.playerId, 'krenko_mob_boss');
      final id = f.player.utilities.last.id;
      await f.board.setUtility(
        f.playerId,
        id,
        name: 'Renamed utility',
        description: 'Personal note',
      );
      await tester.pumpAndSettle();
      for (final query in ['Krenko, Mob Boss', 'renamed', 'personal note']) {
        search(tester, query);
        await tester.pumpAndSettle();
        expect(toggle(id), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
      }
      search(tester, ' no such utility ');
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.text('No utilities match your search.'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsWidgets);
      search(tester, 'ring');
      await tester.pumpAndSettle();
      expect(toggle('the_ring'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'toggle failures keep saved state and duplicates remain independently editable',
    (tester) async {
      final f = await open(tester);
      await f.board.addUtility(f.playerId, 'krenko_mob_boss');
      await f.board.addUtility(f.playerId, 'krenko_mob_boss');
      search(tester, 'Krenko, Mob Boss');
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(2));
      final ids = f.player.utilities
          .where((u) => u.kind == 'krenko_mob_boss')
          .map((u) => u.id)
          .toList();
      final before = f.player.utilities.map((u) => u.toJson()).toList();
      f.repository.failSave = true;
      await tap(tester, toggle(ids.first));
      expect(f.player.utilities.map((u) => u.toJson()).toList(), before);
      expect(tester.widget<Switch>(toggle(ids.first)).value, isTrue);
      f.repository.failSave = false;
      await tap(tester, toggle(ids.first));
      expect(
        f.player.utilities.firstWhere((u) => u.id == ids.first).visible,
        isFalse,
      );
      expect(
        f.player.utilities.firstWhere((u) => u.id == ids.last).visible,
        isTrue,
      );
      expect(find.byKey(ValueKey('utility-open-${ids.first}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
    },
  );

  for (final size in [
    const Size(320, 700),
    const Size(744, 1133),
    const Size(1133, 744),
  ]) {
    testWidgets('header and full-width search have separate space at $size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      final f = await open(
        tester,
        size: size,
        scale: size.width == 320 ? 1.5 : 1,
      );
      await capture(
        tester,
        'picker-${size.width.toInt()}x${size.height.toInt()}',
      );
      final heading = tester.getRect(
        find.byKey(const ValueKey('utility-picker-heading')),
      );
      final searchBox = tester.getRect(
        find.byKey(const ValueKey('utility-picker-search')),
      );
      expect(searchBox.top - heading.bottom, greaterThanOrEqualTo(12));
      final modal = tester.getRect(
        find.byKey(const ValueKey('context-workspace')),
      );
      expect(searchBox.width, closeTo(modal.width - 40, .01));
      search(tester, 'Storm');
      await tester.pumpAndSettle();
      final storm = f.player.utilities.firstWhere(
        (u) => u.kind == 'storm_count',
      );
      final target = toggle(storm.id);
      await tap(tester, target);
      expect(
        f.player.utilities.firstWhere((u) => u.id == storm.id).visible,
        isFalse,
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
    });
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/commander_ledger.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  String? captureArtwork;
  setUpAll(() async {
    if (captures == null) return;
    await Directory(captures).create(recursive: true);
    final artFile = Platform.environment['TABLET_CAPTURE_ART_FILE'];
    if (artFile != null) {
      captureArtwork =
          'data:image/jpeg;base64,${base64Encode(await File(artFile).readAsBytes())}';
    }
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
  Future<TableFixture> open(
    WidgetTester tester,
    Size size,
    int seats,
    int turns, {
    int sources = 2,
    bool artwork = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    for (final profile in state.profiles) {
      profile.name = '${profile.name} with an exceptionally long display name';
      if (artwork) {
        // Opaque white tests strongest contrast without network dependencies.
        // Optional local art produces real visual-review evidence only.
        profile.artworkUrl =
            captureArtwork ??
            'data:image/png;base64,'
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC';
      }
    }
    state.session.players = state.session.players.take(seats).toList();
    state.session.commanders = [
      for (final p in state.session.players)
        for (var n = 0; n < sources; n++)
          CommanderSource(
            id: '${p.id}-commander-$n',
            ownerPlayerId: p.id,
            name: n == 0 ? 'Very long commander name' : 'Partner commander',
          ),
    ];
    final f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-focused-commander'),
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  f.controller,
                  catalog: f.catalog,
                  seatId: f.controller.session.players.first.id,
                  quarterTurns: turns,
                  initialPage: WorkspacePage.commanderDamage,
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
    addTearDown(() async {
      if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
    return f;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .toList();
    if (providers.isNotEmpty) {
      final context = tester.element(
        find.byKey(const ValueKey('capture-focused-commander')),
      );
      await tester.runAsync(
        () => Future.wait(
          providers.map((provider) => precacheImage(provider, context)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObjectList<RenderImage>(find.byType(RawImage))
            .where((image) => image.image != null)
            .length,
        providers.length,
        reason: 'Capture only after every owner artwork decodes',
      );
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture-focused-commander')),
    );
    final pendingImage = boundary.toImage(pixelRatio: 1);
    await tester.runAsync(() async {
      final image = await pendingImage;
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$captures/$name.png').writeAsBytes(png.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(600, 1024),
    const Size(844, 390),
    const Size(650, 480),
    const Size(1133, 744),
  ]) {
    for (final seats in [2, 3, 4]) {
      for (final turns in [0, 1, 2, 3]) {
        testWidgets(
          '$seats owners max partners $size rotation $turns fit without scroll',
          (tester) async {
            final f = await open(tester, size, seats, turns);
            final grid = find.byKey(const ValueKey('focused-commander-grid'));
            expect(grid, findsOneWidget);
            expect(find.byType(ChoiceChip), findsNothing);
            expect(
              find.descendant(of: grid, matching: find.byType(Scrollable)),
              findsNothing,
            );
            Rect painted(Finder finder) {
              final box = tester.renderObject<RenderBox>(finder);
              return MatrixUtils.transformRect(
                box.getTransformTo(null),
                Offset.zero & box.size,
              );
            }

            final surface = painted(
              find.byKey(const ValueKey('commander-workspace')),
            );
            for (final source
                in f.controller.session.commanderTrackingSources) {
              for (final prefix in [
                'commander-increase-',
                'commander-decrease-',
                'commander-edit-',
              ]) {
                final target = find.byKey(ValueKey('$prefix${source.id}'));
                expect(target.hitTestable(), findsOneWidget);
                final rect = painted(target);
                expect(rect.width, greaterThanOrEqualTo(44 - .000001));
                expect(rect.height, greaterThanOrEqualTo(44 - .000001));
                expect(surface.inflate(.01).contains(rect.topLeft), isTrue);
                expect(surface.inflate(.01).contains(rect.bottomRight), isTrue);
              }
            }
            final gridBounds = tester.renderObject<RenderBox>(grid).size;
            final lastOwner = f.controller.session.players.last;
            final ownerBox = tester.renderObject<RenderBox>(
              find.byKey(ValueKey('commander-owner-${lastOwner.id}')),
            );
            final rows = CommanderSeatLayout.rowsFor(
              f.controller.session.players,
              turns,
            ).length;
            expect(
              ownerBox.size.height * rows + (rows - 1) * 6,
              closeTo(gridBounds.height, .01),
              reason:
                  'Artwork tiles fill the grid instead of clumping at its top',
            );
            final expected = CommanderSeatLayout.rowsFor(
              f.controller.session.players,
              turns,
            );
            final gridBox = tester.renderObject<RenderBox>(grid);
            Offset center(PlayerState p) => gridBox.globalToLocal(
              tester.getCenter(find.byKey(ValueKey('commander-owner-${p.id}'))),
            );
            for (var row = 0; row < expected.length; row++) {
              final active = expected[row].whereType<PlayerState>().toList();
              if (active.length == 2) {
                expect(
                  center(active.first).dx,
                  lessThan(center(active.last).dx),
                );
              }
              if (row > 0 && active.isNotEmpty) {
                final previous = expected[row - 1]
                    .whereType<PlayerState>()
                    .first;
                expect(center(previous).dy, lessThan(center(active.first).dy));
              }
            }
            final source = f.controller.session.commanderTrackingSources.first;
            final recipient = f.controller.session.players.first;
            await tester.tap(
              find.byKey(ValueKey('commander-increase-${source.id}')),
            );
            await tester.pumpAndSettle();
            expect(f.controller.player(recipient.id).life, 39);
            expect(
              f.controller.player(recipient.id).commanderDamage[source.id],
              1,
            );
            await tester.tap(find.byTooltip('Undo latest action'));
            await tester.pumpAndSettle();
            expect(f.controller.player(recipient.id).life, 40);
            expect(
              f.controller.player(recipient.id).commanderDamage[source.id] ?? 0,
              0,
            );
            expect(tester.takeException(), isNull);
            if (seats == 4 && turns == 0) {
              await capture(
                tester,
                'commander-${size.width.toInt()}x${size.height.toInt()}-max8-scale13',
              );
            }
            await tester.tap(find.byTooltip('Close workspace'));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Close workspace'), findsNothing);
          },
        );
      }
    }
  }
  testWidgets(
    'artwork partners retain separate values and accessible actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final f = await open(tester, const Size(744, 1133), 4, 2, artwork: true);
      final sources = f.controller.session.commanderTrackingSources;
      final recipient = f.controller.session.players.first;
      final a = sources[0];
      final b = sources[1];
      for (final id in [a.id, b.id, b.id]) {
        await tester.tap(find.byKey(ValueKey('commander-increase-$id')));
        await tester.pumpAndSettle();
      }
      expect(f.controller.player(recipient.id).commanderDamage[a.id], 1);
      expect(f.controller.player(recipient.id).commanderDamage[b.id], 2);
      expect(f.controller.player(recipient.id).life, 37);
      final decrease = find.byKey(ValueKey('commander-decrease-${b.id}'));
      final node = tester.getSemantics(decrease);
      expect(node.label, contains('restore one life'));
      expect(node.value, '2');
      await tester.tap(decrease);
      await tester.pumpAndSettle();
      expect(f.controller.player(recipient.id).commanderDamage[a.id], 1);
      expect(f.controller.player(recipient.id).commanderDamage[b.id], 1);
      expect(f.controller.player(recipient.id).life, 38);
      expect(
        find.byType(Image),
        findsNWidgets(4),
        reason: 'Partners share one artwork surface per owner',
      );
      await capture(tester, 'commander-art-partners-744x1133-rotation2');
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final turns in [0, 1, 2, 3]) {
      testWidgets(
        'artwork owner grid $size rotation $turns retains every partner',
        (tester) async {
          final fixture = await open(tester, size, 4, turns, artwork: true);
          expect(
            find.byKey(const ValueKey('focused-commander-grid')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('commander-density-fallback')),
            findsNothing,
          );
          expect(find.byType(Image), findsNWidgets(4));
          for (final source
              in fixture.controller.session.commanderTrackingSources) {
            expect(
              find
                  .byKey(ValueKey('commander-increase-${source.id}'))
                  .hitTestable(),
              findsOneWidget,
            );
            expect(
              find
                  .byKey(ValueKey('commander-decrease-${source.id}'))
                  .hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('commander-edit-${source.id}')).hitTestable(),
              findsOneWidget,
            );
          }
          await capture(
            tester,
            'commander-art-${size.width.toInt()}x${size.height.toInt()}-rotation$turns',
          );
          await tester.tap(find.byTooltip('Close workspace'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'over-density keeps every source accessible without mutating game',
    (tester) async {
      final f = await open(tester, const Size(600, 1024), 4, 0, sources: 3);
      expect(
        find.byKey(const ValueKey('commander-density-fallback')),
        findsOneWidget,
      );
      expect(f.controller.session.commanderTrackingSources.length, 12);
      expect(f.controller.session.history, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'single-source owners stay visible and edit only corrects ledger',
    (tester) async {
      final f = await open(tester, const Size(600, 1024), 4, 0, sources: 1);
      final recipient = f.controller.session.players.first;
      final source = f.controller.session.commanderTrackingSources.last;
      expect(
        find.byKey(const ValueKey('focused-commander-grid')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('commander-increase-${source.id}')));
      await tester.pumpAndSettle();
      expect(f.controller.player(recipient.id).life, 39);
      await tester.tap(find.byKey(ValueKey('commander-edit-${source.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Record damage'), findsNothing);
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Set damage total',
      );
      tester.widget<TextField>(field).controller!.text = '7';
      final correction = find.text('Correct ledger only');
      await tester.ensureVisible(correction);
      await tester.tap(correction);
      await tester.pumpAndSettle();
      expect(f.controller.player(recipient.id).life, 39);
      expect(f.controller.player(recipient.id).commanderDamage[source.id], 7);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('focused-commander-grid')),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
    },
  );
}

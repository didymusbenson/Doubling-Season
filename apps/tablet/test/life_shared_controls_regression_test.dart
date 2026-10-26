import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalog;
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  String? captureArt;
  const artSource =
      'https://cards.scryfall.io/large/front/e/a/ea630ba1-22f9-4a10-bdc6-0d03128214f4.jpg?1726285123';
  // Optional local evidence asset: Scute Swarm (DSC), Alex Konstad.
  // Production-equivalent art_crop/front/e/a/ea630ba1-22f9-4a10-bdc6-0d03128214f4.jpg?1726285123
  // SHA256 39931b6a7567d7ee87f63a12e886edc6886ea2e230d1dc82389512d8b7897004.
  // Asset is not committed and tests do not require a network download.
  setUpAll(() async {
    final artFile = Platform.environment['TABLET_CAPTURE_ART_FILE'];
    if (artFile != null) {
      captureArt =
          'data:image/jpeg;base64,${base64Encode(await File(artFile).readAsBytes())}';
    }
    catalog = await Directory.systemTemp.createTemp('shared-controls-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
      for (final f in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${f.value}',
        );
        await (FontLoader(
          f.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });
  Future<TableFixture> show(
    WidgetTester tester,
    Size size,
    int seats, {
    int empty = 0,
    bool safeArea = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = safeArea
        ? const FakeViewPadding(top: 24, bottom: 20)
        : const FakeViewPadding();
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    }
    if (seats == 3) state.session.players.removeAt(empty);
    for (final p in state.session.players) {
      p.tokens = [
        for (var i = 0; i < 4; i++)
          sampleToken(
            id: '${p.id}-$i',
            name: 'Scute Swarm $i',
            type: 'Creature — Insect',
            artworkUrl: captureArt,
            abilities:
                'Landfall — Whenever a land you control enters, create a 1/1 green Insect creature token. If you control six or more lands, create a token that is a copy of Scute Swarm instead.',
          ),
      ];
      if (captureArt != null) {
        for (var i = 0; i < p.tokens.length; i++) {
          final token = p.tokens[i];
          token.artworkSet = 'DSC';
          token.artworkOptions = [
            {
              'url': captureArt,
              'set': 'DSC',
              'artist': 'Alex Konstad',
              'source': artSource,
            },
          ];
          token.extra['artworkDisplayStyle'] = i.isEven ? 'fadeout' : 'full';
        }
      }
    }
    final f = TableFixture(state);
    await f.initialize();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: f.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    });
    return f;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    // Decode the actual rendered providers outside fake test time, then wait
    // for their fade-in frame before recording visual evidence.
    if (captureArt != null) {
      final context = tester.element(find.byType(TableScreen));
      final providers = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .toList();
      await tester.runAsync(
        () => Future.wait(
          providers.map((provider) => precacheImage(provider, context)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObjectList<RenderImage>(find.byType(RawImage))
            .any((image) => image.image != null),
        isTrue,
      );
    }
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
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

  Rect localRect(WidgetTester tester, Finder child, Finder ancestor) {
    final box = tester.renderObject<RenderBox>(child);
    final parent = tester.renderObject<RenderBox>(ancestor);
    return MatrixUtils.transformRect(
      box.getTransformTo(parent),
      Offset.zero & box.size,
    );
  }

  for (final size in [
    const Size(744, 1133),
    const Size(1133, 744),
    const Size(1024, 768),
  ]) {
    for (final seats in [2, 3, 4]) {
      for (final empty in seats == 3 ? [0, 1, 2, 3] : [0]) {
        testWidgets(
          '$seats seats empty$empty $size shared clearance and signed delta',
          (tester) async {
            final f = await show(tester, size, seats, empty: empty);
            final hub = find.byKey(const ValueKey('central-game-controls'));
            final table = find.byKey(const ValueKey('table-surface'));
            expect(tester.getRect(hub).center, tester.getRect(table).center);
            final dice = find.byKey(const ValueKey('shared-dice'));
            final day = find.byKey(const ValueKey('shared-day-night'));
            for (final control in [dice, day]) {
              expect(tester.getSize(control), const Size(44, 44));
              expect(control.hitTestable(), findsOneWidget);
              expect(
                tester.getRect(control).overlaps(tester.getRect(hub)),
                isFalse,
              );
            }
            for (final p in f.controller.session.players) {
              final surface = find.byKey(ValueKey('${p.id}-life-surface'));
              final number = find.byKey(ValueKey('${p.id}-life-number'));
              final ledger = find.byKey(ValueKey('${p.id}-commander-ledger'));
              final name = find.byKey(ValueKey('${p.id}-player-name'));
              for (final control in [dice, day]) {
                for (final content in [number, ledger, name]) {
                  expect(
                    tester.getRect(control).overlaps(tester.getRect(content)),
                    isFalse,
                  );
                }
              }
              final signs = find.descendant(
                of: surface,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Icon &&
                      (w.icon == Icons.add || w.icon == Icons.remove),
                ),
              );
              for (final icon in signs.evaluate()) {
                for (final control in [dice, day]) {
                  expect(
                    tester
                        .getRect(find.byWidget(icon.widget))
                        .overlaps(tester.getRect(control)),
                    isFalse,
                  );
                }
              }
              final center = localRect(tester, number, surface).center.dx;
              // Adding shared controls must not push the established life total
              // away from its old center: only the name/ledger footer grows.
              expect(
                localRect(tester, number, surface).center.dy,
                closeTo((tester.getSize(surface).height - 26) / 2 - 14, .01),
              );
              await f.controller.adjustLife(p.id, -1);
              await tester.pump();
              Finder deltaText() => find.descendant(
                of: find.byKey(ValueKey('${p.id}-life-delta')),
                matching: find.byType(Text),
              );
              for (final control in [dice, day]) {
                expect(
                  tester.getRect(deltaText()).overlaps(tester.getRect(control)),
                  isFalse,
                );
              }
              final clipWidget = tester.widget<ClipPath>(
                find.byKey(ValueKey('${p.id}-life-clip')),
              );
              final clip = clipWidget.clipper!.getClip(tester.getSize(surface));
              final deltaBounds = localRect(tester, deltaText(), surface);
              for (final corner in [
                deltaBounds.topLeft,
                deltaBounds.topRight,
                deltaBounds.bottomLeft,
                deltaBounds.bottomRight,
              ]) {
                expect(
                  clip.contains(corner),
                  isTrue,
                  reason:
                      'Delta must be entirely outside shared-control clearance.',
                );
              }

              expect(
                localRect(tester, deltaText(), surface).center.dy,
                closeTo(localRect(tester, number, surface).center.dy, .01),
              );
              expect(
                localRect(tester, number, surface).left -
                    localRect(tester, deltaText(), surface).right,
                closeTo(4, .01),
              );
              if (empty == 0 && [0, 2].contains(p.slot)) {
                await capture(
                  tester,
                  'delta-negative-$seats-seat${p.slot + 1}-${size.width.toInt()}x${size.height.toInt()}',
                );
              }
              expect(
                localRect(tester, number, surface).center.dx,
                closeTo(center, .01),
              );
              await f.controller.adjustLife(p.id, 2);
              await tester.pump();
              for (final control in [dice, day]) {
                expect(
                  tester.getRect(deltaText()).overlaps(tester.getRect(control)),
                  isFalse,
                );
              }
              expect(
                localRect(tester, deltaText(), surface).center.dy,
                closeTo(localRect(tester, number, surface).center.dy, .01),
              );
              expect(
                localRect(tester, deltaText(), surface).left -
                    localRect(tester, number, surface).right,
                closeTo(4, .01),
              );
              if (empty == 0 && [0, 2].contains(p.slot)) {
                await capture(
                  tester,
                  'delta-positive-$seats-seat${p.slot + 1}-${size.width.toInt()}x${size.height.toInt()}',
                );
              }
              expect(
                localRect(tester, number, surface).center.dx,
                closeTo(center, .01),
              );
              expect(
                tester.getRect(deltaText()).overlaps(tester.getRect(ledger)),
                isFalse,
              );
            }
            if (captures != null && empty == 0) {
              await capture(
                tester,
                'shared-$seats-${size.width.toInt()}x${size.height.toInt()}',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'Day/Night cycles, hold clears once, undo restores, dice opens directly',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4);
      final day = find.byKey(const ValueKey('shared-day-night'));
      final original = f.controller.session.players.map((p) => p.life).toList();
      for (final expected in ['day', 'night', 'day']) {
        await tester.tap(day);
        await tester.pumpAndSettle();
        expect(f.controller.session.dayNight, expected);
      }
      final before = f.controller.session.history.length;
      await tester.longPress(day);
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'neither');
      expect(f.controller.session.history.length, before + 1);
      await tester.longPress(day);
      await tester.pumpAndSettle();
      expect(f.controller.session.history.length, before + 1);
      await f.controller.undo();
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'day');
      expect(
        f.controller.session.players.map((p) => p.life).toList(),
        original,
      );
      await tester.tap(find.byKey(const ValueKey('shared-dice')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close workspace'), findsOneWidget);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed Day/Night save preserves state and history, then retry works',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4);
      final before = f.controller.session.history.length;
      f.repository.failSave = true;
      await tester.tap(find.byKey(const ValueKey('shared-day-night')));
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'neither');
      expect(f.controller.session.history.length, before);
      expect(f.controller.error, isNotNull);
      f.repository.failSave = false;
      await tester.tap(find.byKey(const ValueKey('shared-day-night')));
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'day');
      final reloaded = await f.repository.open();
      expect(reloaded.state.session.dayNight, 'day');
    },
  );
  testWidgets('rapid Day/Night taps resolve in command order', (tester) async {
    final f = await show(tester, const Size(1133, 744), 4);
    final control = find.byKey(const ValueKey('shared-day-night'));
    final ink = tester.widget<InkWell>(
      find.ancestor(of: control, matching: find.byType(InkWell)).first,
    );
    ink.onTap!();
    ink.onTap!();
    await tester.pumpAndSettle();
    expect(f.controller.session.dayNight, 'night');
    expect(f.controller.session.history.length, 2);
    await f.controller.undo();
    await tester.pumpAndSettle();
    expect(f.controller.session.dayNight, 'day');
  });
  testWidgets(
    'hide utility confirmation uses fixed frame and consumes dismissal',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 2);
      await tester.tap(find.byTooltip('Storm').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide Storm'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('table-modal-surface'))),
        const Size(849.75, 558),
      );
      final lives = f.controller.session.players.map((p) => p.life).toList();
      await tester.tapAt(const Offset(20, 350));
      await tester.pumpAndSettle();
      expect(find.text('Hide Storm?'), findsNothing);
      expect(f.controller.session.players.map((p) => p.life).toList(), lives);
      expect(
        f.controller.session.players.every(
          (p) => p.utilities.firstWhere((u) => u.kind == 'storm_count').visible,
        ),
        isTrue,
      );
    },
  );
  testWidgets(
    'real artwork fixture preserves expanded fade and full treatments',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4);
      final player = f.controller.session.players.first;
      final id = '${player.id}-0';
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.text('Scute Swarm 0'),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'real-art-expanded-fade');
      await f.board.setArtworkStyle(player.id, id, 'full');
      await tester.pumpAndSettle();
      await capture(tester, 'real-art-expanded-full');
      expect(tester.takeException(), isNull);
    },
  );
  for (final total in [999999, -999999]) {
    testWidgets(
      'wide signed life $total reserves adjacent delta without moving center',
      (tester) async {
        final f = await show(tester, const Size(744, 1133), 4);
        for (final player in f.controller.session.players) {
          await f.controller.setLife(player.id, total);
          await tester.pump();
          final surface = find.byKey(ValueKey('${player.id}-life-surface'));
          final number = find.byKey(ValueKey('${player.id}-life-number'));
          final center = localRect(tester, number, surface).center;
          for (final change in [-999, 1998]) {
            await f.controller.adjustLife(player.id, change);
            await tester.pump();
            final text = find.descendant(
              of: find.byKey(ValueKey('${player.id}-life-delta')),
              matching: find.byType(Text),
            );
            final deltaBox = localRect(tester, text, surface);
            final numberBox = localRect(tester, number, surface);
            expect(numberBox.center.dx, closeTo(center.dx, .01));
            expect(numberBox.center.dy, closeTo(center.dy, .01));
            expect(deltaBox.center.dy, closeTo(center.dy, .01));
            expect(deltaBox.overlaps(numberBox), isFalse);
            expect(deltaBox.left, greaterThanOrEqualTo(0));
            expect(
              deltaBox.right,
              lessThanOrEqualTo(tester.getSize(surface).width),
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [const Size(650, 480), const Size(844, 480)]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        'short board $size $seats seats scrolls tools without changing life',
        (tester) async {
          final f = await show(tester, size, seats, safeArea: false);
          final lives = f.controller.session.players
              .map((p) => p.life)
              .toList();
          for (final p in f.controller.session.players) {
            final surface = find.byKey(ValueKey('${p.id}-life-surface'));
            final originalSurface = tester.getRect(surface);
            final footer = find.byKey(ValueKey('${p.id}-life-footer-scroll'));
            if (footer.evaluate().isNotEmpty) {
              final box = tester.renderObject<RenderBox>(footer);
              final from = box.localToGlobal(
                Offset(box.size.width / 2, box.size.height * .8),
              );
              final to = box.localToGlobal(
                Offset(box.size.width / 2, box.size.height * .2),
              );
              await tester.dragFrom(from, to - from);
              await tester.pumpAndSettle();
            }
            for (final target in [
              find.byKey(ValueKey('${p.id}-player-details')),
              find.byKey(ValueKey('${p.id}-manage-utilities')),
              for (final color in PlayerState.manaColors)
                find.byKey(ValueKey('${p.id}-mana-$color-add')),
            ]) {
              // Slivers deliberately instantiate offscreen utilities lazily.
              // Advance the one scroll owner until the requested control exists.
              final section = find.byKey(ValueKey('${p.id}-utility-section'));
              final scrollable = tester.state<ScrollableState>(
                find
                    .descendant(of: section, matching: find.byType(Scrollable))
                    .first,
              );
              for (
                var attempt = 0;
                target.evaluate().isEmpty && attempt < 30;
                attempt++
              ) {
                scrollable.position.jumpTo(
                  (scrollable.position.pixels + 40).clamp(
                    0,
                    scrollable.position.maxScrollExtent,
                  ),
                );
                await tester.pumpAndSettle();
              }
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              expect(target.hitTestable(), findsOneWidget);
              expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
              expect(
                tester
                    .getRect(target)
                    .deflate(.01)
                    .overlaps(tester.getRect(surface)),
                isFalse,
                reason:
                    '${p.id} $target bounds ${tester.getRect(target)} surface ${tester.getRect(surface)}',
              );
            }
            expect(tester.getRect(surface), originalSurface);
          }
          expect(
            f.controller.session.players.map((p) => p.life).toList(),
            lives,
          );
          expect(f.controller.session.history, isEmpty);
          for (final key in ['shared-dice', 'shared-day-night']) {
            expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
            expect(
              tester.getSize(find.byKey(ValueKey(key))),
              const Size(44, 44),
            );
          }
          if (seats == 4) {
            await capture(tester, 'short-board-${size.width.toInt()}x480');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'short footer reorder auto-scrolls and expanded edits lock dragging',
    (tester) async {
      final f = await show(tester, const Size(650, 480), 4, safeArea: false);
      final p = f.controller.session.players.first;
      await f.controller.updateState('Seed reorder fixture', (state) {
        state.session.player(p.id).utilities = [
          for (var i = 0; i < 8; i++)
            UtilityState(id: 'short-reorder-$i', name: 'Reorder $i'),
        ];
      });
      await tester.pumpAndSettle();
      final enter = find.byKey(ValueKey('${p.id}-start-utility-reorder'));
      tester
          .widget<CustomScrollView>(
            find.byKey(ValueKey('${p.id}-life-footer-scroll')),
          )
          .controller!
          .jumpTo(96);
      await tester.pumpAndSettle();
      await tester.ensureVisible(enter);
      await tester.pumpAndSettle();
      final initialIds = f.controller
          .player(p.id)
          .utilities
          .map((u) => u.id)
          .toList();
      final initialHistory = f.controller.session.history.length;
      await tester.tap(enter);
      await tester.pumpAndSettle();
      expect(
        f.controller.player(p.id).utilities.map((u) => u.id).toList(),
        initialIds,
      );
      expect(f.controller.session.history.length, initialHistory);
      final footer = find.byKey(ValueKey('${p.id}-compact-utility-reorder'));
      final scroll = tester.widget<CustomScrollView>(footer).controller!;
      await capture(tester, 'short-compact-reorder-650x480');
      final row = find.byKey(const ValueKey('compact-reorder-short-reorder-0'));
      expect(tester.getSize(row).height, 44);
      final gesture = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 600));
      final box = tester.renderObject<RenderBox>(footer);
      // An outside pointer must not pull the drag proxy outside its seat.
      await gesture.moveTo(
        box.localToGlobal(Offset(-60, box.size.height + 100)),
      );
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(scroll.offset, greaterThan(60));
      final bounds = tester.getRect(
        find.byKey(ValueKey('${p.id}-utility-reorder-boundary')),
      );
      final proxy = tester.getRect(
        find.byKey(ValueKey('${p.id}-utility-reorder-proxy')),
      );
      expect(bounds.inflate(.01).contains(proxy.topLeft), isTrue);
      expect(bounds.inflate(.01).contains(proxy.bottomRight), isTrue);
      await capture(tester, 'short-compact-reorder-drag-650x480');
      await gesture.up();
      await tester.pumpAndSettle();
      final ids = f.controller.player(p.id).utilities.map((u) => u.id).toList();
      expect(ids.first, isNot('short-reorder-0'));
      expect(ids.toSet().length, 8);
      final reloaded = await f.repository.open();
      expect(
        reloaded.state.session.player(p.id).utilities.map((u) => u.id).toList(),
        ids,
      );
      // Cancel and stationary hold are both no-ops.
      for (final cancel in [true, false]) {
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final history = f.controller.session.history.length;
        final held = await tester.startGesture(
          tester.getCenter(
            find.byKey(ValueKey('compact-reorder-${ids.first}')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        if (cancel) {
          await held.cancel();
        } else {
          await held.up();
        }
        await tester.pumpAndSettle();
        expect(
          f.controller.player(p.id).utilities.map((u) => u.id).toList(),
          ids,
        );
        expect(f.controller.session.history.length, history);
      }
      await tester.tap(find.byKey(ValueKey('${p.id}-finish-utility-reorder')));
      await tester.pumpAndSettle();
      expect(footer, findsNothing);
      final normal = find.byKey(ValueKey('${p.id}-life-footer-scroll'));
      final normalScroll = tester.widget<CustomScrollView>(normal).controller!;
      normalScroll.jumpTo(140);
      await tester.pumpAndSettle();
      final firstName = f.controller.player(p.id).utilities.first.name;
      await tester.ensureVisible(find.text(firstName));
      await tester.pumpAndSettle();
      await tester.tap(find.text(firstName));
      await tester.pumpAndSettle();
      normalScroll.jumpTo(96);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(enter).onPressed, isNull);
      expect(f.controller.session.players.every((p) => p.life == 40), isTrue);
      expect(
        f.controller.player(p.id).utilities.every((u) => u.value == 0),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'short reorder mode exits for modal and lifecycle without changes',
    (tester) async {
      final f = await show(tester, const Size(650, 480), 4, safeArea: false);
      final p = f.controller.session.players.first;
      Future<void> enter() async {
        final normal = find.byKey(ValueKey('${p.id}-life-footer-scroll'));
        tester.widget<CustomScrollView>(normal).controller!.jumpTo(96);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('${p.id}-start-utility-reorder')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('${p.id}-compact-utility-reorder')),
          findsOneWidget,
        );
      }

      final before = f.controller.session.toJson();
      await enter();
      await tester.tap(find.byKey(const ValueKey('shared-dice')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason:
            'Opening Dice from constrained reorder mode must fit the workspace.',
      );
      expect(
        find.byKey(ValueKey('${p.id}-compact-utility-reorder')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('context-workspace')),
        findsOneWidget,
        reason: 'Dice must actually open before testing modal restoration.',
      );
      expect(find.byTooltip('Close workspace'), findsOneWidget);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
      await enter();
      final held = await tester.startGesture(
        tester.getCenter(
          find.byKey(ValueKey('compact-reorder-${p.utilities.first.id}')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('${p.id}-compact-utility-reorder')),
        findsNothing,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await held.up();
      await tester.pumpAndSettle();
      expect(f.controller.session.toJson(), before);
    },
  );
  testWidgets(
    'warned long-name seats keep warning clear of life symbols and delta',
    (tester) async {
      final f = await show(tester, const Size(744, 1133), 4);
      await f.controller.updateState('Seed warnings', (state) {
        for (final player in state.session.players) {
          player.counters['poison'] = 10;
          state.profiles
                  .firstWhere((profile) => profile.id == player.seatId)
                  .name =
              'A very long player name that must truncate';
        }
      });
      await tester.pumpAndSettle();
      for (final p in f.controller.session.players) {
        await f.controller.adjustLife(p.id, 1);
        await tester.pump();
        final warning = find.byKey(ValueKey('${p.id}-life-warning'));
        final surface = find.byKey(ValueKey('${p.id}-life-surface'));
        final symbols = find.descendant(
          of: surface,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && (w.icon == Icons.add || w.icon == Icons.remove),
          ),
        );
        for (final symbol in symbols.evaluate()) {
          expect(
            tester
                .getRect(warning)
                .overlaps(tester.getRect(find.byWidget(symbol.widget))),
            isFalse,
          );
        }
        final name = find.byKey(ValueKey('${p.id}-player-name'));
        expect(tester.widget<Text>(name).overflow, TextOverflow.ellipsis);
        expect(
          tester.getRect(name).deflate(.01).overlaps(tester.getRect(warning)),
          isFalse,
        );
        final number = find.byKey(ValueKey('${p.id}-life-number'));
        final delta = find.descendant(
          of: find.byKey(ValueKey('${p.id}-life-delta')),
          matching: find.byType(Text),
        );
        expect(
          localRect(tester, number, surface).center.dy,
          closeTo(localRect(tester, delta, surface).center.dy, .01),
        );
      }
      await capture(tester, 'warned-long-name-seats-744x1133');
      expect(tester.takeException(), isNull);
    },
  );
}

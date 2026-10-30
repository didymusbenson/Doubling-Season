import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  late Directory catalog;
  final captures = Platform.environment['TABLET_DRAWER_CAPTURE_DIR'];
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('drawer-shell-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final bytes = File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
        ).readAsBytes().then(ByteData.sublistView);
        await (FontLoader(font.key)..addFont(bytes)).load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<TableFixture> show(WidgetTester tester, Size size, int seats) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    state.session.players = state.session.players.take(seats).toList();
    for (final player in state.session.players) {
      player.tokens = [
        for (var i = 0; i < 8; i++) sampleToken(id: '${player.id}-token-$i'),
      ];
    }
    final f = TableFixture(state);
    await f.initialize();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('drawer-capture'),
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: f.controller),
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
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('drawer-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$captures/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  // A hidden RenderSemanticsAnnotations may retain its old cached node.
  // Traverse only nodes still attached to the live accessibility root.
  Set<String> accessibleLabels(WidgetTester tester) {
    var root = tester.getSemantics(find.byType(Scaffold).first);
    while (root.parent != null) {
      root = root.parent!;
    }
    final labels = <String>{};
    void visit(SemanticsNode node) {
      labels.add(node.label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    return labels;
  }

  for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        '$seats seats $size fixed tokens, moving rails and consumed dismissal',
        (tester) async {
          final f = await show(tester, size, seats);
          final beforeState = jsonEncode(f.controller.state.toJson());
          final hub = find.byKey(const ValueKey('central-game-controls'));
          final initialHub = tester.getRect(hub);
          final laneBounds = {
            for (final p in f.controller.session.players)
              p.id: tester.getRect(find.byKey(ValueKey('${p.id}-token-lane'))),
          };
          final railBounds = {
            for (final p in f.controller.session.players)
              p.id: tester.getRect(
                find.byKey(ValueKey('${p.id}-sliding-rail')),
              ),
          };
          final token = f.player.tokens.first;
          final quantity = find.byKey(
            ValueKey('${token.id}-quantity-increase'),
          );
          final tapPoint = tester.getCenter(quantity);
          final initialTokenBounds = tester.getRect(
            find.byKey(ValueKey(token.id)),
          );
          await capture(tester, '$seats-${size.width.toInt()}-closed');
          await tester.tap(hub);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final midHub = tester.getRect(hub);
          expect(midHub.size, const Size(52, 52));
          expect(midHub.center.dx, lessThan(initialHub.center.dx));
          expect(hub.hitTestable(), findsOneWidget);
          for (final p in f.controller.session.players) {
            expect(
              tester.getRect(find.byKey(ValueKey('${p.id}-token-lane'))),
              laneBounds[p.id],
            );
            expect(
              tester.getRect(find.byKey(ValueKey('${p.id}-sliding-rail'))).left,
              isNot(railBounds[p.id]!.left),
            );
          }
          await capture(tester, '$seats-${size.width.toInt()}-mid');
          await tester.pumpAndSettle();
          expect(find.byType(GameDrawerWorkspace), findsOneWidget);
          expect(find.byType(Dialog), findsNothing);
          expect(tester.getRect(hub).size, const Size(52, 52));
          expect(hub.hitTestable(), findsOneWidget);
          for (final key in ['shared-dice', 'shared-day-night']) {
            final control = find.byKey(ValueKey(key));
            expect(tester.getSize(control), const Size(44, 44));
            expect(control.hitTestable(), findsOneWidget);
          }
          expect(
            tester.getRect(find.byKey(ValueKey(token.id))),
            initialTokenBounds,
          );
          await capture(tester, '$seats-${size.width.toInt()}-open');
          await tester.tapAt(tapPoint);
          await tester.pumpAndSettle();
          expect(find.byType(GameDrawerWorkspace), findsNothing);
          expect(tester.getRect(hub), initialHub);
          expect(
            tester.getRect(find.byKey(ValueKey(token.id))),
            initialTokenBounds,
          );
          expect(
            jsonEncode(f.controller.state.toJson()),
            beforeState,
            reason:
                'Dismissal must not activate the quantity button under the finger.',
          );
          await tester.tap(quantity);
          await tester.pumpAndSettle();
          expect(
            f.controller.player(f.playerId).tokens.first.amount,
            token.amount + 1,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'reversing mid-opening is continuous and repeated edge navigation remains usable',
    (tester) async {
      await show(tester, const Size(1133, 744), 4);
      final hub = find.byKey(const ValueKey('central-game-controls'));
      await tester.tap(hub);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 55));
      final beforeClose = tester.getRect(hub);
      await tester.tap(hub);
      await tester.pump();
      expect(tester.getRect(hub), beforeClose);
      await tester.pumpAndSettle();
      expect(find.byType(GameDrawerWorkspace), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('shared-dice')));
        await tester.pumpAndSettle();
        expect(find.byType(GameDrawerWorkspace), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(hub);
        await tester.pumpAndSettle();
        expect(find.byType(GameDrawerWorkspace), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'drawer actions are excluded from accessibility until fully revealed',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final f = await show(tester, const Size(1133, 744), 4);
      final hub = find.byKey(const ValueKey('central-game-controls'));
      await tester.tap(hub);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(accessibleLabels(tester), isNot(contains('History')));
      expect(
        find.bySemanticsLabel(RegExp('Saproling.*increase')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(accessibleLabels(tester), contains('History'));
      for (final player in f.controller.session.players) {
        final node = tester.getSemantics(
          find.byKey(ValueKey('${player.id}-dismiss-drawer')),
        );
        expect(node.label, 'Close game drawer');
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        var childCount = 0;
        node.visitChildren((child) {
          childCount++;
          return true;
        });
        expect(
          childCount,
          0,
          reason:
              'The named dismissal action must not contain a second unnamed pointer target.',
        );
      }
      expect(
        find.byKey(ValueKey('${f.playerId}-dismiss-drawer')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(hub);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(accessibleLabels(tester), isNot(contains('History')));
      await tester.pumpAndSettle();
      expect(find.byType(GameDrawerWorkspace), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'narrow-window Settings uses embedded workspace and survives resize',
    (tester) async {
      await show(tester, const Size(600, 450), 4);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(GameDrawerWorkspace), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      tester.view.physicalSize = const Size(1133, 744);
      await tester.pumpAndSettle();
      expect(find.byType(GameDrawerWorkspace), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('central-game-controls')));
      await tester.pumpAndSettle();
      expect(find.byType(GameDrawerWorkspace), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final seats in [2, 4]) {
    for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
      testWidgets(
        '$seats seats $size drawer label pixels survive repeated clipped openings',
        (tester) async {
          await show(tester, size, seats);
          final hub = find.byKey(const ValueKey('central-game-controls'));
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('drawer-capture')),
          );
          for (var cycle = 0; cycle < 4; cycle++) {
            await tester.tap(hub);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 55));
            // Exercise an actual mid-transition raster read too: semantics alone
            // cannot prove that retained text/ink layers were painted correctly.
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
              image.dispose();
            });
            await tester.pumpAndSettle();
            final labelRects = <String, Rect>{};
            for (final label in [
              'Dice',
              'History',
              'New game',
              'Archives',
              'Board wipes',
              'Settings',
            ]) {
              final text = tester.renderObject<RenderBox>(
                find.descendant(
                  of: find.byType(GameDrawerWorkspace),
                  matching: find.text(label),
                ),
              );
              labelRects[label] = MatrixUtils.transformRect(
                text.getTransformTo(boundary),
                Offset.zero & text.size,
              );
            }
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final pixels = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              for (final entry in labelRects.entries) {
                var paintedLabelPixels = 0;
                for (
                  var y = entry.value.top.ceil();
                  y < entry.value.bottom.floor();
                  y++
                ) {
                  for (
                    var x = entry.value.left.ceil();
                    x < entry.value.right.floor();
                    x++
                  ) {
                    final offset = (y * image.width + x) * 4;
                    final r = pixels.getUint8(offset);
                    final g = pixels.getUint8(offset + 1);
                    final b = pixels.getUint8(offset + 2);
                    if (g > 100 && g - r > 20 && g - b > 10) {
                      paintedLabelPixels++;
                    }
                  }
                }
                expect(
                  paintedLabelPixels,
                  greaterThan(12),
                  reason:
                      '${entry.key} must paint actual foreground glyphs on opening $cycle; borders and semantics are insufficient.',
                );
              }
              image.dispose();
            });
            await tester.tap(hub);
            await tester.pumpAndSettle();
            expect(find.byType(GameDrawerWorkspace), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final seats in [2, 3, 4]) {
    for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
      testWidgets(
        '$seats seats $size dismissal semantics stay outside drawer controls',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final f = await show(tester, size, seats);
            await tester.tap(
              find.byKey(const ValueKey('central-game-controls')),
            );
            await tester.pumpAndSettle();
            final drawerBounds = tester.getRect(
              find.byType(GameDrawerWorkspace),
            );
            for (final p in f.controller.session.players) {
              final dismissal = find.byKey(ValueKey('${p.id}-dismiss-drawer'));
              final node = tester.getSemantics(dismissal);
              var transform = Matrix4.identity();
              for (
                SemanticsNode? current = node;
                current != null;
                current = current.parent
              ) {
                if (current.transform != null) {
                  transform = current.transform! * transform;
                }
              }
              final semanticBounds = MatrixUtils.transformRect(
                transform,
                node.rect,
              );
              expect(
                semanticBounds.overlaps(drawerBounds.deflate(.001)),
                isFalse,
                reason:
                    'A painted hole is not enough: the browser uses the dismissal accessibility rectangle for hit testing.',
              );
              // Rotated render bounds can differ at the shared edge by
              // floating-point noise; a thousandth of a pixel is not a target.
              expect(
                tester.getRect(dismissal).overlaps(drawerBounds.deflate(.001)),
                isFalse,
              );
              expect(node.label, 'Close game drawer');
            }
            await tester.tap(
              find.descendant(
                of: find.byType(GameDrawerWorkspace),
                matching: find.text('History'),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Game history'), findsOneWidget);
            expect(find.byType(GameDrawerWorkspace), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  testWidgets('two-seat save-warning actions remain outside the open drawer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final f = await show(tester, const Size(1133, 744), 2);
      f.repository.failSave = true;
      for (final player in f.controller.session.players) {
        await tester.tap(find.byKey(ValueKey('${player.id}-life-decrease')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('${player.id}-acknowledge-life-error')),
          findsOneWidget,
          reason: 'The failed life save must be visible before opening.',
        );
      }
      final hub = find.byKey(const ValueKey('central-game-controls'));
      await tester.tap(hub);
      await tester.pumpAndSettle();
      final drawerBounds = tester.getRect(find.byType(GameDrawerWorkspace));
      for (final player in f.controller.session.players) {
        final warning = find.byKey(
          ValueKey('${player.id}-acknowledge-life-error'),
        );
        expect(warning, findsOneWidget);
        final node = tester.getSemantics(warning);
        expect(node.label, 'Acknowledge life save warning');
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        var transform = Matrix4.identity();
        for (
          SemanticsNode? current = node;
          current != null;
          current = current.parent
        ) {
          if (current.transform != null) {
            transform = current.transform! * transform;
          }
        }
        final bounds = MatrixUtils.transformRect(transform, node.rect);
        expect(bounds.overlaps(drawerBounds.deflate(.001)), isFalse);
      }
      await tester.tap(
        find.descendant(
          of: find.byType(GameDrawerWorkspace),
          matching: find.text('History'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Game history'), findsOneWidget);
      await tester.tap(hub);
      await tester.pumpAndSettle();
      for (final player in f.controller.session.players) {
        expect(
          find.byKey(ValueKey('${player.id}-acknowledge-life-error')),
          findsOneWidget,
        );
        expect(player.life, 40);
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('opening and closing retain expanded token and scroll position', (
    tester,
  ) async {
    final f = await show(tester, const Size(1133, 744), 4);
    final id = f.player.tokens.first.id;
    final token = find.byWidgetPredicate(
      (widget) => widget is TabletTokenCard && widget.token.id == id,
    );
    await tester.tap(
      find.descendant(of: token, matching: find.text('Saproling')).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TabletTokenCard>(token).expanded, isTrue);
    final list = find.descendant(
      of: find.byKey(ValueKey('${f.playerId}-token-lane')),
      matching: find.byType(ReorderableListView),
    );
    final scroll = tester.widget<ReorderableListView>(list).scrollController!;
    scroll.jumpTo(80);
    await tester.pump();
    final hub = find.byKey(const ValueKey('central-game-controls'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(tester.widget<TabletTokenCard>(token).expanded, isTrue);
      expect(
        tester.widget<ReorderableListView>(list).scrollController,
        same(scroll),
      );
      expect(scroll.offset, 80);
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(tester.widget<TabletTokenCard>(token).expanded, isTrue);
      expect(scroll.offset, 80);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending immediate life receipt survives drawer insertion and removal',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1133, 744);
      addTearDown(tester.view.reset);
      final repository = _DeferredSaveRepository(TabletState.initial());
      final controller = TableController(repository: repository);
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: TableScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      final playerId = controller.session.players.first.id;
      repository.gate = Completer<void>();
      await tester.tap(find.byKey(ValueKey('$playerId-life-decrease')));
      await tester.pump();
      String? shownLife() => tester
          .widget<Text>(find.byKey(ValueKey('$playerId-life-number')))
          .data;
      expect(shownLife(), '39');
      expect(
        controller.player(playerId).life,
        40,
        reason: 'The durability gate has not acknowledged the receipt yet.',
      );
      final hub = find.byKey(const ValueKey('central-game-controls'));
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(shownLife(), '39');
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(shownLife(), '39');
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(controller.player(playerId).life, 39);
      expect(shownLife(), '39');
      expect(controller.session.history.length, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
    testWidgets('empty seat tools recede while drawer is open at $size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(tester, size, 3);
      final empty = find.byKey(const ValueKey('empty-table-controls-3'));
      final dice = find.descendant(of: empty, matching: find.text('Roll dice'));
      expect(tester.widget<Opacity>(empty).opacity, 1);
      expect(dice.hitTestable(), findsOneWidget);
      final hub = find.byKey(const ValueKey('central-game-controls'));
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(empty).opacity, 0);
      expect(dice.hitTestable(), findsNothing);
      expect(accessibleLabels(tester), isNot(contains('The table')));
      expect(accessibleLabels(tester), contains('History'));
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(empty).opacity, 1);
      expect(dice.hitTestable(), findsOneWidget);
      semantics.dispose();
    });
  }
}

class _DeferredSaveRepository extends MemoryTableRepository {
  _DeferredSaveRepository(super.state);
  Completer<void>? gate;
  @override
  Future<void> save(TabletState state) async {
    if (gate != null) await gate!.future;
    await super.save(state);
  }
}

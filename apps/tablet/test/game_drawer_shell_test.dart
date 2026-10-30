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
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  late Directory catalog;
  late String fixtureArtwork;
  final captures = Platform.environment['TABLET_DRAWER_CAPTURE_DIR'];
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('drawer-shell-');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xff4d92ce),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    fixtureArtwork =
        'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    image.dispose();
    picture.dispose();
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

  Future<TableFixture> show(
    WidgetTester tester,
    Size size,
    int seats, {
    String? artStyle,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    state.session.players = state.session.players.take(seats).toList();
    for (final player in state.session.players) {
      player.tokens = [
        for (var i = 0; i < 8; i++)
          sampleToken(
            id: '${player.id}-token-$i',
            artworkUrl: artStyle == null ? null : fixtureArtwork,
          ),
      ];
      if (artStyle != null) {
        for (final token in player.tokens) {
          token.extra['artworkDisplayStyle'] = artStyle;
        }
      }
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
    if (artStyle != null) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }
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

  void expectFirstTokenContentClear(
    WidgetTester tester,
    PlayerState player, {
    required double inset,
  }) {
    final token = find.byWidgetPredicate(
      (w) => w is TabletTokenCard && w.token.id == player.tokens.first.id,
    );
    expect(tester.widget<TabletTokenCard>(token).topContentInset, inset);
    final tokenBox = tester.renderObject<RenderBox>(token);
    final name = find
        .descendant(of: token, matching: find.text('Saproling'))
        .first;
    final totals = find.descendant(
      of: token,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.endsWith(
                  ', edit total, tapped and summoning sickness',
                ) ??
                false),
      ),
    );
    final totalBox = tester.renderObject<RenderBox>(totals);
    final localTotals = MatrixUtils.transformRect(
      totalBox.getTransformTo(tokenBox),
      Offset.zero & totalBox.size,
    );
    expect(localTotals.top, 5 + inset);
    final nameBox = tester.renderObject<RenderBox>(name);
    final localName = MatrixUtils.transformRect(
      nameBox.getTransformTo(tokenBox),
      Offset.zero & nameBox.size,
    );
    expect(localName.top, 8 + inset);
    for (final content in [
      name,
      totals,
      find.byKey(ValueKey('${player.tokens.first.id}-quantity-increase')),
      find.byKey(ValueKey('${player.tokens.first.id}-quantity-decrease')),
    ]) {
      final rect = tester.getRect(content);
      for (final control in [
        'central-game-controls',
        'shared-dice',
        'shared-day-night',
      ]) {
        expect(
          rect.overlaps(tester.getRect(find.byKey(ValueKey(control)))),
          isFalse,
          reason:
              'First token content must clear actual shared-control targets',
        );
      }
    }
    final next = find.byWidgetPredicate(
      (w) => w is TabletTokenCard && w.token.id == player.tokens[1].id,
    );
    if (next.evaluate().isNotEmpty) {
      expect(tester.widget<TabletTokenCard>(next).topContentInset, 0);
    }
  }

  for (final seats in [2, 3, 4]) {
    for (final style in ['full', 'fadeout']) {
      testWidgets(
        '$seats seats preserve $style artwork behind first-card clearance',
        (tester) async {
          final f = await show(
            tester,
            const Size(744, 1133),
            seats,
            artStyle: style,
          );
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('drawer-capture')),
          );
          for (final p in f.controller.session.players) {
            final token = find.byWidgetPredicate(
              (w) => w is TabletTokenCard && w.token.id == p.tokens.first.id,
            );
            final card = tester.widget<TabletTokenCard>(token);
            expect(card.topContentInset, seats == 2 ? 30 : 0);
            final artwork = find.descendant(
              of: token,
              matching: find.byType(TableArtworkSurface),
            );
            expect(tester.widget<TableArtworkSurface>(artwork).style, style);
            expect(
              tester.widget<TableArtworkSurface>(artwork).shadeArtwork,
              isFalse,
            );
            final tokenBox = tester.renderObject<RenderBox>(token);
            final artBox = tester.renderObject<RenderBox>(artwork);
            final localArt = MatrixUtils.transformRect(
              artBox.getTransformTo(tokenBox),
              Offset.zero & artBox.size,
            );
            expect(localArt.top, 0);
            expect(localArt.width, tokenBox.size.width);
            expectFirstTokenContentClear(tester, p, inset: seats == 2 ? 30 : 0);
            if (seats == 2) {
              final point = boundary.globalToLocal(
                tokenBox.localToGlobal(Offset(tokenBox.size.width * .97, 31)),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final pixels = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                final offset =
                    (point.dy.floor() * image.width + point.dx.floor()) * 4;
                expect(
                  [
                    pixels.getUint8(offset),
                    pixels.getUint8(offset + 1),
                    pixels.getUint8(offset + 2),
                  ],
                  [77, 146, 206],
                  reason:
                      'Real artwork pixels must fill the added internal clearance',
                );
                image.dispose();
              });
            }
            await tester.tap(
              find
                  .descendant(of: token, matching: find.text('Saproling'))
                  .first,
            );
            await tester.pumpAndSettle();
            expect(tester.widget<TabletTokenCard>(token).expanded, isTrue);
            expect(tester.widget<TableArtworkSurface>(artwork).style, style);
            expectFirstTokenContentClear(tester, p, inset: seats == 2 ? 30 : 0);
          }
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          await capture(tester, '$seats-centered-$style-expanded');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  void expectMenuSemantics(
    WidgetTester tester, {
    required bool twoPlayer,
    required bool expanded,
  }) {
    final semantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byKey(const ValueKey('central-game-controls')),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Game controls',
        ),
      ),
    );
    expect(
      semantics.properties.identifier,
      twoPlayer ? 'two-player-game-menu' : 'game-menu',
    );
    expect(
      semantics.properties.value,
      '${expanded ? 'Expanded' : 'Collapsed'}, Game saved',
    );
    expect(semantics.properties.expanded, expanded);
    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.onTap, isNotNull);
  }

  void expectRightWallControls(WidgetTester tester) {
    expectMenuSemantics(tester, twoPlayer: false, expanded: true);
    final table = tester.getRect(find.byKey(const ValueKey('table-surface')));
    final hub = tester.getRect(
      find.byKey(const ValueKey('central-game-controls')),
    );
    final dice = tester.getRect(find.byKey(const ValueKey('shared-dice')));
    final dayNight = tester.getRect(
      find.byKey(const ValueKey('shared-day-night')),
    );
    final reveal = find
        .descendant(
          of: find.byKey(const ValueKey('table-drawer-layer')),
          matching: find.byType(ClipRect),
        )
        .first;
    final revealWidget = tester.widget<ClipRect>(reveal);
    final channel = revealWidget.clipper!
        .getClip(tester.getSize(reveal))
        .shift(tester.getTopLeft(reveal));
    expect(hub.size, const Size(52, 52));
    expect(hub.center.dx, closeTo(channel.right, .001));
    expect(hub.center.dy, closeTo(table.center.dy, .001));
    expect(dice.size, const Size(44, 44));
    expect(dayNight.size, const Size(44, 44));
    expect(dice.right, lessThan(channel.left));
    expect(dayNight.left - hub.right, greaterThan(0));
    expect(hub.overlaps(dice), isFalse);
    expect(hub.overlaps(dayNight), isFalse);
    expect(
      find.byKey(const ValueKey('central-game-controls')).hitTestable(),
      findsOneWidget,
    );

    // Both the visible clearance and its native hit-test path must mirror:
    // right hosts Menu, left stays empty. Inspect the actual board mask, not
    // just a widget position that could leave an incorrect wall underneath.
    final maskFinder = find.byKey(const ValueKey('drawer-board-mask'));
    final mask = tester.widget<ClipPath>(maskFinder);
    final path = mask.clipper!.getClip(tester.getSize(maskFinder));
    final origin = tester.getTopLeft(maskFinder);
    final centerY = table.center.dy - origin.dy;
    final left = channel.left - origin.dx;
    final right = channel.right - origin.dx;
    for (final edge in [(left, -1), (right, 1)]) {
      expect(path.contains(Offset(edge.$1 + edge.$2 * 29, centerY)), isFalse);
      expect(path.contains(Offset(edge.$1 + edge.$2 * 31, centerY)), isTrue);
    }
  }

  for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
    for (final seats in [3, 4]) {
      testWidgets(
        '$seats seats $size fixed tokens, moving rails and consumed dismissal',
        (tester) async {
          final f = await show(tester, size, seats);
          final beforeState = jsonEncode(f.controller.state.toJson());
          final hub = find.byKey(const ValueKey('central-game-controls'));
          final initialHub = tester.getRect(hub);
          expect(
            initialHub.center,
            tester.getRect(find.byKey(const ValueKey('table-surface'))).center,
          );
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
          expect(midHub.center.dx, greaterThan(initialHub.center.dx));
          expectRightWallControls(tester);
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
          // The spring briefly exceeds its settled position. Adjacent controls
          // must stay separate at the peak, including the two-seat offset lerp.
          await tester.pump(const Duration(milliseconds: 165));
          expectRightWallControls(tester);
          expect(
            tester.getRect(hub).center.dx,
            greaterThan(
              initialHub.center.dx +
                  tester.getSize(find.byType(GameDrawerWorkspace)).width / 2,
            ),
          );
          await capture(tester, '$seats-${size.width.toInt()}-bounce');
          await tester.pumpAndSettle();
          expect(find.byType(GameDrawerWorkspace), findsOneWidget);
          expect(find.byType(Dialog), findsNothing);
          expectRightWallControls(tester);
          expect(
            tester
                    .getRect(find.byKey(const ValueKey('shared-day-night')))
                    .left -
                tester.getRect(hub).right,
            closeTo(6, .001),
          );
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
          // A new opening reversed mid-flight keeps the same right-hand edge
          // at the reversal frame, then travels back without jumping sides.
          await tester.tap(hub);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final beforeReverse = tester.getRect(hub);
          expectRightWallControls(tester);
          await tester.tap(hub);
          await tester.pump();
          // Close first drains draft/save guards and posts the shell callback;
          // give those frames a turn without advancing the animation clock.
          await tester.pump();
          await tester.pump();
          expect(tester.getRect(hub), beforeReverse);
          await tester.pump(const Duration(milliseconds: 50));
          expectRightWallControls(tester);
          expect(
            tester.getRect(hub).center.dx,
            lessThan(beforeReverse.center.dx),
          );
          expect(
            tester.getRect(hub).center.dx,
            greaterThan(initialHub.center.dx),
          );
          await capture(tester, '$seats-${size.width.toInt()}-reverse');
          await tester.pumpAndSettle();
          expect(tester.getRect(hub), initialHub);
          expect(find.byType(GameDrawerWorkspace), findsNothing);
          expect(jsonEncode(f.controller.state.toJson()), beforeState);
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

  for (final size in [
    const Size(650, 1024),
    const Size(844, 480),
    const Size(1024, 600),
    const Size(744, 1133),
    const Size(1133, 744),
  ]) {
    testWidgets(
      'two seats $size preserve full token widths across horizontal opening',
      (tester) async {
        final f = await show(tester, size, 2);
        final original = jsonEncode(f.controller.state.toJson());
        final table = tester.getRect(
          find.byKey(const ValueKey('table-surface')),
        );
        final hub = find.byKey(const ValueKey('central-game-controls'));
        final closedHub = tester.getRect(hub);
        expectMenuSemantics(tester, twoPlayer: true, expanded: false);
        expect(
          tester.getCenter(find.byKey(const ValueKey('shared-dice'))),
          table.center - const Offset(54, 0),
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('shared-day-night'))),
          table.center + const Offset(54, 0),
        );
        expect(closedHub.center, table.center);
        final lanes = <String, Rect>{};
        final tokenWidths = <String, double>{};
        for (final p in f.controller.session.players) {
          final lane = find.byKey(ValueKey('${p.id}-token-lane'));
          final token = find.byKey(ValueKey(p.tokens.first.id));
          lanes[p.id] = tester.getRect(lane);
          tokenWidths[p.id] = tester.getSize(token).width;
          final laneBox = tester.renderObject<RenderBox>(lane);
          final tokenBox = tester.renderObject<RenderBox>(token);
          final local = MatrixUtils.transformRect(
            tokenBox.getTransformTo(laneBox),
            Offset.zero & tokenBox.size,
          );
          expect(
            local.top,
            closeTo(0, .001),
            reason: 'No control-induced header padding',
          );
          expect(local.width, closeTo(laneBox.size.width, .001));
          expectFirstTokenContentClear(tester, p, inset: 30);
          final life = find.byKey(ValueKey('${p.id}-life-surface'));
          final clip = tester.widget<ClipPath>(
            find.byKey(ValueKey('${p.id}-life-clip')),
          );
          final lifeSize = tester.getSize(life);
          final lifePath = clip.clipper!.getClip(lifeSize);
          expect(
            lifePath.contains(const Offset(26, 26)),
            isTrue,
            reason: 'Former life-corner notch must disappear',
          );
          for (final control in [
            'shared-dice',
            'shared-day-night',
            'central-game-controls',
          ]) {
            for (final suffix in [
              'player-name',
              'life-number',
              'commander-ledger',
            ]) {
              expect(
                tester
                    .getRect(find.byKey(ValueKey('${p.id}-$suffix')))
                    .overlaps(tester.getRect(find.byKey(ValueKey(control)))),
                isFalse,
              );
            }
          }
          expect(
            tester
                .getRect(find.byKey(ValueKey('${p.id}-player-name')))
                .overlaps(closedHub),
            isFalse,
          );
          expect(
            tester
                .getRect(find.byKey(ValueKey('${p.id}-commander-ledger')))
                .overlaps(closedHub),
            isFalse,
          );
        }
        await capture(tester, '2-horizontal-${size.width.toInt()}-closed');
        await tester.tap(hub);
        await tester.pump();
        Future<void> verifyFrame(String name) async {
          expectMenuSemantics(tester, twoPlayer: true, expanded: true);
          final maskFinder = find.byKey(const ValueKey('drawer-board-mask'));
          final mask = tester.widget<ClipPath>(maskFinder);
          final maskBox = tester.renderObject<RenderBox>(maskFinder);
          final path = mask.clipper!.getClip(maskBox.size);
          final reveal = find
              .descendant(
                of: find.byKey(const ValueKey('table-drawer-layer')),
                matching: find.byType(ClipRect),
              )
              .first;
          final channel = tester
              .widget<ClipRect>(reveal)
              .clipper!
              .getClip(tester.getSize(reveal))
              .shift(tester.getTopLeft(reveal));
          expect(channel.width, table.width);
          final menuRect = tester.getRect(hub);
          expect(menuRect.size, const Size(52, 52));
          expect(menuRect.center, Offset(table.center.dx, channel.bottom));
          expect(
            tester.getCenter(find.byKey(const ValueKey('shared-dice'))),
            Offset(table.center.dx - 54, channel.top),
          );
          expect(
            tester.getCenter(find.byKey(const ValueKey('shared-day-night'))),
            Offset(table.center.dx + 54, channel.bottom),
          );
          expect(hub.hitTestable(), findsOneWidget);
          for (final key in ['shared-dice', 'shared-day-night']) {
            final control = find.byKey(ValueKey(key));
            expect(tester.getSize(control), const Size(44, 44));
            expect(tester.getRect(control).overlaps(menuRect), isFalse);
          }
          for (final p in f.controller.session.players) {
            final lane = find.byKey(ValueKey('${p.id}-token-lane'));
            final token = find.byKey(ValueKey(p.tokens.first.id));
            final laneBox = tester.renderObject<RenderBox>(lane);
            final tokenBox = tester.renderObject<RenderBox>(token);
            final laneRect = tester.getRect(lane);
            final local = MatrixUtils.transformRect(
              tokenBox.getTransformTo(laneBox),
              Offset.zero & tokenBox.size,
            );
            expect(laneRect.width, closeTo(lanes[p.id]!.width, .001));
            expect(tester.getSize(token).width, tokenWidths[p.id]);
            expect(local.top, closeTo(0, .001));
            expect(local.left, closeTo(0, .001));
            expect(local.right, closeTo(laneBox.size.width, .001));
            expect(laneRect.overlaps(channel.deflate(.001)), isFalse);
            expectFirstTokenContentClear(tester, p, inset: 30);
            // Test every visible token column against the actual board paint mask,
            // including both edge columns, rather than only the widget's bounds.
            // Only the artwork-backed first 30px admits the centered circular
            // cutout. Every content column below it remains fully visible.
            for (double y = 31; y < laneBox.size.height; y += 13) {
              for (final x in [
                1.0,
                laneBox.size.width / 2,
                laneBox.size.width - 1,
              ]) {
                expect(
                  path.contains(
                    maskBox.globalToLocal(laneBox.localToGlobal(Offset(x, y))),
                  ),
                  isTrue,
                );
              }
            }
            expect(
              tester.getRect(find.byKey(ValueKey('${p.id}-dismiss-drawer'))),
              laneRect,
            );
          }
          await capture(tester, '2-horizontal-${size.width.toInt()}-$name');
          expect(tester.takeException(), isNull);
        }

        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.getRect(hub).center.dy, greaterThan(closedHub.center.dy));
        await verifyFrame('mid');
        await tester.pump(const Duration(milliseconds: 165));
        await verifyFrame('bounce');
        await tester.pumpAndSettle();
        await verifyFrame('open');
        final drawer = tester.getRect(find.byType(GameDrawerWorkspace));
        expect(
          tester.getRect(hub).center.dy,
          closeTo(drawer.bottom + 30, .001),
        );
        final first = f.player.tokens.first;
        final increase = find.byKey(ValueKey('${first.id}-quantity-increase'));
        final firstName = find
            .descendant(
              of: find.byKey(ValueKey(first.id)),
              matching: find.text('Saproling'),
            )
            .first;
        await tester.tapAt(tester.getCenter(firstName));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await verifyFrame('closing');
        await tester.pumpAndSettle();
        expect(find.byType(GameDrawerWorkspace), findsNothing);
        expect(tester.getRect(hub), closedHub);
        expect(
          tester
              .widget<TabletTokenCard>(
                find.byWidgetPredicate(
                  (w) => w is TabletTokenCard && w.token.id == first.id,
                ),
              )
              .expanded,
          isFalse,
          reason: 'Dismissal must not expand the tapped name',
        );
        expect(
          jsonEncode(f.controller.state.toJson()),
          original,
          reason: 'Closing tap must not adjust the token',
        );
        for (final p in f.controller.session.players) {
          expect(
            tester.getRect(find.byKey(ValueKey('${p.id}-token-lane'))),
            lanes[p.id],
          );
        }
        await tester.tap(increase);
        await tester.pumpAndSettle();
        expect(f.player.tokens.first.amount, first.amount + 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'two seats $size expanded cards and scroll position survive opening',
      (tester) async {
        final f = await show(tester, size, 2);
        final hub = find.byKey(const ValueKey('central-game-controls'));
        for (final p in f.controller.session.players) {
          final id = p.tokens.first.id;
          final token = find.byWidgetPredicate(
            (w) => w is TabletTokenCard && w.token.id == id,
          );
          await tester.tap(
            find.descendant(of: token, matching: find.text('Saproling')).first,
          );
          await tester.pumpAndSettle();
          expect(tester.widget<TabletTokenCard>(token).expanded, isTrue);
        }
        final lists = <String, ScrollController>{};
        final widths = <String, double>{};
        for (final p in f.controller.session.players) {
          final list = find.descendant(
            of: find.byKey(ValueKey('${p.id}-token-lane')),
            matching: find.byType(ReorderableListView),
          );
          final scroll = tester
              .widget<ReorderableListView>(list)
              .scrollController!;
          lists[p.id] = scroll;
          widths[p.id] = tester
              .getSize(find.byKey(ValueKey(p.tokens.first.id)))
              .width;
          scroll.jumpTo(80);
        }
        await tester.pump();
        for (var cycle = 0; cycle < 2; cycle++) {
          await tester.tap(hub);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 75));
          await capture(
            tester,
            '2-horizontal-expanded-${size.width.toInt()}-mid-$cycle',
          );
          await tester.pumpAndSettle();
          for (final p in f.controller.session.players) {
            final token = find.byWidgetPredicate(
              (w) => w is TabletTokenCard && w.token.id == p.tokens.first.id,
            );
            expect(tester.widget<TabletTokenCard>(token).expanded, isTrue);
            expect(
              tester.getSize(find.byKey(ValueKey(p.tokens.first.id))).width,
              widths[p.id],
            );
            expect(lists[p.id]!.offset, 80);
          }
          await capture(
            tester,
            '2-horizontal-expanded-${size.width.toInt()}-open-$cycle',
          );
          await tester.tap(hub);
          await tester.pumpAndSettle();
          for (final p in f.controller.session.players) {
            expect(lists[p.id]!.offset, 80);
            lists[p.id]!.jumpTo(lists[p.id]!.position.maxScrollExtent);
          }
          await tester.pumpAndSettle();
          // Lazy lists refine their extent after expanded rows leave view.
          // Reach the final actual extent before checking the last action.
          for (final p in f.controller.session.players) {
            lists[p.id]!.jumpTo(lists[p.id]!.position.maxScrollExtent);
          }
          await tester.pumpAndSettle();
          for (final p in f.controller.session.players) {
            expect(
              find
                  .byKey(ValueKey('${p.tokens.last.id}-quantity-increase'))
                  .hitTestable(),
              findsOneWidget,
            );
            lists[p.id]!.jumpTo(80);
          }
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      },
    );
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

  for (final size in [const Size(480, 800), const Size(600, 1024)]) {
    testWidgets('two seats preserve narrow-window guard at $size', (
      tester,
    ) async {
      final f = await show(tester, size, 2);
      final before = jsonEncode(f.controller.state.toJson());
      expect(find.byKey(const ValueKey('table-surface')), findsNothing);
      expect(find.text('Give your table a little more room'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(GameDrawerWorkspace), findsOneWidget);
      expect(jsonEncode(f.controller.state.toJson()), before);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'short two-seat drawer keeps complete actions clear of the handles',
    (tester) async {
      final f = await show(tester, const Size(844, 480), 2);
      for (var i = 0; i < 16; i++) {
        await f.controller.updateState(
          'History sample $i',
          (state) => state.session.players.first.life--,
          recordHistory: true,
        );
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('central-game-controls')));
      await tester.pumpAndSettle();
      Finder body() => find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == 'game-drawer-body-viewport',
      );
      void expectInside(Finder target) {
        final viewport = tester.getRect(body());
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        for (final key in [
          'central-game-controls',
          'shared-dice',
          'shared-day-night',
        ]) {
          expect(
            rect.overlaps(tester.getRect(find.byKey(ValueKey(key)))),
            isFalse,
          );
        }
        expect(target.hitTestable(), findsOneWidget);
      }

      expectInside(find.byKey(const ValueKey('drawer-menu-dice')));
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: body(), matching: find.byType(Scrollable)).first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expectInside(find.byKey(const ValueKey('drawer-menu-boardWipes')));
      await capture(tester, '2-short-menu-last-actions');
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawer-menu-history')));
      await tester.pumpAndSettle();
      final undo = find
          .ancestor(
            of: find.text('Undo latest'),
            matching: find.byType(FilledButton),
          )
          .first;
      expectInside(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(f.controller.session.history.last.undone, isTrue);
      final historyScroll = tester.state<ScrollableState>(
        find.descendant(of: body(), matching: find.byType(Scrollable)).first,
      );
      historyScroll.position.jumpTo(historyScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expectInside(find.text('History sample 0'));
      await capture(tester, '2-short-history-last-row');
      expect(tester.takeException(), isNull);
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
  testWidgets(
    'two-seat utility scroll offset survives short rail and drawer round trips',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 2);
      await f.controller.updateState('Populate utility viewport', (state) {
        for (final p in state.session.players) {
          p.utilities.addAll([
            for (var i = 0; i < 12; i++)
              UtilityState(id: '${p.id}-extra-$i', name: 'Utility $i'),
          ]);
        }
      });
      await tester.pumpAndSettle();
      final scrolls = <ScrollController>[];
      for (final p in f.controller.session.players) {
        final list = find.descendant(
          of: find.byKey(ValueKey('${p.id}-utility-section')),
          matching: find.byType(ReorderableListView),
        );
        final scroll = tester
            .widget<ReorderableListView>(list)
            .scrollController!;
        scrolls.add(scroll);
        scroll.jumpTo(96);
      }
      await tester.pumpAndSettle();
      final hub = find.byKey(const ValueKey('central-game-controls'));
      for (var cycle = 0; cycle < 2; cycle++) {
        await tester.tap(hub);
        await tester.pumpAndSettle();
        for (final scroll in scrolls) {
          expect(scroll.offset, 96);
        }
        await tester.tap(hub);
        await tester.pumpAndSettle();
        for (final scroll in scrolls) {
          expect(scroll.offset, 96);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
    testWidgets('two-seat warnings at $size remain tappable closed and open', (
      tester,
    ) async {
      final f = await show(tester, size, 2);
      f.repository.failSave = true;
      final hub = find.byKey(const ValueKey('central-game-controls'));
      for (final open in [false, true]) {
        for (final player in f.controller.session.players) {
          await tester.tap(find.byKey(ValueKey('${player.id}-life-decrease')));
          await tester.pumpAndSettle();
        }
        if (open) {
          await tester.tap(hub);
          await tester.pumpAndSettle();
        }
        await capture(
          tester,
          '2-horizontal-warning-${size.width.toInt()}-${open ? "open" : "closed"}',
        );
        for (final player in f.controller.session.players) {
          final warning = find.byKey(
            ValueKey('${player.id}-acknowledge-life-error'),
          );
          expect(warning.hitTestable(), findsOneWidget);
          final rect = tester.getRect(warning);
          for (final control in [
            'central-game-controls',
            'shared-dice',
            'shared-day-night',
          ]) {
            expect(
              rect.overlaps(tester.getRect(find.byKey(ValueKey(control)))),
              isFalse,
            );
          }
          await tester.tapAt(rect.center);
          await tester.pumpAndSettle();
          expect(
            warning,
            findsNothing,
            reason:
                'Actual acknowledgement tap must clear warning, not open/close Menu',
          );
          expect(
            find.byType(GameDrawerWorkspace),
            open ? findsOneWidget : findsNothing,
          );
          expect(f.controller.player(player.id).life, 40);
        }
        if (open) {
          await tester.tap(hub);
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    });
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

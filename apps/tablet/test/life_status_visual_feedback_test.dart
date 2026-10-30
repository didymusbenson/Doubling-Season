import 'support/control_finders.dart';
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
import 'package:tripling_table/ui/table_mana_icons.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

const _captureKey = ValueKey('life-status-feedback-renderer');
final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalog;
  late String contrastArtwork;

  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('life-status-feedback-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    // A deterministic high-contrast image exercises actual artwork composition
    // without network dependencies or pretending to be a native screenshot.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 200),
      Paint()..color = const Color(0xFFFAE7A0),
    );
    canvas.drawRect(
      const Rect.fromLTWH(100, 0, 100, 200),
      Paint()..color = const Color(0xFF203B6A),
    );
    canvas.drawCircle(
      const Offset(100, 100),
      65,
      Paint()..color = const Color(0xFF9D3264),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    contrastArtwork =
        'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
    image.dispose();
    picture.dispose();
    final artworkFile = Platform.environment['TABLET_CAPTURE_ART_FILE'];
    if (artworkFile != null) {
      contrastArtwork =
          'data:image/jpeg;base64,${base64Encode(await File(artworkFile).readAsBytes())}';
    }
    if (_captureDirectory != null) {
      await Directory(_captureDirectory!).create(recursive: true);
      for (final entry in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final font = File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${entry.value}',
        );
        await (FontLoader(
          entry.key,
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
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

  Future<TableFixture> show(
    WidgetTester tester,
    Size size,
    int seats, {
    bool artwork = false,
    bool active = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    }
    if (seats == 3) state.session.players.removeAt(0);
    for (final player in state.session.players) {
      final profile = state.profiles.firstWhere(
        (profile) => profile.id == player.seatId,
      );
      profile.name =
          'A very long player name ${player.slot + 1} whose full identity remains accessible';
      if (artwork) profile.artworkUrl = contrastArtwork;
      if (active) {
        player.citysBlessing = true;
        player.counters = {
          'energy': 12,
          'poison': 3,
          'experience': 7,
          'radiation': 2,
          'custom': 9,
        };
        player.utilities.add(
          UtilityState(
            id: '${player.id}-initiative',
            kind: 'initiative',
            name: 'The Initiative',
            isActive: true,
            visible: false,
          ),
        );
      }
    }
    if (active) state.session.monarchPlayerId = state.session.players.first.id;
    final fixture = TableFixture(state);
    await fixture.initialize();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: fixture.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (artwork) {
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
    addTearDown(() async {
      if (byControlLabel('Close workspace').evaluate().isNotEmpty) {
        await tester.tap(byControlLabel('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
    });
    return fixture;
  }

  Rect local(WidgetTester tester, Finder child, Finder ancestor) {
    final box = tester.renderObject<RenderBox>(child);
    final parent = tester.renderObject<RenderBox>(ancestor);
    return MatrixUtils.transformRect(
      box.getTransformTo(parent),
      Offset.zero & box.size,
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    // Widget-test fake time does not advance image decoder work. Re-warm the
    // current providers after navigation, then let their real frame fade finish.
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
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_captureDirectory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final seats in [2, 3, 4]) {
      for (final artwork in [false, true]) {
        testWidgets(
          '$seats seats $size art=$artwork active state is on life with no name footer',
          (tester) async {
            final f = await show(tester, size, seats, artwork: artwork);
            for (final player in f.controller.session.players) {
              final profile = f.controller.profile(player.seatId);
              final surface = find.byKey(ValueKey('${player.id}-life-surface'));
              final name = find.byKey(ValueKey('${player.id}-player-name'));
              final total = find.byKey(ValueKey('${player.id}-life-number'));
              final ledger = find.byKey(
                ValueKey('${player.id}-commander-ledger'),
              );
              final summary = find.byKey(
                ValueKey('${player.id}-life-counter-summary'),
              );
              final tools = find.byKey(ValueKey('${player.id}-life-tools'));
              expect(
                tester
                    .widget<TableArtworkSurface>(
                      find
                          .descendant(
                            of: surface,
                            matching: find.byType(TableArtworkSurface),
                          )
                          .first,
                    )
                    .artworkFit,
                BoxFit.cover,
              );
              final miniArt = find.descendant(
                of: ledger,
                matching: find.byType(TableArtworkSurface),
              );
              expect(
                tester
                    .widgetList<TableArtworkSurface>(miniArt)
                    .every((art) => art.artworkFit == BoxFit.fitWidth),
                isTrue,
                reason:
                    'Life-only cover must not change the mini-ledger or token artwork policy.',
              );
              expect(
                local(tester, name, surface).bottom,
                lessThanOrEqualTo(local(tester, total, surface).top + .01),
              );
              expect(
                local(tester, total, surface).bottom,
                lessThanOrEqualTo(local(tester, ledger, surface).top + .01),
              );
              expect(
                local(tester, total, surface).height,
                greaterThanOrEqualTo(40),
              );
              expect(
                tester.getSize(surface).height,
                inInclusiveRange(160, 180),
              );
              expect(tester.getSize(tools).height, 48);
              expect(
                local(
                  tester,
                  summary,
                  surface,
                ).overlaps(local(tester, ledger, surface)),
                isFalse,
              );
              final ledgerBounds = local(tester, ledger, surface);
              final summaryBounds = local(tester, summary, surface);
              expect(summaryBounds.left, closeTo(ledgerBounds.right + 4, .01));
              expect(
                summaryBounds.center.dy,
                closeTo(ledgerBounds.center.dy, .01),
              );
              expect(
                find.descendant(of: surface, matching: summary),
                findsOneWidget,
              );
              expect(
                find.descendant(of: tools, matching: summary),
                findsNothing,
              );
              final text = tester.widget<Text>(name);
              expect(text.maxLines, 1);
              expect(text.overflow, TextOverflow.ellipsis);
              final nameBounds = local(tester, name, surface);
              final lifeClip = tester.widget<ClipPath>(
                find.byKey(ValueKey('${player.id}-life-clip')),
              );
              final clip = lifeClip.clipper!.getClip(tester.getSize(surface));
              for (final corner in [
                nameBounds.topLeft,
                nameBounds.topRight,
                nameBounds.bottomLeft,
                nameBounds.bottomRight,
              ]) {
                expect(
                  clip.contains(corner),
                  isTrue,
                  reason:
                      'The subdued name must clear the hub notch, not only fit its bounding box.',
                );
              }
              expect(
                tester
                    .getRect(name)
                    .overlaps(
                      tester.getRect(
                        find.byKey(const ValueKey('central-game-controls')),
                      ),
                    ),
                isFalse,
              );
              expect(text.style!.fontSize, lessThanOrEqualTo(14));
              expect(
                text.style!.fontWeight!.value,
                lessThan(FontWeight.w600.value),
              );
              for (final target in [
                summary,
                ledger,
                find.byKey(ValueKey('${player.id}-player-details')),
                find.byKey(ValueKey('${player.id}-manage-utilities')),
              ]) {
                expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
                expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
                final hitRegion = target == summary
                    ? byControlLabel('${profile.name}, player counters')
                    : target;
                expect(hitRegion.hitTestable(), findsOneWidget);
              }
              final semantics = tester.widget<Semantics>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label ==
                          '${profile.name}, player counters',
                ),
              );
              for (final expected in [
                'City’s blessing',
                'Initiative',
                'energy: 12',
                'poison: 3',
                'experience: 7',
                'radiation: 2',
                'custom: 9',
              ]) {
                expect(semantics.properties.value, contains(expected));
              }
              expect(
                find.descendant(
                  of: summary,
                  matching: find.byIcon(TableManaIcons.ascend),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(
                  of: summary,
                  matching: find.byIcon(Icons.explore_outlined),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(
                  of: summary,
                  matching: find.byType(MonarchCrown),
                ),
                player.id == f.playerId ? findsOneWidget : findsNothing,
              );
              final before = f.controller.session.toJson();
              await tester.tap(
                byControlLabel('${profile.name}, player counters'),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('commander-workspace')),
                findsOneWidget,
              );
              expect(
                find.byKey(const ValueKey('focused-commander-grid')),
                findsOneWidget,
              );
              expect(byControlLabel('Initiative, On'), findsOneWidget);
              expect(byControlLabel('City’s blessing, On'), findsOneWidget);
              expect(
                f.controller.session.toJson(),
                before,
                reason: 'Summary navigation must not change life or state.',
              );
              await tester.tap(byControlLabel('Close workspace'));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            if (seats == 4) {
              await capture(
                tester,
                'life-status-${size.width.toInt()}x${size.height.toInt()}-art$artwork',
              );
            }
          },
        );
      }
    }
  }

  for (final label in ['Monarch', 'City’s blessing', 'Initiative']) {
    testWidgets(
      'status semantics stays enabled and toggles $label through accessibility',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final f = await show(tester, const Size(1133, 744), 4, active: false);
          final originalLife = f.player.life;
          expect(
            find.byKey(ValueKey('${f.playerId}-life-counter-summary')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(ValueKey('${f.playerId}-commander-ledger')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('commander-workspace')),
            findsOneWidget,
          );

          bool activeState() => switch (label) {
            'Monarch' => f.controller.session.monarchPlayerId == f.playerId,
            'City’s blessing' => f.player.citysBlessing,
            'Initiative' => f.board.hasInitiative(f.playerId),
            _ => throw StateError('Unexpected status $label'),
          };

          for (final active in [false, true]) {
            final status = find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == '$label, ${active ? 'On' : 'Off'}',
            );
            expect(status, findsOneWidget, reason: '$label active=$active');
            final node = tester.getSemantics(status);
            final data = node.getSemanticsData();
            expect(
              data.flagsCollection.isEnabled,
              ui.Tristate.isTrue,
              reason:
                  'iOS switch accessibility requires an explicit enabled state.',
            );
            expect(
              data.flagsCollection.isToggled,
              active ? ui.Tristate.isTrue : ui.Tristate.isFalse,
            );
            expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
            expect(activeState(), active);
            node.owner!.performAction(node.id, ui.SemanticsAction.tap);
            await tester.pumpAndSettle();
            expect(activeState(), !active);
            expect(f.player.life, originalLife);
          }
          await tester.tap(byControlLabel('Close workspace'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'new-game Initiative claim transfer hold-clear and History undo persist',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4, active: false);
      final first = f.controller.session.players.first;
      final second = f.controller.session.players[1];
      for (final player in f.controller.session.players) {
        expect(
          find.byKey(ValueKey('${player.id}-life-counter-summary')),
          findsNothing,
        );
        final ledger = find.byKey(ValueKey('${player.id}-commander-ledger'));
        expect(tester.getSize(ledger).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(ledger).height, greaterThanOrEqualTo(44));
      }
      Future<void> open(PlayerState player) async {
        await tester.tap(find.byKey(ValueKey('${player.id}-commander-ledger')));
        await tester.pumpAndSettle();
      }

      await open(first);
      await tester.tap(byControlLabel('Initiative, Off'));
      await tester.pumpAndSettle();
      expect(f.board.hasInitiative(first.id), isTrue);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      await open(second);
      await tester.tap(byControlLabel('Initiative, Off'));
      await tester.pumpAndSettle();
      expect(f.board.hasInitiative(first.id), isFalse);
      expect(f.board.hasInitiative(second.id), isTrue);
      final history = f.controller.session.history.length;
      final held = await tester.startGesture(
        tester.getCenter(byControlLabel('Initiative, On')),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(f.board.hasInitiative(second.id), isFalse);
      await held.up();
      await tester.pumpAndSettle();
      expect(f.board.hasInitiative(second.id), isFalse);
      expect(f.controller.session.history.length, history + 1);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      await tester.tap(byControlLabel('Game controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Undo latest:'));
      await tester.pumpAndSettle();
      expect(f.board.hasInitiative(second.id), isTrue);
      final loaded = await f.repository.open();
      expect(
        loaded.state.session
            .player(second.id)
            .utilities
            .where((u) => u.kind == 'initiative' && u.isActive),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Day and Night have distinct high-contrast colors and hold release stays clear',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4, active: false);
      final target = find.byKey(const ValueKey('shared-day-night'));
      Material surface() => tester.widget<Material>(
        find.ancestor(of: target, matching: find.byType(Material)).first,
      );
      final neutral = surface().color;
      await tester.tap(target);
      await tester.pumpAndSettle();
      final warm = surface().color!;
      expect(warm, isNot(neutral));
      expect(warm.r, greaterThan(warm.b));
      await tester.tap(target);
      await tester.pumpAndSettle();
      final cool = surface().color!;
      expect(cool, isNot(warm));
      expect(cool.b, greaterThan(cool.r));
      final history = f.controller.session.history.length;
      final held = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 650));
      expect(f.controller.session.dayNight, 'neither');
      await held.up();
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'neither');
      expect(f.controller.session.history.length, history + 1);
      expect(surface().color, neutral);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(f.controller.session.dayNight, 'day');
      await capture(tester, 'life-status-day-color');
    },
  );

  testWidgets(
    'Storm stepper has separate contrasting bounded surface and full-size halves',
    (tester) async {
      final f = await show(tester, const Size(1133, 744), 4, active: false);
      for (final player in f.controller.session.players) {
        final storm = player.utilities.firstWhere(
          (u) => u.kind == 'storm_count',
        );
        final surface = find.byKey(ValueKey('${storm.id}-value-surface'));
        final container = tester.widget<Container>(surface);
        final decoration =
            (container.decoration ?? container.foregroundDecoration)
                as BoxDecoration;
        expect(decoration.border, isNotNull);
        expect(decoration.color, isNotNull);
        final stepper = find.descendant(
          of: surface,
          matching: find.byType(HalfStepper),
        );
        final halves = find.descendant(
          of: stepper,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_StepHalf',
          ),
        );
        expect(halves, findsNWidgets(2));
        for (final half in halves.evaluate()) {
          expect(
            tester.getSize(find.byWidget(half.widget)).width,
            greaterThanOrEqualTo(44),
          );
          expect(
            tester.getSize(find.byWidget(half.widget)).height,
            greaterThanOrEqualTo(44),
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}

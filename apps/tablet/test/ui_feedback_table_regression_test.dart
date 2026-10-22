import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:doubling_season/widgets/mana/mana_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/monarch_crown.dart';

import 'support/table_fixture.dart';

// These optional captures are Flutter widget-test renderer evidence. They are
// not browser, release-build, or native-device acceptance screenshots.
final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('flutter-test-renderer-table');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolatedCatalog;

  setUpAll(() async {
    isolatedCatalog = await Directory.systemTemp.createTemp('tablet-feedback-');
    Hive.init(isolatedCatalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (_captureDirectory != null) {
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
      // Review captures use real text and icons rather than test-font boxes.
      // Geometry/interaction tests do not require this machine-specific cache.
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.value}',
        );
        if (await file.exists()) {
          await (FontLoader(
            font.key,
          )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
      }
      await Directory(_captureDirectory!).create(recursive: true);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await isolatedCatalog.delete(recursive: true);
  });

  TabletState tableFor(int seats, {int tokens = 0}) {
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    } else if (seats == 3) {
      state.session.players.removeAt(0);
    }
    for (final player in state.session.players) {
      player.tokens = [
        for (var index = 0; index < tokens; index++)
          sampleToken(
            id: '${player.id}-token-$index',
            name: 'Saproling ${index + 1}',
          ),
      ];
    }
    return state;
  }

  Future<TableFixture> showTable(
    WidgetTester tester,
    Size size,
    TabletState state,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  // Rectangles include the 180-degree transform of the opposite-facing seats.
  Rect bounds(WidgetTester tester, Finder finder, {Finder? within}) {
    final box = tester.renderObject<RenderBox>(finder);
    final ancestor = within == null
        ? null
        : tester.renderObject<RenderBox>(within);
    return Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: ancestor),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: ancestor),
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$_captureDirectory/flutter-test-renderer-$name.png',
        ).writeAsBytes(png.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  testWidgets(
    'utility metadata persists without a color stripe while token color rails remain',
    (tester) async {
      final state = tableFor(4, tokens: 1);
      for (final player in state.session.players) {
        player.utilities.first.colors = 'RG';
        player.utilities.last.colors = 'U';
      }
      final fixture = await showTable(tester, const Size(1133, 744), state);
      final gradients = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      );
      final utilities = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_UtilityRow',
      );
      expect(
        find.descendant(of: utilities, matching: gradients),
        findsNothing,
        reason: 'Utility color metadata must not render a stripe.',
      );
      final tokenRails = find.descendant(
        of: find.byType(TabletTokenCard),
        matching: gradients,
      );
      expect(tokenRails, findsNWidgets(4));
      for (final rail in tokenRails.evaluate()) {
        expect(bounds(tester, find.byWidget(rail.widget)).width, 7);
      }
      await fixture.controller.adjustMana(fixture.playerId, 'W', 1);
      await tester.pumpAndSettle();
      final reloaded = TabletState.fromJson(
        jsonMap(jsonDecode(fixture.repository.encoded)),
      );
      for (final player in reloaded.session.players) {
        expect(player.utilities.first.colors, 'RG');
        expect(player.utilities.last.colors, 'U');
        expect(player.tokens.single.colors, 'G');
      }
      await capture(tester, '4p-utilities-without-color-stripes');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('game controls are a standalone compact central component', (
    tester,
  ) async {
    await showTable(tester, const Size(1133, 744), tableFor(4));
    final hub = find.byKey(const ValueKey('central-game-controls'));
    expect(hub, findsOneWidget);
    expect(bounds(tester, hub).size, const Size(52, 52));
    expect(
      bounds(tester, hub).center,
      bounds(tester, find.byKey(const ValueKey('table-surface'))).center,
    );
    expect(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_GameStrip'),
      findsNothing,
    );
  });

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        '$seats seats at $size keep dividers, game controls and local token FABs clear',
        (tester) async {
          final fixture = await showTable(
            tester,
            size,
            tableFor(seats, tokens: 4),
          );
          final divider = find.byKey(
            const ValueKey('player-horizontal-divider'),
          );
          expect(bounds(tester, divider).height, 3);
          final hardVerticalDividers = find.byWidgetPredicate(
            (widget) => widget is VerticalDivider && widget.thickness == 3,
          );
          expect(hardVerticalDividers, findsNWidgets(seats == 2 ? 0 : 2));
          for (final element in hardVerticalDividers.evaluate()) {
            expect(bounds(tester, find.byWidget(element.widget)).width, 3);
          }
          final strip = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_GameHub',
          );
          final stripBounds = bounds(tester, strip);
          expect(
            stripBounds.center.dx,
            closeTo(size.width / 2, .01),
            reason:
                'Game controls must be centered in global table coordinates.',
          );
          expect(
            stripBounds.center.dy,
            closeTo(bounds(tester, divider).center.dy, .01),
            reason:
                'Game controls must straddle the center seam, not sit in bottom seats.',
          );
          final tableBounds = bounds(
            tester,
            find.byKey(const ValueKey('table-surface')),
          );
          expect(stripBounds.center, tableBounds.center);
          expect(stripBounds.size, const Size(52, 52));
          final shell = tester.widget<Material>(
            find.descendant(of: strip, matching: find.byType(Material)).first,
          );
          expect(shell.shape, isA<CircleBorder>());
          expect(
            find.byKey(const ValueKey('game-strip-player-divider')),
            findsNothing,
          );
          final tableHeight = size.height - 44;
          for (final player in fixture.controller.session.players) {
            final name = fixture.controller.profile(player.seatId).name;
            final life = find.byKey(ValueKey('${player.id}-life-surface'));
            expect(bounds(tester, life).overlaps(stripBounds), isFalse);
            final decrease = find.byKey(ValueKey('${player.id}-life-decrease'));
            final increase = find.byKey(ValueKey('${player.id}-life-increase'));
            final hitBounds = bounds(
              tester,
              decrease,
            ).expandToInclude(bounds(tester, increase));
            final surfaceBounds = bounds(tester, life);
            for (final edges in [
              [hitBounds.left, surfaceBounds.left],
              [hitBounds.right, surfaceBounds.right],
              [hitBounds.top, surfaceBounds.top],
              [hitBounds.bottom, surfaceBounds.bottom],
            ]) {
              expect(
                edges[0],
                closeTo(edges[1], .001),
                reason: 'Every part of the colored surface belongs to a half.',
              );
            }
            final tools = find.byKey(ValueKey('${player.id}-life-tools'));
            expect(bounds(tester, tools).overlaps(stripBounds), isFalse);
            expect(
              bounds(tester, tools).overlaps(bounds(tester, life)),
              isFalse,
            );
            expect(
              find.descendant(of: tools, matching: find.byType(MonarchCrown)),
              findsOneWidget,
            );
            final monarch = find.byTooltip('$name, Monarch, disabled');
            final blessing = find.byTooltip('$name, City’s blessing, disabled');
            final crownPosition = bounds(tester, monarch, within: tools).center;
            final blessingPosition = bounds(
              tester,
              blessing,
              within: tools,
            ).center;
            expect(crownPosition.dy, blessingPosition.dy);
            expect(crownPosition.dx, lessThan(blessingPosition.dx));
            final editPosition = bounds(
              tester,
              find.byKey(ValueKey('${player.id}-player-details')),
              within: tools,
            ).center;
            for (final label in [
              '$name, player counters',
              '$name, rules',
              '$name, commander damage',
            ]) {
              final button = find.byTooltip(label);
              expect(button.hitTestable(), findsOneWidget);
              final point = bounds(tester, button, within: tools).center;
              expect(
                point.dy < editPosition.dy || point.dx < editPosition.dx,
                isTrue,
                reason: 'Edit is last in player-local tool order.',
              );
            }
            expect(find.byTooltip('$name, saved presets'), findsNothing);
            final manage = find.byKey(
              ValueKey('${player.id}-manage-utilities'),
            );
            expect(manage.hitTestable(), findsOneWidget);
            expect(find.descendant(of: tools, matching: manage), findsNothing);
            expect(
              find.descendant(
                of: find.byKey(ValueKey('${player.id}-utility-section')),
                matching: manage,
              ),
              findsOneWidget,
            );
            final lane = find.byKey(ValueKey('${player.id}-token-lane'));
            final fab = find.byKey(ValueKey('${player.id}-add-token'));
            final laneSize = tester.getSize(lane);
            final firstName = find.descendant(
              of: lane,
              matching: find.text('Saproling 1'),
            );
            expect(firstName.hitTestable(), findsOneWidget);
            final nameBounds = bounds(tester, firstName);
            final laneBounds = bounds(tester, lane);
            expect(
              nameBounds.left,
              greaterThanOrEqualTo(laneBounds.left - .01),
            );
            expect(nameBounds.right, lessThanOrEqualTo(laneBounds.right + .01));
            final localFab = bounds(tester, fab, within: lane);
            expect(fab.hitTestable(), findsOneWidget);
            expect(localFab.right, closeTo(laneSize.width - 12, .01));
            expect(localFab.bottom, closeTo(laneSize.height - 12, .01));
            expect(laneSize.height, closeTo((tableHeight - 3) / 2, .01));
            expect(
              bounds(tester, lane).overlaps(stripBounds),
              isFalse,
              reason: '$name token board must remain uninterrupted.',
            );
            final summary = find.byTooltip('$name, board summary');
            expect(summary.hitTestable(), findsOneWidget);
            expect(
              find.descendant(of: lane, matching: summary),
              findsOneWidget,
            );
            final localSummary = bounds(
              tester,
              find.byKey(ValueKey('${player.id}-board-summary')),
              within: lane,
            );
            expect(localSummary.right, closeTo(laneSize.width - 68, .01));
            expect(localSummary.bottom, closeTo(laneSize.height - 12, .01));
            expect(localSummary.overlaps(localFab), isFalse);
            final tokenList = find.descendant(
              of: lane,
              matching: find.byType(ReorderableListView),
            );
            final localList = bounds(tester, tokenList, within: lane);
            expect(localList.top, 0);
            expect(localList.left, 0);
            expect(localList.size, laneSize);
            expect(
              tester.widget<ReorderableListView>(tokenList).padding,
              const EdgeInsets.only(bottom: 88),
              reason: 'Compact corner controls must not reserve a header.',
            );
            for (final status in ['Monarch', 'City’s blessing']) {
              expect(
                find.byTooltip('$name, $status, disabled').hitTestable(),
                findsOneWidget,
              );
            }
          }
          expect(find.byTooltip('Game controls').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            '${seats}p-${size.width.toInt()}x${size.height.toInt()}',
          );
        },
      );
    }
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        '$seats seats at $size center game controls in the physical view when safe insets are zero',
        (tester) async {
          await showTable(tester, size, tableFor(seats));
          tester.view.padding = const FakeViewPadding();
          await tester.pumpAndSettle();
          final strip = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_GameHub',
          );
          expect(bounds(tester, strip).center.dx, closeTo(size.width / 2, .01));
          expect(
            bounds(tester, strip).center.dy,
            closeTo(size.height / 2, .01),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'direct life change shows a readable delta beside the seat name',
    (tester) async {
      final fixture = await showTable(
        tester,
        const Size(1133, 744),
        tableFor(4),
      );
      final id = fixture.playerId;
      await tester.tap(find.byKey(ValueKey('$id-life-decrease')));
      await tester.tap(find.byKey(ValueKey('$id-life-decrease')));
      await tester.pumpAndSettle();
      expect(fixture.player.life, 38);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('$id-life-delta')),
          matching: find.text('-2'),
        ),
        findsOneWidget,
      );
      await capture(tester, '4p-direct-life-running-delta');
    },
  );

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (var empty = 0; empty < 4; empty++) {
      testWidgets(
        '3p empty slot $empty at $size retains clear direct shared controls',
        (tester) async {
          final state = tableFor(4);
          state.session.players.removeWhere((p) => p.slot == empty);
          await showTable(tester, size, state);
          final strip = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_GameHub',
          );
          final table = find.byKey(const ValueKey('table-surface'));
          expect(bounds(tester, strip).center, bounds(tester, table).center);
          for (final label in [
            'Roll dice',
            'History & undo',
            'Reset / reload',
          ]) {
            final button = find.widgetWithText(OutlinedButton, label);
            expect(button.hitTestable(), findsOneWidget);
            expect(
              bounds(tester, button).overlaps(bounds(tester, strip)),
              isFalse,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'centered hub at $size keeps every game action available without changing players',
      (tester) async {
        final fixture = await showTable(tester, size, tableFor(2));
        final before = fixture.controller.session.toJson();
        await tester.tap(find.byTooltip('Game controls'));
        await tester.pumpAndSettle();
        for (final label in ['History', 'Reset', 'Dice', 'Settings']) {
          expect(
            find.widgetWithText(ChoiceChip, label).hitTestable(),
            findsOneWidget,
          );
        }
        await tester.tapAt(const Offset(2, 30));
        await tester.pumpAndSettle();
        expect(fixture.controller.session.toJson(), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'empty P/T glyphs, long names and large totals stay readable at $size',
      (tester) async {
        final state = tableFor(4);
        for (final player in state.session.players) {
          player.tokens = [
            sampleToken(
              id: '${player.id}-treasure',
              name: 'Treasure',
              pt: '',
              type: 'Artifact — Treasure',
              colors: '',
              amount: 12,
              tapped: 0,
              sick: 0,
            ),
            sampleToken(
              id: '${player.id}-large',
              name: 'A very long creature token name with many words',
              amount: 999999,
              tapped: 888888,
              sick: 777777,
            ),
          ];
        }
        final fixture = await showTable(tester, size, state);
        final player = fixture.controller.session.players.first;
        final treasure = find.byWidgetPredicate(
          (widget) =>
              widget is TabletTokenCard &&
              widget.token.id == '${player.id}-treasure',
        );
        await tester.tap(
          find.descendant(of: treasure, matching: find.text('Treasure')),
        );
        await tester.pumpAndSettle();
        for (final icon in [ManaIcons.power, ManaIcons.toughness]) {
          final glyph = find.descendant(
            of: treasure,
            matching: find.byIcon(icon),
          );
          expect(glyph.hitTestable(), findsOneWidget);
          expect(tester.widget<Icon>(glyph).icon!.fontFamily, 'Mana');
        }
        expect(find.text('P/T'), findsNothing);
        for (final other in fixture.controller.session.players.skip(1)) {
          final large = find.byWidgetPredicate(
            (widget) =>
                widget is TabletTokenCard &&
                widget.token.id == '${other.id}-large',
          );
          final name = find.descendant(
            of: large,
            matching: find.text(
              'A very long creature token name with many words',
            ),
          );
          final total = find.descendant(
            of: large,
            matching: find.text('999999'),
          );
          expect(name.hitTestable(), findsOneWidget);
          expect(total.hitTestable(), findsOneWidget);
          expect(bounds(tester, name).overlaps(bounds(tester, total)), isFalse);
        }
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          '4p-${size.width.toInt()}x${size.height.toInt()}-mana-glyphs-long-name-large-totals',
        );
      },
    );
  }

  testWidgets(
    'last expanded token actions scroll completely above its floating add button',
    (tester) async {
      final state = tableFor(4, tokens: 18);
      state.session.players.first.tokens.last.abilities = List.filled(
        24,
        'Flying, vigilance, and a long ability description to exercise a token taller than its lane.',
      ).join(' ');
      state.session.players.first.tokens.last.type = List.filled(
        20,
        'Legendary Artifact Creature — Saproling, with a deliberately long type line',
      ).join(' ');
      final fixture = await showTable(tester, const Size(1133, 744), state);
      final player = fixture.controller.session.players.first;
      final lastId = player.tokens.last.id;
      final lane = find.byKey(ValueKey('${player.id}-token-lane'));
      final list = tester.widget<ReorderableListView>(
        find.descendant(of: lane, matching: find.byType(ReorderableListView)),
      );
      list.scrollController!.jumpTo(
        list.scrollController!.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      final lastCard = find.byWidgetPredicate(
        (widget) => widget is TabletTokenCard && widget.token.id == lastId,
      );
      await tester.tap(
        find.descendant(of: lastCard, matching: find.text('Saproling 18')),
      );
      await tester.pumpAndSettle();
      list.scrollController!.jumpTo(
        list.scrollController!.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      final fab = find.byKey(ValueKey('${player.id}-add-token'));
      final fabTop = bounds(tester, fab, within: lane).top;
      expect(
        tester.getSize(lastCard).height,
        greaterThan(tester.getSize(lane).height),
      );
      for (final label in [
        'Remove one; hold to remove all',
        'Add one; hold to add ten',
        'Untap one; hold to untap all',
        'Tap one; hold to tap all',
        'Add +1/+1 counter; hold to add ten',
        'Copy one fresh token',
        'Split stack',
      ]) {
        final action = find.descendant(
          of: lastCard,
          matching: find.byTooltip(label),
        );
        expect(action.hitTestable(), findsOneWidget, reason: label);
        expect(
          bounds(tester, action, within: lane).bottom,
          lessThan(fabTop),
          reason: label,
        );
      }
      final addCounter = find.descendant(
        of: lastCard,
        matching: find.byTooltip('Add +1/+1 counter; hold to add ten'),
      );
      expect(addCounter.hitTestable(), findsOneWidget);
      await tester.tap(addCounter);
      await tester.pumpAndSettle();
      expect(
        fixture.controller.player(player.id).tokens.last.plusOneCounters,
        1,
      );
      expect(fab.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, '4p-mini-landscape-last-expanded-token');
    },
  );

  testWidgets(
    'status badges transfer monarch, preserve independent blessings and undo',
    (tester) async {
      final fixture = await showTable(
        tester,
        const Size(1366, 1024),
        tableFor(4),
      );
      final players = fixture.controller.session.players;
      String name(int index) =>
          fixture.controller.profile(players[index].seatId).name;
      Future<void> tapStatus(int index, String status, bool enabled) async {
        await tester.tap(
          find.byTooltip(
            '${name(index)}, $status, ${enabled ? 'enabled' : 'disabled'}',
          ),
        );
        await tester.pumpAndSettle();
      }

      await tapStatus(0, 'Monarch', false);
      expect(fixture.controller.session.monarchPlayerId, players[0].id);
      expect(fixture.controller.session.history.last.label, 'Claim monarch');
      expect(fixture.controller.session.history.last.playerId, players[0].id);
      await tapStatus(0, 'City’s blessing', false);
      await tapStatus(1, 'City’s blessing', false);
      await tapStatus(1, 'Monarch', false);
      expect(fixture.controller.session.monarchPlayerId, players[1].id);
      expect(find.byTooltip('${name(0)}, Monarch, disabled'), findsOneWidget);
      expect(find.byTooltip('${name(1)}, Monarch, enabled'), findsOneWidget);
      expect(
        players
            .take(2)
            .map((p) => fixture.controller.player(p.id).citysBlessing),
        everyElement(isTrue),
      );
      expect(await fixture.controller.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(fixture.controller.session.monarchPlayerId, players[0].id);
      expect(find.byTooltip('${name(0)}, Monarch, enabled'), findsOneWidget);
      expect(find.byTooltip('${name(1)}, Monarch, disabled'), findsOneWidget);
      expect(fixture.controller.player(players[1].id).citysBlessing, isTrue);
      expect(await fixture.controller.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(players[0].id).citysBlessing, isTrue);
      expect(fixture.controller.player(players[1].id).citysBlessing, isFalse);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, '4p-status-badges-after-undo');
    },
  );

  testWidgets(
    'direct commander trackers retain source owner identity, partner and self damage with undo',
    (tester) async {
      final state = tableFor(2);
      final recipient = state.session.players.first;
      final opponent = state.session.players.last;
      final owner = state.profiles.firstWhere((p) => p.id == opponent.seatId);
      owner.artworkUrl =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      state.session.commanders = [
        CommanderSource(
          id: 'partner-a',
          ownerPlayerId: opponent.id,
          name: 'Partner A',
        ),
        CommanderSource(
          id: 'partner-b',
          ownerPlayerId: opponent.id,
          name: 'Partner B',
        ),
        CommanderSource(
          id: 'self',
          ownerPlayerId: recipient.id,
          name: 'Self commander',
        ),
      ];
      final fixture = await showTable(tester, const Size(1133, 744), state);
      final recipientName = fixture.controller.profile(recipient.seatId).name;
      final unchangedOpponent = fixture.controller.player(opponent.id).toJson();
      final row = find.byKey(ValueKey('${recipient.id}-commander-trackers'));
      expect(row.hitTestable(), findsOneWidget);
      final lifePanel = find.descendant(
        of: find.byKey(ValueKey(recipient.id)),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_LifePanel',
        ),
      );
      expect(
        bounds(tester, row).bottom,
        closeTo(bounds(tester, lifePanel).bottom, .01),
      );
      expect(tester.getSize(row).height, 44);
      final sources = tester.widget<ListView>(
        find.descendant(of: row, matching: find.byType(ListView)),
      );
      var sourceIndex = 0;
      expect(
        bounds(tester, row).overlaps(
          bounds(tester, find.byKey(ValueKey('${recipient.id}-token-lane'))),
        ),
        isFalse,
      );
      for (final source in fixture.controller.session.commanders) {
        sources.controller!.jumpTo(
          (sourceIndex++ * 144.0).clamp(
            0,
            sources.controller!.position.maxScrollExtent,
          ),
        );
        await tester.pumpAndSettle();
        final sourceOwner = fixture.controller.player(source.ownerPlayerId);
        final identity = fixture.controller.profile(sourceOwner.seatId);
        final chip = find.byKey(
          ValueKey('${recipient.id}-commander-${source.id}'),
        );
        expect(chip.hitTestable(), findsOneWidget);
        final sourceLabel = find.descendant(
          of: chip,
          matching: find.text(source.name),
        );
        expect(
          tester.getSize(sourceLabel).width,
          greaterThanOrEqualTo(80),
          reason:
              'Partner suffixes need a readable label area independent of the value/edit controls.',
        );
        final container = tester.widget<Container>(
          find.descendant(of: chip, matching: find.byType(Container)).first,
        );
        final border =
            (container.foregroundDecoration! as BoxDecoration).border!
                as Border;
        expect(border.top.color, Color(identity.color));
        expect(
          tester
              .widget<TableArtworkSurface>(
                find.descendant(
                  of: chip,
                  matching: find.byType(TableArtworkSurface),
                ),
              )
              .url,
          identity.artworkUrl,
        );
        final add = find.byTooltip(
          '$recipientName, increase damage from ${source.name} (${identity.name})',
        );
        expect(add.hitTestable(), findsOneWidget);
        expect(tester.getSize(add).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(add).height, greaterThanOrEqualTo(44));
        expect(
          bounds(tester, chip).left,
          greaterThanOrEqualTo(bounds(tester, row).left - .01),
        );
        expect(
          bounds(tester, chip).right,
          lessThanOrEqualTo(bounds(tester, row).right + .01),
        );
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(
          fixture.controller.player(recipient.id).commanderDamage[source.id],
          1,
        );
        expect(fixture.controller.session.history.last.playerId, recipient.id);
        expect(
          fixture.controller.session.history.last.summary,
          '${source.name} damage +1',
        );
      }
      expect(fixture.controller.player(recipient.id).life, 37);
      expect(
        fixture.controller.player(opponent.id).toJson(),
        unchangedOpponent,
      );
      expect(await fixture.controller.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(recipient.id).life, 38);
      expect(
        fixture.controller.player(recipient.id).commanderDamage['self'] ?? 0,
        0,
      );
      expect(
        fixture.controller.player(recipient.id).commanderDamage['partner-a'],
        1,
      );
      expect(
        fixture.controller.player(recipient.id).commanderDamage['partner-b'],
        1,
      );
      sources.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(
          '$recipientName, decrease damage from Partner A (${owner.name})',
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.controller.player(recipient.id).life, 39);
      expect(
        fixture.controller.player(recipient.id).commanderDamage['partner-a'],
        0,
      );
      expect(await fixture.controller.undo(), isTrue);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(recipient.id).life, 38);
      expect(
        fixture.controller.player(recipient.id).commanderDamage['partner-a'],
        1,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, '2p-direct-commander-partner-self-trackers');
    },
  );
}

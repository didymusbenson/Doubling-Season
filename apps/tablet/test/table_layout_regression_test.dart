import 'support/control_finders.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

// Optional evidence uses the Flutter widget renderer, not a release browser.
final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('capacity-renderer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolatedCatalog;
  setUpAll(() async {
    isolatedCatalog = await Directory.systemTemp.createTemp(
      'tablet-layout-catalog-',
    );
    Hive.init(isolatedCatalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (_captureDirectory != null) {
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
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
      await Directory(_captureDirectory!).create(recursive: true);
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await isolatedCatalog.delete(recursive: true);
  });

  TabletState tableFor(int seats) {
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    }
    if (seats == 3) state.session.players.removeAt(0);
    for (final player in state.session.players) {
      player.tokens = [
        for (var n = 0; n < 4; n++)
          sampleToken(
            id: '${player.id}-token-$n',
            name: 'Saproling ${n + 1}',
            counters: {'charge': 1},
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
    // Include iPad safe-area space: fitting only edge-to-edge web content
    // would miss the original mini-landscape clipping regression.
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
    for (final player in fixture.controller.session.players) {
      final seat = find.byKey(ValueKey(player.id));
      final token = find.byKey(ValueKey('${player.id}-token-lane'));
      final life = find.descendant(
        of: seat,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_LifePanel',
        ),
      );
      final tokenWidth = tester.getSize(token).width;
      final innerWidth = tester.getSize(life).width;
      final surface = find.byKey(ValueKey('${player.id}-life-surface'));
      final tools = find.byKey(ValueKey('${player.id}-life-tools'));
      expect(
        tester.getSize(surface).width,
        closeTo(innerWidth, .01),
        reason: 'Tools stay below the full-width colored life surface.',
      );
      expect(tester.getRect(surface).overlaps(tester.getRect(tools)), isFalse);
      expect(tokenWidth / (tokenWidth + innerWidth), closeTo(.6, .0001));
      expect(innerWidth / (tokenWidth + innerWidth), closeTo(.4, .0001));
      expect(
        tokenWidth + innerWidth + 1,
        closeTo(tester.getSize(seat).width, .01),
      );
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  bool allowsUtilityScroll(Size size, int seats) =>
      size == const Size(1133, 744) || size == const Size(744, 1133);

  ScrollController utilityScroll(WidgetTester tester, PlayerState player) =>
      tester
          .widget<ReorderableListView>(
            find.descendant(
              of: find.byKey(ValueKey('${player.id}-utility-section')),
              matching: find.byType(ReorderableListView),
            ),
          )
          .scrollController!;

  Future<void> revealUtilityControl(
    WidgetTester tester,
    PlayerState player,
    Finder control,
    bool mayScroll,
  ) async {
    final bounds = tester.getRect(control);
    final height = tester.view.physicalSize.height;
    if (mayScroll &&
        (control.hitTestable().evaluate().isEmpty ||
            bounds.top < 24 ||
            bounds.bottom > height - 20)) {
      // A partially clipped control can pass the center-point hit test. Reveal
      // its whole touch target before checking the scrollable utility lane.
      await Scrollable.ensureVisible(tester.element(control), alignment: .5);
      await tester.pumpAndSettle();
    }
    expect(
      control.hitTestable(),
      findsOneWidget,
      reason: 'Every full-size mana control must remain directly reachable.',
    );
  }

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        '$seats seats at $size expose every default mana control at full touch size',
        (tester) async {
          final fixture = await showTable(tester, size, tableFor(seats));
          expect(tester.takeException(), isNull);
          expect(
            byControlLabel(RegExp(r'^Storm, (expand|collapse)$')).hitTestable(),
            findsNWidgets(seats),
          );
          expect(find.text('Mana pool').hitTestable(), findsNWidgets(seats));
          for (final player in fixture.controller.session.players) {
            final name = fixture.controller.profile(player.seatId).name;
            expect(
              find.text(name),
              findsOneWidget,
              reason: 'Seat identity belongs in the life counter.',
            );
            for (final type in PlayerState.manaColors) {
              for (final action in ['add', 'spend']) {
                final target = find.byKey(
                  ValueKey('${player.id}-mana-$type-$action'),
                );
                await revealUtilityControl(
                  tester,
                  player,
                  target,
                  allowsUtilityScroll(size, seats),
                );
                final bounds = tester.getRect(target);
                expect(bounds.top, greaterThanOrEqualTo(24));
                expect(bounds.bottom, lessThanOrEqualTo(size.height - 20));
              }
            }
          }
        },
      );
    }
  }

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final seats in [2, 3, 4]) {
      for (final partners in [false, true]) {
        testWidgets(
          '$seats seats at $size retain default utility capacity with ${partners ? 'partners' : 'one source'}',
          (tester) async {
            final state = tableFor(seats);
            final owners = partners
                ? state.session.players
                : [state.session.players.last];
            state.session.commanders = [
              for (final owner in owners)
                for (var n = 0; n < (partners ? 2 : 1); n++)
                  CommanderSource(
                    id: '${owner.id}-$n',
                    ownerPlayerId: owner.id,
                    name: n == 0 ? 'Partner A' : 'Partner B',
                  ),
            ];
            for (final player in state.session.players) {
              for (var n = 0; n < PlayerState.manaColors.length; n++) {
                player.mana[PlayerState.manaColors[n]] = n + 1;
              }
              player.utilities
                      .firstWhere((u) => u.kind == 'storm_count')
                      .value =
                  7;
              for (var n = 0; n < state.session.commanders.length; n++) {
                player.commanderDamage[state.session.commanders[n].id] = n + 1;
              }
            }
            final fixture = await showTable(tester, size, state);
            for (final player in fixture.controller.session.players) {
              final seat = find.byKey(ValueKey(player.id));
              final life = find.descendant(
                of: seat,
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_LifePanel',
                ),
              );
              final lifeText = find.descendant(
                of: life,
                matching: find.text('40'),
              );
              expect(
                tester.widget<Text>(lifeText).style!.fontSize,
                greaterThanOrEqualTo(64),
                reason: 'Commander capacity must preserve life legibility.',
              );
              final utilities = tester.widget<ReorderableListView>(
                find.descendant(
                  of: find.byKey(ValueKey('${player.id}-utility-section')),
                  matching: find.byType(ReorderableListView),
                ),
              );
              expect(
                utilities.scrollController!.position.maxScrollExtent,
                lessThanOrEqualTo(
                  allowsUtilityScroll(size, seats)
                      ? (size.width < size.height
                            ? 28
                            : (seats == 2 ? 74 : 106))
                      : 1,
                ),
                reason:
                    'Shared-control clearance permits modest utility scrolling; all life and mana controls retain full targets.',
              );
              final ledger = find.byKey(
                ValueKey('${player.id}-commander-ledger'),
              );
              expect(ledger.hitTestable(), findsOneWidget);
              expect(tester.getSize(ledger).width, inInclusiveRange(60, 80));
              expect(tester.getSize(ledger).height, 44);
              for (final source in fixture.controller.session.commanders) {
                final cell = find.byKey(
                  ValueKey('${player.id}-ledger-source-${source.id}'),
                );
                expect(
                  find.descendant(of: ledger, matching: cell),
                  findsOneWidget,
                );
                final owner = fixture.controller.player(source.ownerPlayerId);
                final identity = fixture.controller.profile(owner.seatId);
                final decoration =
                    tester
                            .widget<DecoratedBox>(
                              find
                                  .descendant(
                                    of: cell,
                                    matching: find.byType(DecoratedBox),
                                  )
                                  .first,
                            )
                            .decoration
                        as BoxDecoration;
                expect(
                  (decoration.border! as Border).top.color,
                  Color(identity.color),
                );
              }
              for (final color in PlayerState.manaColors) {
                for (final action in ['add', 'spend']) {
                  final control = find.byKey(
                    ValueKey('${player.id}-mana-$color-$action'),
                  );
                  await revealUtilityControl(
                    tester,
                    player,
                    control,
                    allowsUtilityScroll(size, seats),
                  );
                  final bounds = tester.getRect(control);
                  expect(bounds.top, greaterThanOrEqualTo(24));
                  expect(bounds.bottom, lessThanOrEqualTo(size.height - 20));
                  expect(
                    bounds.height,
                    closeTo(44, .01),
                    reason: 'Mana targets retain a 44px touch height.',
                  );
                }
              }
            }
            for (final player in fixture.controller.session.players) {
              utilityScroll(tester, player).jumpTo(0);
            }
            await tester.pumpAndSettle();
            expect(
              byControlLabel(
                RegExp(r'^Storm, (expand|collapse)$'),
              ).hitTestable(),
              findsNWidgets(seats),
            );
            expect(tester.takeException(), isNull);
            if (_captureDirectory != null &&
                partners &&
                (seats != 3 || size.width == 1133)) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(_captureKey),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                try {
                  final png = (await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  ))!;
                  await File(
                    '$_captureDirectory/flutter-test-renderer-capacity-${seats}p-${size.width.toInt()}x${size.height.toInt()}-partners.png',
                  ).writeAsBytes(png.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
          },
        );
      }
    }
  }

  testWidgets(
    'mini landscape mana spending stays on board and preserves other seats',
    (tester) async {
      final fixture = await showTable(
        tester,
        const Size(1133, 744),
        tableFor(4),
      );
      final player = fixture.controller.session.players.first;
      final add = find.byKey(ValueKey('${player.id}-mana-W-add'));
      final spend = find.byKey(ValueKey('${player.id}-mana-W-spend'));
      // The additional life tool row keeps full-size controls: reach mana by
      // an actual player-local scroll gesture rather than tapping clipped ink.
      await tester.drag(
        find.byKey(ValueKey('${player.id}-utility-section')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(add.hitTestable(), findsOneWidget);
      final bottomAdd = find.byKey(ValueKey('${player.id}-mana-C-add'));
      final bottomSpend = find.byKey(ValueKey('${player.id}-mana-C-spend'));
      expect(bottomAdd.hitTestable(), findsOneWidget);
      await tester.tap(bottomAdd);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['C'], 1);
      await tester.tap(bottomSpend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['C'], 0);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 1);
      await tester.longPress(add);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 11);
      await tester.tap(spend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 10);
      await tester.longPress(spend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 0);
      for (final other in fixture.controller.session.players.skip(1)) {
        expect(other.mana['W'] ?? 0, 0);
      }
      expect(find.byType(AlertDialog), findsNothing);
      await tester.drag(
        find.byKey(ValueKey('${player.id}-utility-section')),
        const Offset(0, 100),
      );
      await tester.pumpAndSettle();
      expect(
        byControlLabel(RegExp(r'^Storm, (expand|collapse)$')).hitTestable(),
        findsNWidgets(4),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [7, 123, 999999]) {
    testWidgets('portrait Storm displays $count in a full-width direct stepper', (
      tester,
    ) async {
      final state = tableFor(4);
      for (final player in state.session.players) {
        player.utilities.firstWhere((u) => u.kind == 'storm_count').value =
            count;
      }
      final fixture = await showTable(tester, const Size(744, 1133), state);
      expect(find.text('Storm').hitTestable(), findsNWidgets(4));
      for (final player in fixture.controller.session.players) {
        final section = find.byKey(ValueKey('${player.id}-utility-section'));
        final stepper = find.descendant(
          of: section,
          matching: find.byWidgetPredicate(
            (w) => w is HalfStepper && w.label == 'Storm',
          ),
        );
        final bounds = tester.getRect(stepper);
        final storm = player.utilities.firstWhere(
          (utility) => utility.kind == 'storm_count',
        );
        final valueSurface = find.byKey(ValueKey('${storm.id}-value-surface'));
        expect(tester.getSize(valueSurface).width, greaterThan(130));
        expect(
          bounds.width,
          closeTo(tester.getSize(valueSurface).width - 2, .01),
        );
        expect(bounds.height, 44);
        final value = find.descendant(
          of: stepper,
          matching: find.text('$count'),
        );
        final render = tester.renderObject<RenderBox>(value);
        final painted = MatrixUtils.transformRect(
          render.getTransformTo(null),
          Offset.zero & render.size,
        );
        expect(
          painted.height,
          greaterThanOrEqualTo(18),
          reason:
              'Fitting the complete value must not reduce it to a fragment.',
        );
        expect(bounds.inflate(.01).contains(painted.topLeft), isTrue);
        expect(bounds.inflate(.01).contains(painted.bottomRight), isTrue);
      }
      if (_captureDirectory != null && count == 999999) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_captureKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$_captureDirectory/flutter-test-renderer-storm-999999-4p-744x1133.png',
            ).writeAsBytes(png.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      final player = fixture.controller.session.players.last;
      final section = find.byKey(ValueKey('${player.id}-utility-section'));
      int currentStorm() => fixture.controller
          .player(player.id)
          .utilities
          .firstWhere((u) => u.kind == 'storm_count')
          .value;
      await tester.tap(
        find.descendant(
          of: section,
          matching: byControlLabel('Decrease Storm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(currentStorm(), count - 1);
      await tester.tap(
        find.descendant(
          of: section,
          matching: byControlLabel('Increase Storm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(currentStorm(), count);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('narrow portrait lane bounds large utility and mana values', (
    tester,
  ) async {
    final state = tableFor(4);
    for (final player in state.session.players) {
      player.utilities.first.value = 999999;
      player.counters['poison'] = 999999;
      for (final type in PlayerState.manaColors) {
        player.mana[type] = 999999;
      }
    }
    await showTable(tester, const Size(744, 1133), state);
    expect(
      byControlLabel(RegExp(r'^Storm, (expand|collapse)$')).hitTestable(),
      findsNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });
}

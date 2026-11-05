import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';

import 'support/table_fixture.dart';
import 'support/control_finders.dart';

const _captureKey = ValueKey('reorder-rotation-capture');

class _Basis {
  _Basis(RenderBox box)
    : origin = box.localToGlobal(Offset.zero),
      x = box.localToGlobal(const Offset(10, 0)),
      y = box.localToGlobal(const Offset(0, 10));
  final Offset origin, x, y;
  Offset get dx => x - origin;
  Offset get dy => y - origin;
  Map<String, Object> toJson() => {
    'origin': [origin.dx, origin.dy],
    'x': [x.dx, x.dy],
    'y': [y.dx, y.dy],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('reorder-rotation-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    if (captures != null) {
      await Directory(captures).create(recursive: true);
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
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<TableFixture> show(
    WidgetTester tester, {
    int seats = 4,
    bool phone = false,
    bool compact = false,
    int utilityCount = 3,
  }) async {
    final size = phone
        ? const Size(390, 844)
        : compact
        ? const Size(650, 480)
        : const Size(1133, 744);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.display.size = size;
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    final state = TabletState.initial();
    state.session.players = state.session.players.take(seats).toList();
    for (var p = 0; p < seats; p++) {
      final player = state.session.players[p];
      player.tokens = [
        for (var i = 0; i < 3; i++)
          sampleToken(
            id: '${player.id}-token-$i',
            name: 'P${p + 1} token $i',
            type: '',
            abilities: '',
          ),
      ];
      player.utilities = [
        for (var i = 0; i < utilityCount; i++)
          UtilityState(
            id: '${player.id}-utility-$i',
            name: 'P${p + 1} tool $i',
            value: i + 2,
          ),
      ];
    }
    final fixture = TableFixture(state);
    await fixture.initialize();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(
            controller: fixture.controller,
            enablePhonePresentation: phone,
            compactPlayerOne: phone,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
    return fixture;
  }

  Rect globalBounds(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    final points = [
      Offset.zero,
      Offset(box.size.width, 0),
      Offset(0, box.size.height),
      Offset(box.size.width, box.size.height),
    ].map(box.localToGlobal).toList();
    return Rect.fromLTRB(
      points.map((p) => p.dx).reduce(math.min),
      points.map((p) => p.dy).reduce(math.min),
      points.map((p) => p.dx).reduce(math.max),
      points.map((p) => p.dy).reduce(math.max),
    );
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Map<String, Object> measurements,
  ) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final pending = boundary.toImage(pixelRatio: 1);
    await tester.runAsync(() async {
      final image = await pending;
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$captures/$name.png').writeAsBytes(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
        await File('$captures/$name.geometry.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(measurements),
        );
      } finally {
        image.dispose();
      }
    });
  }

  void closeOffset(Offset actual, Offset expected, String reason) {
    expect(actual.dx, closeTo(expected.dx, .5), reason: reason);
    expect(actual.dy, closeTo(expected.dy, .5), reason: reason);
  }

  for (final checkOrientation in [true, false]) {
    testWidgets(
      'P2 token drag preserves ${checkOrientation ? 'oriented basis' : 'off-center grab anchor'}',
      (tester) async {
        final f = await show(tester);
        final player = f.controller.session.players[1];
        final name = find.text('P2 token 0');
        final before = _Basis(tester.renderObject<RenderBox>(name));
        closeOffset(before.dx, const Offset(-10, 0), 'P2 starts rotated.');
        closeOffset(before.dy, const Offset(0, -10), 'P2 starts rotated.');
        final box = tester.renderObject<RenderBox>(name);
        final localGrab = Offset(box.size.width * .23, box.size.height * .35);
        final start = box.localToGlobal(localGrab);
        const movement = Offset(0, -30);
        final gesture = await tester.startGesture(start);
        try {
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveBy(movement);
          await tester.pump(const Duration(milliseconds: 80));
          final during = _Basis(tester.renderObject<RenderBox>(name));
          final grab = tester
              .renderObject<RenderBox>(name)
              .localToGlobal(localGrab);
          final row = find.byWidgetPredicate(
            (widget) =>
                widget is TabletTokenCard &&
                widget.token.id == player.tokens.first.id,
          );
          final bounds = globalBounds(tester, row);
          await capture(
            tester,
            'p2-token-${checkOrientation ? 'basis' : 'anchor'}',
            {
              'before': before.toJson(),
              'during': during.toJson(),
              'pointer': [start.dx + movement.dx, start.dy + movement.dy],
              'grab': [grab.dx, grab.dy],
              'proxyBounds': [
                bounds.left,
                bounds.top,
                bounds.right,
                bounds.bottom,
              ],
            },
          );
          if (checkOrientation) {
            closeOffset(
              during.dx,
              before.dx,
              'The dragged token keeps its seat-facing x basis.',
            );
            closeOffset(
              during.dy,
              before.dy,
              'The dragged token keeps its seat-facing y basis.',
            );
          } else {
            closeOffset(
              grab,
              start + movement,
              'The same off-center point stays under the pointer.',
            );
          }
        } finally {
          await gesture.cancel();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  final scenarios = [
    for (var seat = 0; seat < 4; seat++)
      (kind: 'token', seat: seat, seats: 4, phone: false, compact: false),
    (kind: 'token', seat: 1, seats: 2, phone: false, compact: false),
    (kind: 'token', seat: 0, seats: 4, phone: true, compact: false),
    for (var seat = 0; seat < 4; seat++)
      (kind: 'utility', seat: seat, seats: 4, phone: false, compact: false),
    (kind: 'utility', seat: 0, seats: 4, phone: true, compact: false),
    for (var seat = 0; seat < 4; seat++)
      (kind: 'utility', seat: seat, seats: 4, phone: false, compact: true),
  ];
  for (final scenario in scenarios) {
    final label =
        '${scenario.phone ? 'phone' : '${scenario.seats}-seat'}-'
        'p${scenario.seat + 1}-${scenario.compact ? 'compact-' : ''}${scenario.kind}';
    testWidgets('$label keeps orientation, anchor, bounds, order and undo', (
      tester,
    ) async {
      final f = await show(
        tester,
        seats: scenario.seats,
        phone: scenario.phone,
        compact: scenario.compact,
        utilityCount: scenario.phone && scenario.kind == 'token' ? 0 : 3,
      );
      final playerId = f.controller.session.players[scenario.seat].id;
      final token = scenario.kind == 'token';
      final originalPlayer = f.controller.player(playerId);
      final original = token
          ? originalPlayer.tokens.map((t) => t.id).toList()
          : originalPlayer.utilities.map((u) => u.id).toList();
      final otherSeats = {
        for (final p in f.controller.session.players)
          if (p.id != playerId) p.id: jsonEncode(p.toJson()),
      };
      final originalObjects = token
          ? originalPlayer.tokens.map((t) => jsonEncode(t.toJson())).toList()
          : originalPlayer.utilities
                .map((u) => jsonEncode(u.toJson()))
                .toList();
      List<String> currentIds() => token
          ? f.controller.player(playerId).tokens.map((t) => t.id).toList()
          : f.controller.player(playerId).utilities.map((u) => u.id).toList();
      Future<void> enterCompact() async {
        if (!scenario.compact) return;
        await showAdaptiveUtilities(tester, playerId: playerId);
        final footer = find.byKey(ValueKey('$playerId-life-footer-scroll'));
        tester.widget<CustomScrollView>(footer).controller!.jumpTo(48);
        await tester.pumpAndSettle();
        final enter = find.byKey(ValueKey('$playerId-start-utility-reorder'));
        await tester.ensureVisible(enter);
        await tester.pumpAndSettle();
        await tester.tap(enter);
        await tester.pumpAndSettle();
        tester
            .widget<CustomScrollView>(
              find.byKey(ValueKey('$playerId-compact-utility-reorder')),
            )
            .controller!
            .jumpTo(0);
        await tester.pumpAndSettle();
      }

      for (final forward in [true, false]) {
        await enterCompact();
        final index = forward
            ? 0
            : token
            ? 1
            : 2;
        final id = original[index];
        final name = find.text(
          'P${scenario.seat + 1} ${token ? 'token' : 'tool'} $index',
        );
        if (!forward) {
          final ScrollController scroll;
          if (scenario.phone || scenario.compact) {
            final scrollView = scenario.phone
                ? find.byKey(const PageStorageKey('phone-player-one-scroll'))
                : find.byKey(ValueKey('$playerId-compact-utility-reorder'));
            scroll = tester.widget<CustomScrollView>(scrollView).controller!;
          } else {
            final lane = find.byKey(
              ValueKey('$playerId-${token ? 'token-lane' : 'utility-section'}'),
            );
            scroll = tester
                .widget<ReorderableListView>(
                  find.descendant(
                    of: lane,
                    matching: find.byType(ReorderableListView),
                  ),
                )
                .scrollController!;
          }
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        await Scrollable.ensureVisible(tester.element(name), alignment: .5);
        await tester.pumpAndSettle();
        final tokenTarget = token
            ? tester.getCenter(
                find.text('P${scenario.seat + 1} token ${forward ? 1 : 0}'),
              )
            : null;
        final beforeBox = tester.renderObject<RenderBox>(name);
        final before = _Basis(beforeBox);
        final rotated =
            !scenario.phone && (scenario.seat == 1 || scenario.seat == 2);
        final sign = rotated ? -1.0 : 1.0;
        closeOffset(
          before.dx,
          Offset(sign * 10, 0),
          'Content starts facing its player.',
        );
        closeOffset(
          before.dy,
          Offset(0, sign * 10),
          'Content starts facing its player.',
        );
        final localGrab = Offset(
          beforeBox.size.width * .23,
          beforeBox.size.height * .35,
        );
        final start = beforeBox.localToGlobal(localGrab);
        final direction = sign * (forward ? 1 : -1);
        final movement = Offset(0, direction * 10);
        final boundary = scenario.phone
            ? find.byKey(const PageStorageKey('phone-player-one-scroll'))
            : scenario.compact
            ? find.byKey(ValueKey('$playerId-utility-reorder-boundary'))
            : find.byKey(
                ValueKey(
                  '$playerId-${token ? 'token-lane' : 'utility-section'}',
                ),
              );
        final bounds = globalBounds(tester, boundary);
        Finder row() => token
            ? find.byWidgetPredicate(
                (w) => w is TabletTokenCard && w.token.id == id,
              )
            : scenario.compact
            ? find.byKey(ValueKey('compact-reorder-$id'))
            : find.ancestor(
                of: name,
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_UtilityRow',
                ),
              );
        final gesture = await tester.startGesture(start);
        var released = false;
        try {
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveBy(movement);
          await tester.pump(const Duration(milliseconds: 80));
          final duringBox = tester.renderObject<RenderBox>(name);
          final during = _Basis(duringBox);
          final grab = duringBox.localToGlobal(localGrab);
          await capture(tester, '$label-${forward ? 'forward' : 'backward'}', {
            'before': before.toJson(),
            'during': during.toJson(),
            'pointer': [start.dx + movement.dx, start.dy + movement.dy],
            'grab': [grab.dx, grab.dy],
          });
          closeOffset(
            during.dx,
            before.dx,
            'A lifted item retains its horizontal orientation.',
          );
          closeOffset(
            during.dy,
            before.dy,
            'A lifted item retains its vertical orientation.',
          );
          closeOffset(
            grab,
            start + movement,
            'An off-center grip follows the pointer.',
          );
          final destination = tokenTarget == null
              ? Offset(
                  start.dx,
                  direction > 0 ? bounds.bottom + 100 : bounds.top - 100,
                )
              : Offset(start.dx, tokenTarget.dy + direction * 20);
          // Cross insertion thresholds as a real drag does. A single teleport
          // can skip the SDK's overlapping-item regions and leave its gap stale.
          for (var step = 1; step <= 30; step++) {
            await gesture.moveTo(
              Offset.lerp(start + movement, destination, step / 30)!,
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          for (var tick = 0; tick < 25; tick++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final proxy = globalBounds(tester, row());
          await capture(
            tester,
            '$label-${forward ? 'forward' : 'backward'}-endpoint',
            {
              'laneBounds': [
                bounds.left,
                bounds.top,
                bounds.right,
                bounds.bottom,
              ],
              'proxyBounds': [proxy.left, proxy.top, proxy.right, proxy.bottom],
            },
          );
          expect(
            bounds.inflate(.5).contains(proxy.topLeft),
            isTrue,
            reason: 'The drag proxy remains inside its seat/lane.',
          );
          expect(
            bounds.inflate(.5).contains(proxy.bottomRight),
            isTrue,
            reason: 'The drag proxy remains inside its seat/lane.',
          );
          await gesture.up();
          released = true;
          await tester.pumpAndSettle();
        } finally {
          if (!released) await gesture.cancel();
          await tester.pumpAndSettle();
        }
        final expected = token
            ? [original[1], original[0], original[2]]
            : forward
            ? [original[1], original[2], original[0]]
            : [original[2], original[0], original[1]];
        expect(
          currentIds(),
          expected,
          reason:
              'Drop order follows player-local ${forward ? 'forward' : 'backward'} list direction.',
        );
        final reloaded = await f.repository.open();
        final persisted = reloaded.state.session.player(playerId);
        expect(
          token
              ? persisted.tokens.map((t) => t.id).toList()
              : persisted.utilities.map((u) => u.id).toList(),
          expected,
        );
        final nowObjects = token
            ? f.controller
                  .player(playerId)
                  .tokens
                  .map((t) => jsonEncode(t.toJson()))
                  .toList()
            : f.controller
                  .player(playerId)
                  .utilities
                  .map((u) => jsonEncode(u.toJson()))
                  .toList();
        expect(
          nowObjects,
          unorderedEquals(originalObjects),
          reason: 'Reorder preserves each item payload.',
        );
        for (final other in otherSeats.entries) {
          expect(
            jsonEncode(f.controller.player(other.key).toJson()),
            other.value,
            reason: 'Other seat state is untouched.',
          );
        }
        expect(await f.controller.undo(), isTrue);
        await tester.pumpAndSettle();
        expect(currentIds(), original);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

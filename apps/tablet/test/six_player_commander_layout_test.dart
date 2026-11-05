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
import 'support/control_finders.dart';

TabletState multiplayerState(int count) {
  final state = TabletState.initial();
  for (var i = state.session.players.length; i < count; i++) {
    final profile = SeatProfile(
      id: 'seat-$i',
      name: 'Player ${i + 1}',
      color: 0xff83b7ce,
    );
    state.profiles.add(profile);
    state.session.players.add(
      PlayerState(id: 'player-$i', seatId: profile.id, slot: i),
    );
  }
  state.session.commanders = [
    for (final player in state.session.players)
      for (var i = 0; i < 2; i++)
        CommanderSource(
          id: '${player.id}-$i',
          ownerPlayerId: player.id,
          name: i == 0 ? 'Commander' : 'Partner',
        ),
  ];
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['TABLET_CAPTURE_DIR'] == null) return;
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
  for (final count in [5, 6]) {
    test('$count owners retain every source in player-local rows', () {
      final players = multiplayerState(count).session.players;
      expect(
        CommanderSeatLayout.rowsFor(
          players,
          0,
        ).map((row) => row.map((p) => p?.slot).toList()).toList(),
        count == 5
            ? [
                [1, 2],
                [0, 4, 3],
              ]
            : [
                [1, 5, 2],
                [0, 4, 3],
              ],
      );
      for (var turns = 0; turns < 4; turns++) {
        final rows = CommanderSeatLayout.rowsFor(players, turns);
        expect(
          rows
              .expand((row) => row)
              .whereType<PlayerState>()
              .map((p) => p.id)
              .toSet(),
          players.map((p) => p.id).toSet(),
        );
      }
      for (final player in players) {
        expect(
          CommanderSeatLayout.turnsForPlayer(players, player),
          [1, 2, 5].contains(player.slot) ? 2 : 0,
        );
      }
    });

    for (final size in [const Size(650, 480), const Size(1133, 744)]) {
      for (final turns in [0, 1, 2, 3]) {
        testWidgets(
          '$count players twelve-source capacity $size rotation $turns',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            final f = TableFixture(multiplayerState(count));
            await f.initialize();
            f.catalog.loaded = true;
            addTearDown(() async {
              if (byControlLabel('Close workspace').evaluate().isNotEmpty) {
                await tester.tap(byControlLabel('Close workspace'));
                await tester.pumpAndSettle();
              }
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
              f.dispose();
            });
            final player = f.controller.session.players.last;
            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('six-commander-capture'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  theme: tableTheme(Brightness.dark),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: SizedBox(
                          width: 180,
                          child: CommanderLedger(
                            controller: f.controller,
                            recipient: player,
                            onOpen: () => showTableWorkspace(
                              context,
                              f.controller,
                              catalog: f.catalog,
                              seatId: player.id,
                              quarterTurns: turns,
                              initialPage: WorkspacePage.commanderDamage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final source
                in f.controller.session.commanderTrackingSources) {
              expect(
                find.byKey(ValueKey('${player.id}-ledger-source-${source.id}')),
                findsOneWidget,
              );
            }
            await tester.tap(find.byType(CommanderLedger));
            await tester.pumpAndSettle();
            final grid = find.byKey(const ValueKey('focused-commander-grid'));
            expect(grid, findsOneWidget);
            final gridBox = tester.renderObject<RenderBox>(grid);
            final rows = CommanderSeatLayout.rowsFor(
              f.controller.session.players,
              turns,
            );
            Offset ownerCenter(PlayerState owner) => gridBox.globalToLocal(
              tester.getCenter(
                find.byKey(ValueKey('commander-owner-${owner.id}')),
              ),
            );
            for (var row = 0; row < rows.length; row++) {
              final owners = rows[row].whereType<PlayerState>().toList();
              for (var col = 1; col < owners.length; col++) {
                expect(
                  ownerCenter(owners[col - 1]).dx,
                  lessThan(ownerCenter(owners[col]).dx),
                );
              }
              if (row > 0) {
                expect(
                  ownerCenter(rows[row - 1].whereType<PlayerState>().first).dy,
                  lessThan(ownerCenter(owners.first).dy),
                );
              }
            }
            final original = f.controller.state.toJson();
            for (final source
                in f.controller.session.commanderTrackingSources) {
              for (final action in ['increase', 'decrease']) {
                final finder = find.byKey(
                  ValueKey('commander-$action-${source.id}'),
                );
                await tester.ensureVisible(finder);
                await tester.pumpAndSettle();
                expect(finder.hitTestable(), findsOneWidget);
                final bounds = tester.getSize(finder);
                expect(bounds.width, greaterThanOrEqualTo(44));
                expect(bounds.height, greaterThanOrEqualTo(44));
              }
            }
            expect(
              f.controller.state.toJson(),
              original,
              reason: 'Scrolling and opening cannot write gameplay history.',
            );
            final source = f.controller.session.commanderTrackingSources.last;
            final target = find.byKey(
              ValueKey('commander-increase-${source.id}'),
            );
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(f.controller.player(player.id).life, 39);
            expect(
              f.controller.player(player.id).commanderDamage[source.id],
              1,
            );
            expect(await f.controller.undo(), isTrue);
            await tester.pumpAndSettle();
            expect(f.controller.player(player.id).life, 40);
            expect(
              f.controller.player(player.id).commanderDamage[source.id] ?? 0,
              0,
            );
            final capture = Platform.environment['TABLET_CAPTURE_DIR'];
            if (capture != null && turns == 0 && size.width == 1133) {
              final grid = find.byKey(const ValueKey('focused-commander-grid'));
              await Scrollable.ensureVisible(
                tester.element(grid),
                alignment: 0,
              );
              await tester.pumpAndSettle();
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('six-commander-capture')),
              );
              final pending = boundary.toImage(pixelRatio: 1);
              await tester.runAsync(() async {
                final image = await pending;
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(capture).create(recursive: true);
                await File(
                  '$capture/commander-$count-players.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            expect(tester.takeException(), isNull);
            await tester.tap(byControlLabel('Close workspace'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('focused-commander-grid')),
              findsNothing,
            );
          },
        );
      }
    }
  }
}

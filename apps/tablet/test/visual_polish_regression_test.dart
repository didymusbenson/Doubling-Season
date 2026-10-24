import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('polish-modal-renderer');
const _fixtureArt =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAABgCAIAAABaGO0eAAABbElEQVR4nO3bWw0CQRQEUcQgggRjmEMHdrCwPHaq73QlJWBun9/dy/V+M7AL/oLyBBCgOwEE6E4AAboTQIDuBBCgOwEE6E4AAboTQIDuBBDgcK/n43j4a/cB+Gj3cRK5AD/uPkUiFODv68caxAGcNH0sQxbAgvXTDFIAlk2fxhABgKwfYsADgOsnGMAA+Pq4AQmA755gIEArAL54iAEDgG+dYyBAHwC+cpTBagB83zQDAQTIa1sAfNlAAwEEiGxDAHzTTAMBBEhNAAEEEEAAAQQQQAABBBBAAAEEEEAAAaYCzDJYtokAAkS2J8AUg5WDCCBAXjsD5BssXsOvo8n1BWgFyDRAdvAfMXJ9AboBcgzABfxTnlw/AoA1wG+PAKAM8KuDABYz4JeGAqwxwG+MBjiVAb9rDMAZBvhFwwD+JYG/fzzAdxL4azcE2DIBBOhOAAG6E0CA7gQQoDsBBOhOAAG6E0CA7gQQoDsB4N7vK09igIP+QwAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      Directory? sdk = File(Platform.resolvedExecutable).parent;
      while (sdk != null &&
          !Directory(
            '${sdk.path}/bin/cache/artifacts/material_fonts',
          ).existsSync()) {
        final parent = sdk.parent;
        sdk = parent.path == sdk.path ? null : parent;
      }
      if (sdk == null) {
        throw StateError(
          'Flutter material fonts are required for visual-fit tests.',
        );
      }
      final file = File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/${font.value}',
      );
      if (await file.exists()) {
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    if (_captureDirectory != null) {
      await Directory(_captureDirectory!).create(recursive: true);
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final pixels = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = (await pixels.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        await File(
          '$_captureDirectory/flutter-renderer-$name.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
      } finally {
        pixels.dispose();
      }
    });
  }

  const scenes = <String, WorkspacePage>{
    'life-edit': WorkspacePage.player,
    'appearance': WorkspacePage.player,
    'edit-commanders': WorkspacePage.player,
    'commander-grid': WorkspacePage.commanderDamage,
    'commander-setup': WorkspacePage.commanderDamage,
    'commander-correction': WorkspacePage.commanderDamage,
    'counters': WorkspacePage.counters,
    'counter-correction': WorkspacePage.counters,
    'mana': WorkspacePage.utilities,
    'storm': WorkspacePage.utilities,
    'utility-selection': WorkspacePage.utilities,
    'rules': WorkspacePage.rules,
    'rules-custom': WorkspacePage.rules,
    'dice': WorkspacePage.dice,
    'reset-new-game': WorkspacePage.reset,
    'reset-three-player': WorkspacePage.reset,
    'reset-archives': WorkspacePage.reset,
    'reset-wipes': WorkspacePage.reset,
    'presets': WorkspacePage.presets,
    'token-search': WorkspacePage.tokens,
    'token-create': WorkspacePage.tokens,
    'token-custom': WorkspacePage.tokens,
    'token-status': WorkspacePage.tokenStatus,
    'token-counters': WorkspacePage.tokenCounters,
    'token-split': WorkspacePage.tokenSplit,
    'token-art': WorkspacePage.tokenArtwork,
    'token-art-many': WorkspacePage.tokenArtwork,
    'token-art-empty': WorkspacePage.tokenArtwork,
    'token-art-preview': WorkspacePage.tokenArtwork,
    'token-details': WorkspacePage.token,
    'token-summary': WorkspacePage.tokenSummary,
    'settings': WorkspacePage.settings,
    'history': WorkspacePage.history,
  };

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final scene in scenes.entries) {
      for (final turns in [
        0,
        if (size.width == 1133 &&
            {
              'life-edit',
              'mana',
              'token-status',
              'commander-grid',
              'counters',
              'counter-correction',
              'reset-new-game',
              'token-art',
              'token-art-many',
              'token-art-empty',
              'token-art-preview',
              'token-create',
              'rules',
              'dice',
            }.contains(scene.key))
          2,
      ]) {
        testWidgets(
          'populated ${scene.key} at $size facing $turns stays readable and dismisses without clickthrough',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
            addTearDown(tester.view.reset);
            final state = stateWithTokens(
              [
                sampleToken(
                  id: 'polish-token',
                  name: 'Goblin',
                  artworkUrl: _fixtureArt,
                  type: 'Creature — Goblin',
                  colors: 'R',
                  amount: 12,
                  tapped: 4,
                  sick: 3,
                  plusOne: 2,
                  abilities: 'Haste',
                  counters: {'charge': 3},
                ),
                sampleToken(
                  id: 'polish-token-2',
                  name: 'Treasure',
                  pt: '',
                  type: 'Artifact — Treasure',
                  amount: 8,
                  tapped: 0,
                  sick: 0,
                  colors: '',
                ),
              ],
              modifiers: ['doubling_season'],
            );
            final player = state.session.players.first;
            player.counters.addAll({
              'energy': 5,
              'poison': 2,
              'experience': 3,
              'radiation': 1,
            });
            player.mana.addAll({
              'W': 6,
              'U': 2,
              'B': 1,
              'R': 3,
              'G': 5,
              'C': 2,
            });
            player.utilities.firstWhere((u) => u.kind == 'storm_count').value =
                7;
            state.session.commanders = [
              CommanderSource(
                id: 'partner-a',
                ownerPlayerId: state.session.players[1].id,
                name: 'Partner A',
              ),
              CommanderSource(
                id: 'partner-b',
                ownerPlayerId: state.session.players[1].id,
                name: 'Partner B',
              ),
              CommanderSource(
                id: 'self',
                ownerPlayerId: player.id,
                name: 'Own commander',
              ),
            ];
            player.commanderDamage.addAll({
              'partner-a': 6,
              'partner-b': 2,
              'self': 1,
            });
            if (scene.key == 'token-art-many') {
              player.tokens.first.artworkOptions.addAll([
                for (var index = 0; index < 20; index++)
                  {
                    'url': _fixtureArt,
                    'set': 'Fixture $index',
                    'artist': 'Synthetic image',
                  },
              ]);
            }
            if (scene.key == 'token-art-empty') {
              player.tokens.first.artworkUrl = null;
              player.tokens.first.artworkOptions.clear();
              player.tokens.first.definitionId = 'no-art-fixture';
            }
            final f = TableFixture(state);
            await f.initialize();
            addTearDown(() async {
              try {
                if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
                  await tester.tap(find.byTooltip('Close workspace'));
                  await tester.pumpAndSettle();
                }
              } finally {
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pumpAndSettle();
                f.dispose();
              }
            });
            f.catalog.loaded = true;
            final definition = TokenDefinition(
              name: 'Goblin',
              abilities: 'Haste',
              pt: '1/1',
              colors: 'R',
              type: 'Creature — Goblin',
              popularity: 1,
              artwork: [
                ArtworkVariant(
                  set: 'Fixture',
                  url: _fixtureArt,
                  artist: 'Synthetic test image',
                ),
              ],
            );
            await f.catalog.saveCustom(definition);
            await PresetService(
              f.controller,
              f.catalog,
            ).save(f.playerId, 'Weekend Goblins');
            await f.controller.adjustLife(f.playerId, -3);
            if (scene.key == 'reset-archives') {
              await f.controller.resetGame(keepBoard: true);
            }
            final item = scene.key == 'mana'
                ? f.player.utilities.firstWhere((u) => u.kind == 'mana_pool').id
                : scene.key == 'storm'
                ? f.player.utilities
                      .firstWhere((u) => u.kind == 'storm_count')
                      .id
                : scene.key.startsWith('token-') &&
                      !{
                        'token-search',
                        'token-create',
                        'token-custom',
                      }.contains(scene.key)
                ? 'polish-token'
                : null;
            var launches = 0;
            await tester.pumpWidget(
              RepaintBoundary(
                key: _captureKey,
                child: MaterialApp(
                  theme: tableTheme(Brightness.dark),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => Center(
                        child: TextButton(
                          onPressed: () {
                            launches++;
                            showTableWorkspace(
                              context,
                              f.controller,
                              catalog: f.catalog,
                              seatId:
                                  {
                                    'dice',
                                    'reset-archives',
                                    'reset-new-game',
                                    'reset-three-player',
                                    'reset-wipes',
                                    'history',
                                    'settings',
                                  }.contains(scene.key)
                                  ? null
                                  : f.player.seatId,
                              initialPage: scene.value,
                              itemId: item,
                              quarterTurns: turns,
                            );
                          },
                          child: const Text('Open audit state'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open audit state'));
            await tester.pumpAndSettle();
            switch (scene.key) {
              case 'appearance':
                await tester.tap(find.widgetWithText(ChoiceChip, 'Appearance'));
              case 'edit-commanders':
                await tester.tap(find.widgetWithText(ChoiceChip, 'Commanders'));
              case 'commander-setup':
                await tester.tap(find.byTooltip('Edit commander sources'));
              case 'commander-correction':
                await tester.tap(find.byKey(const ValueKey('commander-edit-partner-a')));
              case 'token-create':
                await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Goblin · 1/1').first);
              case 'token-custom':
                await tester.tap(find.text('Custom token'));
              case 'reset-three-player':
                await tester.tap(find.widgetWithText(ChoiceChip, '3 players'));
              case 'reset-archives':
                await tester.tap(find.widgetWithText(ChoiceChip, 'Archives'));
              case 'reset-wipes':
                await tester.tap(
                  find.widgetWithText(ChoiceChip, 'Board wipes'),
                );
              case 'rules-custom':
                await tester.ensureVisible(find.text('Create a custom rule'));
                await tester.tap(find.text('Create a custom rule'));
              case 'counter-correction':
                await tester.tap(find.byTooltip('Set radiation total'));
              case 'token-art-preview':
                await tester.tap(find.text('TEST\nTest artist'));
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 80)),
                );
              case 'dice':
                await tester.tap(find.text('Roll selected dice'));
            }
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${scene.key} layout',
            );
            expect(
              find.byTooltip('Close workspace').hitTestable(),
              findsOneWidget,
            );
            if ({
              'life-edit',
              'rules-custom',
              'counters',
              'dice',
              'token-custom',
              'token-details',
              'token-create',
              'token-status',
              'reset-new-game',
              'reset-three-player',
              'reset-wipes',
              'settings',
            }.contains(scene.key)) {
              for (final list in find.byType(ListView).evaluate()) {
                final scroll = find
                    .descendant(
                      of: find.byWidget(list.widget),
                      matching: find.byType(Scrollable),
                    )
                    .first;
                if (scroll.evaluate().isEmpty) continue;
                expect(
                  tester
                      .state<ScrollableState>(scroll)
                      .position
                      .maxScrollExtent,
                  lessThanOrEqualTo(1),
                  reason: '${scene.key} fixed controls fit',
                );
              }
            }
            if (scene.key == 'counters') {
              expect(find.byType(TextField), findsNothing);
              final steppers = <Rect>[];
              for (final name in [
                'energy',
                'poison',
                'experience',
                'radiation',
              ]) {
                expect(
                  find.byTooltip('Set $name total').hitTestable(),
                  findsOneWidget,
                );
                steppers.add(
                  tester.getRect(
                    find.byWidgetPredicate(
                      (w) => w is HalfStepper && w.label == name,
                    ),
                  ),
                );
              }
              for (final rect in steppers) {
                expect(rect.width, closeTo(steppers.first.width, .01));
                expect(rect.height, closeTo(steppers.first.height, .01));
              }
              expect(
                steppers[0].center.dx,
                closeTo(steppers[2].center.dx, .01),
              );
              expect(
                steppers[1].center.dx,
                closeTo(steppers[3].center.dx, .01),
              );
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('context-workspace')))
                    .height,
                lessThanOrEqualTo(420),
              );
            }
            if (scene.key == 'counter-correction') {
              expect(find.byType(TextField), findsOneWidget);
              expect(find.text('Set').hitTestable(), findsOneWidget);
              expect(
                find.byTooltip('Cancel counter correction').hitTestable(),
                findsOneWidget,
              );
            }
            if (scene.key == 'rules') {
              expect(find.textContaining('Owned by'), findsNothing);
              expect(
                find.text('Global · applies to the entire table'),
                findsOneWidget,
              );
              expect(
                find.text('Create a custom rule').hitTestable(),
                findsOneWidget,
              );
            }
            if (scene.key == 'reset-new-game') {
              final field = find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.labelText == 'Starting life',
              );
              expect(tester.getSize(field).width, lessThanOrEqualTo(160));
              expect(find.text('20 life').hitTestable(), findsOneWidget);
              expect(find.text('40 life').hitTestable(), findsOneWidget);
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('context-workspace')))
                    .height,
                lessThanOrEqualTo(size.width < 760 ? 460 : 420),
              );
            }
            if (scene.key == 'token-create') {
              final chips = [
                for (final n in [1, 2, 3, 4, 5])
                  find.widgetWithText(ChoiceChip, '$n'),
              ];
              final parent = tester.renderObject<RenderBox>(
                find.byKey(const ValueKey('context-workspace')),
              );
              final positions = [
                for (final chip in chips)
                  parent.globalToLocal(tester.getCenter(chip)),
              ];
              for (final point in positions) {
                expect(point.dy, closeTo(positions.first.dy, .01));
              }
              final create = parent.globalToLocal(
                tester.getTopLeft(
                  find.widgetWithText(FilledButton, 'Create tokens'),
                ),
              );
              final quantity = parent.globalToLocal(
                tester.getTopLeft(find.byType(TextField).first),
              );
              expect(create.dx, closeTo(quantity.dx, .01));
            }
            if (scene.key == 'token-art-many') {
              final choices = tester.state<ScrollableState>(
                find
                    .descendant(
                      of: find.byKey(const ValueKey('artwork-options-scroll')),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              expect(choices.position.maxScrollExtent, greaterThan(0));
              expect(
                find.text('Preview image URL').hitTestable(),
                findsOneWidget,
              );
            }
            if (scene.key == 'token-art-empty') {
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('context-workspace')))
                    .height,
                lessThanOrEqualTo(360),
              );
              expect(
                find.text('Preview image URL').hitTestable(),
                findsOneWidget,
              );
            }
            if (scene.key == 'token-art-preview') {
              expect(
                find.text('Use this artwork').hitTestable(),
                findsOneWidget,
              );
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('context-workspace')))
                    .height,
                lessThanOrEqualTo(640),
              );
            }
            if (scene.key == 'token-art') {
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('context-workspace')))
                    .height,
                lessThanOrEqualTo(580),
              );
              expect(
                find.text('Preview image URL').hitTestable(),
                findsOneWidget,
              );
            }
            await capture(
              tester,
              '${scene.key}-${size.width.toInt()}x${size.height.toInt()}-turns$turns',
            );
            final snapshot = f.controller.session.toJson();
            await tester.tapAt(const Offset(1, 25));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Close workspace'), findsNothing);
            expect(launches, 1);
            expect(f.controller.session.toJson(), snapshot);
          },
        );
      }
    }
  }
}

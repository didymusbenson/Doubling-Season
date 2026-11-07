import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

const captureKey = ValueKey('utility-header-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['UTILITY_HEADER_CAPTURES'];
  late Directory cache;
  setUpAll(() async {
    cache = await Directory.systemTemp.createTemp('utility-header-');
    Hive.init(cache.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures == null) return;
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
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
  });
  tearDownAll(() async {
    await Hive.close();
    await cache.delete(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$captures/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final phone in [true, false]) {
    for (final seats in phone ? [2] : [2, 3, 4, 5, 6]) {
      for (final portrait in [false, true]) {
        final size = phone
            ? (portrait ? const Size(320, 700) : const Size(390, 844))
            : (portrait ? const Size(744, 1133) : const Size(1133, 744));
        final scale = phone && portrait ? 1.5 : 1.0;
        final label =
            '${phone ? 'phone' : '$seats-seat'}-${size.width.toInt()}';
        testWidgets('utility values share their action row in $label', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final f = TableFixture();
          await f.initialize();
          await f.controller.resetGame(keepBoard: false, playerCount: seats);
          final player = f.player;
          player.utilities = [
            UtilityState(
              id: 'squirrel',
              kind: 'the_unbeatable_squirrel_girl',
              name: 'The Unbeatable Squirrel Girl',
              description:
                  'Nontoken Squirrels you control (including Squirrel Girl)',
              value: 1,
              configuration: {
                'hasAction': true,
                'actionType': 'the_unbeatable_squirrel_girl',
                'actionButtonText': 'Make Squirrels · 1GGG',
              },
            ),
            UtilityState(
              id: 'krenko',
              kind: 'krenko_mob_boss',
              name: 'Krenko, Mob Boss',
              description: 'Nontoken goblins you control',
              value: 1,
              configuration: {'hasAction': true},
            ),
            UtilityState(
              id: 'cathars',
              kind: 'cathars_crusade',
              name: "Cathars' Crusade",
              description: 'Pending triggers',
              value: 1,
              configuration: {'hasAction': true},
            ),
            UtilityState(
              id: 'ring',
              kind: 'the_ring',
              name: 'The Ring',
              value: 0,
            ),
          ];
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            f.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: tableTheme(Brightness.dark),
              builder: (context, child) => RepaintBoundary(
                key: captureKey,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
              home: TableScreen(
                controller: f.controller,
                enablePhonePresentation: phone,
                compactPlayerOne: phone,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (!phone) await showAdaptiveUtilities(tester, playerId: player.id);
          for (final utility in player.utilities) {
            final row = find.byKey(ValueKey('swipe-utility-${utility.id}'));
            final surface = find.byKey(ValueKey('${utility.id}-value-surface'));
            await tester.ensureVisible(surface);
            await tester.pumpAndSettle();
            final rowBox = tester.renderObject<RenderBox>(row);
            final surfaceBox = tester.renderObject<RenderBox>(surface);
            final detailsBox = tester.renderObject<RenderBox>(
              find.byKey(ValueKey('utility-details-${utility.id}')),
            );
            final localTop = surfaceBox
                .localToGlobal(Offset.zero, ancestor: rowBox)
                .dy;
            final detailsTop = detailsBox
                .localToGlobal(Offset.zero, ancestor: rowBox)
                .dy;
            expect(
              localTop,
              greaterThanOrEqualTo(detailsTop + detailsBox.size.height),
              reason: 'The value belongs beside actions, never in the header.',
            );
            final actionBox = tester.renderObject<RenderBox>(
              find.byKey(
                ValueKey(
                  utility.kind == 'the_ring'
                      ? 'ring-tempt-${utility.id}'
                      : 'utility-action-${utility.id}',
                ),
              ),
            );
            final actionOrigin = actionBox.localToGlobal(
              Offset.zero,
              ancestor: rowBox,
            );
            final surfaceOrigin = surfaceBox.localToGlobal(
              Offset.zero,
              ancestor: rowBox,
            );
            if (rowBox.size.width - 16 >= 96 + 100 * scale) {
              expect(
                surfaceOrigin.dy + surfaceBox.size.height / 2,
                closeTo(actionOrigin.dy + actionBox.size.height / 2, 0.01),
                reason: '${utility.name} action and value share a row.',
              );
              expect(
                surfaceOrigin.dx,
                greaterThanOrEqualTo(
                  actionOrigin.dx + actionBox.size.width + 6,
                ),
              );
            } else {
              expect(localTop, greaterThanOrEqualTo(actionOrigin.dy));
            }
            expect(surfaceBox.size.height, greaterThanOrEqualTo(44));
            final increase = byControlLabel('Increase ${utility.name}');
            expect(increase.hitTestable(), findsOneWidget);
            final before = f.board.utilityValue(player.id, utility.id);
            await tester.tap(increase);
            await tester.pumpAndSettle();
            expect(f.board.utilityValue(player.id, utility.id), before + 1);
            await f.controller.undo();
            await tester.pumpAndSettle();
            expect(f.board.utilityValue(player.id, utility.id), before);
            expect(tester.takeException(), isNull);
            if (phone && !portrait) {
              await capture(tester, '$label-${utility.id}');
            }
            if (utility.id == 'cathars') {
              await f.board.setUtility(player.id, 'cathars', value: 999999);
              await tester.pumpAndSettle();
              final largeValue = find.byKey(
                const ValueKey('cathars-value-surface'),
              );
              await tester.ensureVisible(largeValue);
              await tester.pumpAndSettle();
              expect(largeValue.hitTestable(), findsOneWidget);
              expect(tester.getSize(largeValue).width, greaterThan(90));
              expect(tester.takeException(), isNull);
              await f.controller.undo();
              await tester.pumpAndSettle();
            }
            if (phone && !portrait && utility.id == 'squirrel') {
              final details = find.byKey(
                const ValueKey('utility-details-squirrel'),
              );
              await tester.ensureVisible(details);
              await tester.pumpAndSettle();
              await tester.tap(details);
              await tester.pumpAndSettle();
              expect(find.text('Make Squirrels'), findsWidgets);
              expect(
                find.text('Make Squirrels · 1GGG'),
                findsNothing,
                reason:
                    'Existing saved utilities use the new detail label too.',
              );
              await tester.tap(byControlLabel('Close workspace'));
              await tester.pumpAndSettle();
            }
          }
          expect(find.text('Make Squirrels · 1GGG'), findsNothing);
          if (!phone) await capture(tester, label);
        });
      }
    }
  }
}

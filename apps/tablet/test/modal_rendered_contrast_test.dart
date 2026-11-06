import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';
import 'support/control_finders.dart';

void main() {
  late Directory temp;
  setUp(() {
    debugDisableShadows = false;
  });
  tearDown(() {
    debugDisableShadows = true;
  });
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('modal-contrast');
    Hive.init(temp.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    // Resolve from the running Flutter test engine, not a developer's SDK path.
    var sdk = Directory(
      Platform.environment['FLUTTER_ROOT'] ??
          File(Platform.resolvedExecutable).parent.path,
    );
    while (!Directory(
          '${sdk.path}/bin/cache/artifacts/material_fonts',
        ).existsSync() &&
        sdk.parent.path != sdk.path) {
      sdk = sdk.parent;
    }
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(
            File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.value}',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  for (final brightness in Brightness.values) {
    for (final (page, embedded) in [
      (WorkspacePage.rules, false),
      (WorkspacePage.utilities, false),
      (WorkspacePage.history, false),
      (WorkspacePage.history, true),
    ]) {
      testWidgets(
        '${brightness.name} ${page.name} rendered ${embedded ? "drawer" : "modal"}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1133, 744);
          addTearDown(tester.view.reset);
          final f = TableFixture();
          await f.initialize();
          f.player.rules.add(
            ModifierSource(
              id: 'custom',
              ownerPlayerId: f.playerId,
              definitionId: 'custom',
              name: 'Saved custom multiplier',
              count: 2,
              enabled: true,
              configuration: {
                'triggerType': 'any_token',
                'outcomes': [
                  {'outcomeType': 'multiply', 'multiplier': 2},
                ],
              },
            ),
          );
          f.catalog.loaded = true;
          addTearDown(f.dispose);
          await f.board.setModifier(f.playerId, 'doubling_season', 2);
          await f.board.addUtility(f.playerId, 'cathars_crusade');
          await f.controller.adjustLife(f.playerId, -3);
          final utility = f.player.utilities.firstWhere(
            (u) => u.kind == 'cathars_crusade',
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: tableTheme(brightness),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('capture'),
                child: child!,
              ),
              home: embedded
                  ? TableScreen(controller: f.controller)
                  : Scaffold(
                      body: Builder(
                        builder: (context) => TextButton(
                          onPressed: () => showTableWorkspace(
                            context,
                            f.controller,
                            catalog: f.catalog,
                            seatId: f.playerId,
                            initialPage: page,
                            itemId: page == WorkspacePage.utilities
                                ? utility.id
                                : null,
                          ),
                          child: const Text('Open'),
                        ),
                      ),
                    ),
            ),
          );
          if (embedded) {
            await tester.tap(
              find.byKey(const ValueKey('central-game-controls')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('History'));
            await tester.pumpAndSettle();
            expect(find.byType(GameDrawerWorkspace), findsOneWidget);
            expect(
              find.byKey(const ValueKey('context-workspace')),
              findsNothing,
            );
            expect(find.text('Life -3'), findsOneWidget);
          } else {
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
          }
          Future<void> inspect(String suffix) async {
            await tester.runAsync(() async {
              final image = await tester
                  .renderObject<RenderRepaintBoundary>(
                    find.byKey(const ValueKey('capture')),
                  )
                  .toImage();
              final raw = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              Color pixel(Offset p) {
                final i = (p.dy.floor() * image.width + p.dx.floor()) * 4;
                return Color.fromARGB(
                  raw.getUint8(i + 3),
                  raw.getUint8(i),
                  raw.getUint8(i + 1),
                  raw.getUint8(i + 2),
                );
              }

              double ratio(Color a, Color b) {
                final x = a.computeLuminance(), y = b.computeLuminance();
                return (math.max(x, y) + .05) / (math.min(x, y) + .05);
              }

              double ink(Rect rect, Color background) {
                var best = 1.0;
                for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
                  for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
                    best = math.max(
                      best,
                      ratio(
                        pixel(Offset(x.toDouble(), y.toDouble())),
                        background,
                      ),
                    );
                  }
                }
                return best;
              }

              final workspace = embedded
                  ? find.byKey(const ValueKey('game-drawer-workspace'))
                  : find.byKey(const ValueKey('context-workspace'));
              final bounds = tester.getRect(workspace).deflate(2);
              for (final element
                  in find
                      .descendant(
                        of: workspace,
                        matching: find.byType(HalfStepper),
                      )
                      .evaluate()) {
                final step = element.widget as HalfStepper;
                final rect = tester.getRect(find.byWidget(step));
                if (rect.top < 52 || rect.bottom > 692) continue;
                final bg = pixel(rect.topLeft + const Offset(3, 3));
                final icons = find.descendant(
                  of: find.byWidget(step),
                  matching: find.byType(Icon),
                );
                for (final icon in icons.evaluate()) {
                  final widget = icon.widget as Icon;
                  if (widget.color!.a < 1) {
                    continue; // The zero decrement is truly disabled.
                  }
                  final measured = ink(
                    tester.getRect(find.byWidget(widget)),
                    bg,
                  );
                  expect(
                    measured,
                    greaterThanOrEqualTo(3),
                    reason: 'Rendered enabled ${step.label} icon',
                  );
                  debugPrint(
                    'PIXEL ${brightness.name} $suffix ${step.label} icon ${measured.toStringAsFixed(2)}',
                  );
                }
                final card = find
                    .ancestor(
                      of: find.byWidget(step),
                      matching: find.byType(Card),
                    )
                    .first;
                final cardRect = tester.getRect(card);
                final boundary = pixel(
                  Offset(cardRect.left + 1, cardRect.center.dy),
                );
                final measured = ratio(boundary, bg);
                expect(
                  measured,
                  greaterThanOrEqualTo(3),
                  reason: 'Rendered ${step.label} card boundary',
                );
                debugPrint(
                  'PIXEL ${brightness.name} $suffix boundary ${measured.toStringAsFixed(2)}',
                );
              }
              var leastText = 100.0;
              var textCount = 0;
              for (final element
                  in find
                      .descendant(of: workspace, matching: find.byType(Text))
                      .evaluate()) {
                final text = element.widget as Text;
                final rect = tester.getRect(find.byWidget(text));
                if (rect.isEmpty ||
                    !bounds.contains(rect.topLeft - const Offset(0, 2)) ||
                    !bounds.contains(rect.bottomRight)) {
                  continue;
                }
                final measured = ink(
                  rect,
                  pixel(rect.topLeft - const Offset(0, 2)),
                );
                expect(
                  measured,
                  greaterThanOrEqualTo(4.5),
                  reason: 'Rendered text: ${text.data}',
                );
                leastText = math.min(leastText, measured);
                textCount++;
              }
              expect(textCount, greaterThan(0));
              if (page == WorkspacePage.history) {
                var separators = 0;
                for (final element
                    in find
                        .descendant(
                          of: workspace,
                          matching: find.byType(DecoratedBox),
                        )
                        .evaluate()) {
                  final box = element.widget as DecoratedBox;
                  final decoration = box.decoration;
                  if (decoration is! BoxDecoration ||
                      decoration.border is! Border) {
                    continue;
                  }
                  final border = decoration.border! as Border;
                  if (border.bottom.width <= 0 ||
                      border.bottom.style == BorderStyle.none) {
                    continue;
                  }
                  final rect = tester.getRect(find.byWidget(box));
                  if (!bounds.contains(rect.bottomCenter)) continue;
                  final bg = pixel(rect.bottomCenter - const Offset(0, 4));
                  final measured = ink(
                    Rect.fromLTWH(rect.center.dx - 2, rect.bottom - 2, 4, 2),
                    bg,
                  );
                  expect(
                    measured,
                    greaterThanOrEqualTo(3),
                    reason: 'Rendered history separator',
                  );
                  debugPrint(
                    'PIXEL ${brightness.name} $suffix separator ${measured.toStringAsFixed(2)}',
                  );
                  separators++;
                }
                expect(separators, greaterThan(0));
              }
              debugPrint(
                'PIXEL ${brightness.name} $suffix minimum text ${leastText.toStringAsFixed(2)}',
              );
              final out = Platform.environment['TABLET_CAPTURE_DIR'];
              if (out != null) {
                await Directory(out).create(recursive: true);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$out/${brightness.name}-$suffix.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              }
              image.dispose();
            });
          }

          await inspect(embedded ? 'embedded-history' : page.name);
          if (embedded) {
            await tester.tap(find.text('Undo latest'));
            await tester.pumpAndSettle();
            expect(find.text('Undone · Life -3'), findsOneWidget);
            await inspect('embedded-history-undone');
          }
          if (page == WorkspacePage.rules) {
            await tester.ensureVisible(find.text('Saved custom multiplier'));
            await tester.pumpAndSettle();
            await inspect('custom-rules');
          }
          expect(tester.takeException(), isNull);
          await tester.tap(
            embedded
                ? find.byKey(ValueKey('${f.playerId}-dismiss-drawer'))
                : byControlLabel('Close workspace'),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
          debugDisableShadows = true;
        },
      );
    }
  }
}

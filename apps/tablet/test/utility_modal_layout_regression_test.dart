import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

// Optional captures are Flutter test renderer evidence, not native acceptance.
final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('utility-capture');

void main() {
  setUpAll(() async {
    if (_captureDirectory == null) return;
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
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$_captureDirectory/flutter-test-renderer-utility-$name.png',
        ).writeAsBytes(png.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<void> reachable(
    WidgetTester tester,
    Finder target, {
    String? reason,
  }) async {
    expect(target, findsOneWidget, reason: reason);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget, reason: reason);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reachable(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> showUtility(
    WidgetTester tester,
    TableFixture fixture,
    UtilityState utility,
    Size size, {
    int quarterTurns = 0,
    VoidCallback? onBackgroundTap,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    addTearDown(() async {
      if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
        await tap(tester, find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
    fixture.catalog.loaded = true;
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
                    onBackgroundTap?.call();
                    showTableWorkspace(
                      context,
                      fixture.controller,
                      catalog: fixture.catalog,
                      seatId: fixture.playerId,
                      initialPage: WorkspacePage.utilities,
                      itemId: utility.id,
                      quarterTurns: quarterTurns,
                    );
                  },
                  child: const Text('Open utility'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Open utility'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('context-workspace'))),
      TableModalFrame.localSize(
        Size(size.width, size.height - 44),
        quarterTurns,
      ),
    );
  }

  Future<void> closeUtility(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'every utility exposes reachable options inside the bounded responsive shell at $size',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        addTearDown(fixture.dispose);
        // Exercise the actual catalog, including each special action's controls.
        final definitions = fixture.board.utilityDefinitions;
        for (final definition in definitions) {
          await fixture.board.addUtility(fixture.playerId, definition.id);
        }
        await fixture.board.createCustomUtility(
          fixture.playerId,
          name: 'Custom tracker',
        );
        await fixture.board.createCustomUtility(
          fixture.playerId,
          name: 'Custom toggle',
          toggle: true,
        );
        final ids = fixture.player.utilities.map((u) => u.id).toList();
        for (final id in ids) {
          final utility = fixture.player.utilities.firstWhere(
            (u) => u.id == id,
          );
          utility.artworkUrl = null;
          utility.configuration['artworkOptions'] = [];
          await showUtility(tester, fixture, utility, size);
          final detail = find.byKey(ValueKey('utility-detail-${utility.kind}'));
          expect(detail, findsOneWidget, reason: utility.kind);
          expect(
            tester.getSize(find.byKey(const ValueKey('context-workspace'))),
            TableModalFrame.localSize(Size(size.width, size.height - 44), 0),
          );
          for (final label in ['Name', 'Description']) {
            await reachable(
              tester,
              find.byWidgetPredicate(
                (w) => w is TextField && w.decoration?.labelText == label,
              ),
              reason: utility.kind,
            );
          }
          for (final label in ['All utilities', 'Artwork']) {
            await reachable(
              tester,
              find.text(label),
              reason: '${utility.kind}: $label',
            );
          }
          await reachable(
            tester,
            find.byTooltip('Remove this utility'),
            reason: utility.kind,
          );
          expect(find.byType(ExpansionTile), findsNothing);
          if (utility.kind == 'mana_pool') {
            for (final color in PlayerState.manaColors) {
              final card = find.byKey(ValueKey('utility-mana-$color'));
              for (final control
                  in tester
                      .widgetList<Tooltip>(
                        find.descendant(
                          of: card,
                          matching: find.byType(Tooltip),
                        ),
                      )
                      .toList()) {
                await reachable(tester, find.byTooltip(control.message!));
              }
            }
            await reachable(tester, find.text('Empty unlocked mana'));
          } else if (utility.configuration['type'] == 'toggle') {
            await reachable(tester, find.byType(SwitchListTile));
          } else if (utility.configuration['actionOnly'] != true) {
            await reachable(tester, find.byTooltip('Increase Value'));
            await reachable(tester, find.byTooltip('Decrease Value'));
            await reachable(
              tester,
              find.widgetWithText(OutlinedButton, 'Set value'),
            );
          }
          if (utility.configuration['hasAction'] == true) {
            final label = utility.kind == 'brudiclad_telchor_engineer'
                ? 'Create Myr & skip transformation'
                : utility.configuration['actionButtonText'] as String;
            await reachable(tester, find.text(label), reason: utility.kind);
            if (utility.kind == 'cathars_crusade') {
              await reachable(tester, find.text('Quick +1/+1 to creatures'));
            }
          }
          expect(tester.takeException(), isNull, reason: utility.kind);
          if ({
            'mana_pool',
            'storm_count',
            'cathars_crusade',
          }.contains(utility.kind)) {
            await capture(
              tester,
              '${utility.kind}-${size.width.toInt()}x${size.height.toInt()}',
            );
          }
          await closeUtility(tester);
        }
        expect(
          definitions.map((d) => d.id),
          containsAll([
            'mana_pool',
            'storm_count',
            'krenko_mob_boss',
            'krenko_tin_street',
            'cathars_crusade',
            'academy_manufactor',
            'rhys_the_redeemed',
            'hare_apparent',
            'brudiclad_telchor_engineer',
          ]),
        );
      },
    );
  }

  testWidgets(
    'compact mana actions preserve locks, conversion, and seat scope',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final utility = fixture.player.utilities.firstWhere(
        (u) => u.kind == 'mana_pool',
      );
      final otherSeat = fixture.controller.session.players[1].toJson();
      await showUtility(tester, fixture, utility, const Size(1133, 744));
      await tap(tester, find.byTooltip('Increase White mana'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byTooltip('Increase White mana'));
      await tester.pumpAndSettle();
      expect(fixture.player.mana['W'], 11);
      await tap(tester, find.byTooltip('Lock White mana for Empty'));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Increase Blue mana'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Empty unlocked mana'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Empty unlocked mana'),
      );
      await tester.pumpAndSettle();
      expect(fixture.player.mana['W'], 11);
      expect(fixture.player.mana['U'], 0);
      await tap(tester, find.byTooltip('Convert all mana to Blue'));
      await tester.pumpAndSettle();
      expect(fixture.player.mana['W'], 0);
      expect(fixture.player.mana['U'], 11);
      expect(fixture.player.manaLocks, contains('W'));
      expect(fixture.controller.session.players[1].toJson(), otherSeat);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await closeUtility(tester);
    },
  );

  testWidgets(
    'utility art has a separate scroll area and tapaway consumes input',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final utility = fixture.player.utilities.firstWhere(
        (u) => u.kind == 'storm_count',
      );
      var backgroundTaps = 0;
      await showUtility(
        tester,
        fixture,
        utility,
        const Size(744, 1133),
        onBackgroundTap: () => backgroundTaps++,
      );
      await tap(tester, find.text('Artwork'));
      await tester.pumpAndSettle();
      expect(find.text('Upload utility artwork').hitTestable(), findsOneWidget);
      expect(find.text('Utility controls').hitTestable(), findsOneWidget);
      await tap(tester, find.text('Utility controls'));
      await tester.pumpAndSettle();
      expect(
        find
            .byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == 'Name',
            )
            .hitTestable(),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 500));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close workspace'), findsNothing);
      expect(backgroundTaps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'utility properties commit before artwork navigation and toggle stays scoped',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await fixture.board.createCustomUtility(
        fixture.playerId,
        name: 'Custom blessing',
        toggle: true,
      );
      final utility = fixture.player.utilities.firstWhere(
        (u) => u.kind == 'custom_toggle',
      );
      utility.artworkUrl = null;
      utility.configuration['artworkOptions'] = [];
      final otherSeat = fixture.controller.session.players[1].toJson();
      await showUtility(tester, fixture, utility, const Size(744, 1133));
      await tap(tester, find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        fixture.player.utilities.firstWhere((u) => u.id == utility.id).isActive,
        isTrue,
      );
      expect(fixture.player.citysBlessing, isFalse);
      for (final entry in {
        'Name': 'Ascended',
        'Description': 'Saved utility description',
      }.entries) {
        final field = tester.widget<TextField>(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == entry.key,
          ),
        );
        field.controller!.text = entry.value;
      }
      await tester.pump();
      await tap(tester, find.text('Artwork'));
      await tester.pumpAndSettle();
      final saved = fixture.player.utilities.firstWhere(
        (u) => u.id == utility.id,
      );
      expect(saved.name, 'Ascended');
      expect(saved.description, 'Saved utility description');
      expect(fixture.controller.session.players[1].toJson(), otherSeat);
      expect(tester.takeException(), isNull);
      await closeUtility(tester);
    },
  );

  testWidgets(
    'large action previews and transformation lists scroll independently',
    (tester) async {
      final fixture = TableFixture(
        stateWithTokens([
          for (var i = 0; i < 40; i++)
            sampleToken(id: 'token-$i', name: 'Creature $i'),
        ]),
      );
      await fixture.initialize();
      addTearDown(fixture.dispose);
      for (final kind in ['rhys_the_redeemed', 'brudiclad_telchor_engineer']) {
        await fixture.board.addUtility(fixture.playerId, kind);
        final utility = fixture.player.utilities.firstWhere(
          (u) => u.kind == kind,
        );
        utility.artworkUrl = null;
        utility.configuration['artworkOptions'] = [];
        await showUtility(tester, fixture, utility, const Size(1133, 744));
        if (kind == 'rhys_the_redeemed') {
          final fixed = find.byKey(const ValueKey('utility-fixed-controls'));
          final outer = tester.state<ScrollableState>(
            find.descendant(of: fixed, matching: find.byType(Scrollable)).first,
          );
          expect(outer.position.viewportDimension, inInclusiveRange(44, 640));
          final preview = find.byKey(const ValueKey('utility-action-preview'));
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(of: preview, matching: find.byType(Scrollable))
                .first,
          );
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          await reachable(
            tester,
            find.text(utility.configuration['actionButtonText'] as String),
          );
        } else {
          final targets = find.byKey(
            const ValueKey('utility-transform-targets'),
          );
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(of: targets, matching: find.byType(Scrollable))
                .first,
          );
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          await reachable(
            tester,
            find.text('Create Myr & skip transformation'),
          );
        }
        await reachable(tester, find.text('Artwork'));
        expect(tester.takeException(), isNull);
        await closeUtility(tester);
      }
    },
  );
}

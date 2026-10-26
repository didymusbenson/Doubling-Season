import 'package:doubling_season/widgets/mana/mana_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';

import 'support/table_fixture.dart';

const _scuteAbilities =
    'Landfall — Whenever a land you control enters, create a 1/1 green '
    'Insect creature token. If you control six or more lands, create a '
    'token that’s a copy of Scute Swarm instead.';
const _manaAbilities =
    '{T}: Add {G}. {2}{G}: Create a 1/1 green Saproling creature token. '
    'Whenever another creature enters under your control, you gain 1 life. '
    'This final sentence must remain reachable when the token is expanded.';
// Local image bytes keep artwork geometry tests independent of the network.
const _art =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
  });

  Future<void Function(bool)> showCard(
    WidgetTester tester,
    TableFixture fixture, {
    double width = 260,
    double textScale = 1,
    int turns = 0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await fixture.initialize();
    var expanded = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: RotatedBox(
                quarterTurns: turns,
                child: SizedBox(
                  width: width,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      return ListenableBuilder(
                        listenable: fixture.controller,
                        builder: (context, _) => TabletTokenCard(
                          token: fixture.token('source'),
                          player: fixture.player,
                          board: fixture.board,
                          playerName: 'Player 1',
                          quarterTurns: turns,
                          expanded: expanded,
                          onExpand: () => setState(() => expanded = !expanded),
                          onOpenDetailed: (_) {},
                          onInputLock: (_) {},
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
    return (value) => rebuild(() => expanded = value);
  }

  Finder description(String text) => find.byWidgetPredicate(
    (widget) => widget is ManaText && widget.text == text,
  );

  for (final turns in [0, 1, 2, 3]) {
    for (final scale in [1.0, 1.6]) {
      for (final abilities in [_scuteAbilities, _manaAbilities]) {
        testWidgets(
          'collapsed abilities reserve complete ellipsis lines '
          '(turns $turns, scale $scale, mana ${abilities == _manaAbilities})',
          (tester) async {
            final fixture = TableFixture(
              stateWithTokens([
                sampleToken(
                  name: 'Scute Swarm',
                  abilities: abilities,
                  pt: abilities == _manaAbilities ? '123456/123456' : '1/1',
                ),
              ]),
            );
            await showCard(tester, fixture, turns: turns, textScale: scale);
            final text = description(abilities);
            final mana = tester.widget<ManaText>(text);
            expect(mana.maxLines, 3);
            expect(mana.overflow, TextOverflow.ellipsis);
            // The old fixed 48px non-scrollable viewport clipped line three.
            // Collapsed abilities must not be inside any text scroll viewport.
            expect(
              find.ancestor(
                of: text,
                matching: find.byType(SingleChildScrollView),
              ),
              findsNothing,
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)).first,
            );
            expect(paragraph.didExceedMaxLines, isTrue);
            final visibleText = tester.getRect(text);
            final card = tester.getRect(find.byType(TabletTokenCard));
            expect(card.contains(visibleText.topLeft), isTrue);
            expect(
              card.contains(visibleText.bottomRight - const Offset(.1, .1)),
              isTrue,
            );
            if (scale > 1) {
              // The larger text is allowed to exceed the old pixel budget.
              expect(paragraph.size.height, greaterThan(42));
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('expanded long abilities remain fully scrollable', (
    tester,
  ) async {
    final fixture = TableFixture(
      stateWithTokens([
        sampleToken(abilities: '$_scuteAbilities $_manaAbilities'),
      ]),
    );
    final expand = await showCard(tester, fixture, width: 220);
    expand(true);
    await tester.pumpAndSettle();
    final text = description('$_scuteAbilities $_manaAbilities');
    expect(tester.widget<ManaText>(text).maxLines, isNull);
    final scroll = find.ancestor(
      of: text,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    expect(scrollable.position.extentAfter, 0);
    expect(tester.takeException(), isNull);
  });

  for (final turns in [0, 1, 2, 3]) {
    testWidgets('art preference survives expansion and edits (turns $turns)', (
      tester,
    ) async {
      final token = sampleToken(artworkUrl: _art, abilities: _scuteAbilities);
      token.extra['artworkDisplayStyle'] = 'fadeout';
      final fixture = TableFixture(stateWithTokens([token]));
      final expand = await showCard(tester, fixture, turns: turns);
      final surface = find.byType(TableArtworkSurface);
      Finder fade() =>
          find.descendant(of: surface, matching: find.byType(ShaderMask));
      expect(fade(), findsOneWidget);
      expand(true);
      await tester.pumpAndSettle();
      expect(fade(), findsOneWidget);
      await fixture.board.setArtworkStyle(fixture.playerId, 'source', 'full');
      await tester.pumpAndSettle();
      expect(fade(), findsNothing);
      await fixture.board.setArtworkStyle(
        fixture.playerId,
        'source',
        'fadeout',
      );
      await tester.pumpAndSettle();
      expect(fade(), findsOneWidget);
      expand(false);
      await tester.pumpAndSettle();
      expect(fade(), findsOneWidget);
      final reloaded = await fixture.repository.open();
      expect(
        reloaded
            .state
            .session
            .players
            .first
            .tokens
            .first
            .extra['artworkDisplayStyle'],
        'fadeout',
      );
      expect(tester.takeException(), isNull);
    });
  }
}

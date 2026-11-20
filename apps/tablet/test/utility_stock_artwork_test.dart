import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

const portalStormCrow =
    'https://cards.scryfall.io/art/front/d/f/dfe87b59-b456-4532-a695-0dea3110d878.webp?1783946835';
const alphaBlackLotus =
    'https://cards.scryfall.io/art/front/b/0/b0faa7f2-b547-42c4-a810-839da50dadfe.webp?1783948669';
const priorStormDefault =
    'https://cards.scryfall.io/large/front/e/c/ec17fa3c-9033-4eab-a236-3f0068595536.jpg?1674097527';
const customArt = 'https://example.test/own-art.webp';

void main() {
  for (final (kind, url, set, artist) in [
    ('storm_count', portalStormCrow, 'POR', 'Una Fricker'),
    ('mana_pool', alphaBlackLotus, 'LEA', 'Christopher Rush'),
  ]) {
    test(
      '$kind has the exact stock art with credit on all new paths',
      () async {
        final f = TableFixture();
        await f.initialize();
        addTearDown(f.dispose);
        UtilityState current() =>
            f.player.utilities.singleWhere((u) => u.kind == kind);
        final definition = f.board.utilityDefinitions.singleWhere(
          (d) => d.id == kind,
        );
        expect(definition.artwork.first.url, url);
        expect(definition.artwork.first.set, set);
        expect(definition.artwork.first.artist, artist);
        expect(current().displayedArtworkUrl, url);
        expect(current().artworkUrl, url);

        await f.board.removeUtility(f.playerId, current().id);
        await f.board.addUtility(f.playerId, kind);
        expect(current().displayedArtworkUrl, url);
        expect((current().configuration['artworkOptions'] as List).first, {
          'url': url,
          'set': set,
          'artist': artist,
        });
      },
    );

    test(
      '$kind fills old blank defaults but keeps prior custom/clear choices',
      () async {
        final state = TabletState.initial();
        final base = state.session.players.first.utilities.singleWhere(
          (u) => u.kind == kind,
        )..artworkUrl = null;
        final oldSnapshot = jsonEncode(base.toJson());
        expect(base.displayedArtworkUrl, url);
        expect(jsonEncode(base.toJson()), oldSnapshot);
        expect(
          (base.copy()..artworkUrl = customArt).displayedArtworkUrl,
          customArt,
        );
        expect(
          (base.copy()
                ..configuration['artworkOptions'] = [
                  {'url': customArt},
                ])
              .displayedArtworkUrl,
          isNull,
        );
        expect(
          (base.copy()..configuration['legacyInteractionVersion'] = 1)
              .displayedArtworkUrl,
          isNull,
        );

        final f = TableFixture(state);
        await f.initialize();
        addTearDown(f.dispose);
        UtilityState current() =>
            f.player.utilities.singleWhere((u) => u.kind == kind);
        expect(current().displayedArtworkUrl, url);
        await f.board.setUtility(f.playerId, current().id, clearArtwork: true);
        expect(current().displayedArtworkUrl, isNull);
        expect(current().copy().displayedArtworkUrl, isNull);
        await f.board.setUtility(
          f.playerId,
          current().id,
          artworkUrl: customArt,
        );
        expect(current().displayedArtworkUrl, customArt);
        await f.controller.resetGame(keepBoard: true);
        expect(current().displayedArtworkUrl, customArt);
        await f.board.setUtility(f.playerId, current().id, clearArtwork: true);
        expect(current().displayedArtworkUrl, isNull);
        await f.controller.resetGame(keepBoard: true);
        expect(current().displayedArtworkUrl, isNull);
        await f.controller.resetGame(keepBoard: false);
        expect(current().displayedArtworkUrl, url);
      },
    );
  }

  test('only the exact retired tablet Storm art aliases Portal', () {
    final utility = UtilityState(
      id: 'storm',
      kind: 'storm_count',
      artworkUrl: priorStormDefault,
    );
    expect(utility.displayedArtworkUrl, portalStormCrow);
    expect(utility.artworkUrl, priorStormDefault);
    expect(
      (utility.copy()..artworkUrl = '$priorStormDefault&custom=1')
          .displayedArtworkUrl,
      '$priorStormDefault&custom=1',
    );
    expect(
      (utility.copy()..configuration['legacyInteractionVersion'] = 1)
          .displayedArtworkUrl,
      priorStormDefault,
    );
  });

  testWidgets('past Storm save shows Portal credit and a removable default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    final storm = state.session.players.first.utilities.first
      ..artworkUrl = null;
    final f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
    addTearDown(f.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                f.controller,
                catalog: f.catalog,
                seatId: f.playerId,
                initialPage: WorkspacePage.utilities,
                itemId: storm.id,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Una Fricker'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is TableArtwork && w.url == portalStormCrow,
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const ValueKey('utility-edit-artwork')));
    await tester.pumpAndSettle();
    expect(find.text('Current artwork'), findsOneWidget);
    final remove = find.text('Remove artwork');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Current artwork'), findsNothing);
    expect(find.text('POR'), findsOneWidget);
    expect(
      f.player.utilities
          .singleWhere((u) => u.id == storm.id)
          .displayedArtworkUrl,
      isNull,
    );
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

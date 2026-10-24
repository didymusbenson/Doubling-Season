import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'support/table_fixture.dart';

void main() {
  for (final failure in [false, true]) {
    testWidgets(
      'swipe deletes durably without confirmation, failure=$failure',
      (tester) async {
        final fixture = TableFixture(stateWithTokens([sampleToken()]));
        await fixture.initialize();
        fixture.repository.failSave = failure;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          fixture.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: fixture.controller,
                builder: (_, _) => fixture.player.tokens.isEmpty
                    ? const SizedBox()
                    : SizedBox(
                        width: 320,
                        child: TabletTokenCard(
                          token: fixture.token('source'),
                          player: fixture.player,
                          board: fixture.board,
                          playerName: 'Player 1',
                          quarterTurns: 0,
                          expanded: false,
                          onExpand: () {},
                          onOpenDetailed: (_) {},
                          onInputLock: (_) {},
                        ),
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(fixture.player.tokens.length, failure ? 1 : 0);
        if (!failure) {
          await fixture.controller.undo();
          await tester.pumpAndSettle();
          expect(fixture.token('source').amount, 3);
        } else {
          expect(
            find.textContaining('Simulated storage failure'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'token surface opts out of shared artwork scrim without changing default',
    (tester) async {
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        fixture.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: TabletTokenCard(
                token: fixture.token('source'),
                player: fixture.player,
                board: fixture.board,
                playerName: 'Player 1',
                quarterTurns: 0,
                expanded: false,
                onExpand: () {},
                onOpenDetailed: (_) {},
                onInputLock: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<TableArtworkSurface>(find.byType(TableArtworkSurface))
            .shadeArtwork,
        isFalse,
      );
      expect(
        const TableArtworkSurface(url: null, child: SizedBox()).shadeArtwork,
        isTrue,
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_artwork.dart';
import 'package:tripling_table/ui/token_board_summary.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

const _pixel =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
const _invalidImage = 'data:image/png;base64,bm90IGFuIGltYWdl';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectSummaryValue(String label, String value) {
    final row = find
        .ancestor(of: find.text(label), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: row, matching: find.text(value)),
      findsOneWidget,
    );
  }

  Future<void> openWorkspace(
    WidgetTester tester,
    TableFixture fixture,
    WorkspacePage page,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fixture.catalog.loaded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                fixture.controller,
                catalog: fixture.catalog,
                seatId: fixture.playerId,
                initialPage: page,
                itemId: 'source',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> closeWorkspace(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets(
    'summary includes independent power counters and keeps variable power explicit',
    (tester) async {
      final state = stateWithTokens([
        sampleToken(
          pt: '2/3',
          amount: 3,
          tapped: 1,
          plusOne: 1,
          counters: {'+1/+0': 2, '+0/+1': 50},
        ),
        sampleToken(
          id: 'negative',
          pt: '-1/2',
          amount: 2,
          tapped: 2,
          minusOne: 2,
        ),
        sampleToken(
          id: 'variable',
          name: 'Elemental',
          pt: '*/*',
          amount: 4,
          counters: {'+1/+0': 7},
        ),
        sampleToken(
          id: 'treasure',
          name: 'Treasure',
          pt: '',
          type: 'Artifact — Treasure',
          amount: 5,
          sick: 0,
        ),
        sampleToken(id: 'zero', amount: 0, tapped: 0, sick: 0, plusOne: 100),
        sampleToken(
          id: 'emblem',
          name: 'Emblem',
          pt: '',
          type: 'Emblem',
          amount: 99,
          tapped: 0,
          sick: 0,
        ),
      ]);
      state.session.players[1].tokens.add(sampleToken(amount: 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TokenBoardSummary(player: state.session.players.first),
            ),
          ),
        ),
      );
      expectSummaryValue('Tokens', '14');
      expectSummaryValue('Creatures', '9');
      expectSummaryValue('Known total power', '9'); // 3×(2+1+2) + 2×(-1-2).
      expectSummaryValue('Known untapped power', '10');
      expectSummaryValue('Artifacts', '5');
      expect(
        find.text('Variable power — excluded from known power totals'),
        findsOneWidget,
      );
      expect(find.text('4 × Elemental (*/*)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'image validation rejects malformed data and unsupported URLs',
    () async {
      expect(await TableArtwork.validatedBytes(_pixel), isNotEmpty);
      await expectLater(
        TableArtwork.validatedBytes(_invalidImage),
        throwsException,
      );
      await expectLater(
        TableArtwork.validatedBytes('file:///not-allowed.png'),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'failed artwork selection preserves the current image and saved metadata',
    (tester) async {
      final token = sampleToken(artworkUrl: _pixel);
      token.artworkOptions.add({
        'url': _invalidImage,
        'set': 'INVALID',
        'artist': 'Bad image',
      });
      final f = TableFixture(stateWithTokens([token]));
      await f.initialize();
      addTearDown(f.dispose);
      final before = f.token('source').toJson();
      final saved = f.repository.encoded;
      await openWorkspace(
        tester,
        f,
        WorkspacePage.tokenArtwork,
        const Size(1133, 744),
      );
      final invalid = find.text('INVALID\nBad image');
      await tester.ensureVisible(invalid);
      await tester.tap(invalid);
      await tester.pumpAndSettle();
      expect(find.text('Use this artwork'), findsNothing);
      expect(find.text('Current artwork'), findsOneWidget);
      expect(f.token('source').toJson(), before);
      expect(f.repository.encoded, saved);
      expect(tester.takeException(), isNull);
      await closeWorkspace(tester);
    },
  );

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'artwork variants and summary remain scrollable at ${size.width}x${size.height}',
      (tester) async {
        final source = sampleToken(artworkUrl: _pixel);
        source.artworkOptions = [
          for (var i = 0; i < 24; i++)
            {'url': _pixel, 'set': 'SET $i', 'artist': 'Artist $i'},
        ];
        final f = TableFixture(
          stateWithTokens([
            source,
            for (var i = 0; i < 24; i++)
              sampleToken(id: 'variable-$i', name: 'Variable $i', pt: '*/*'),
          ]),
        );
        await f.initialize();
        addTearDown(f.dispose);
        await openWorkspace(tester, f, WorkspacePage.tokenArtwork, size);
        final lastArt = find.text('SET 23\nArtist 23');
        await tester.ensureVisible(lastArt);
        await tester.pumpAndSettle();
        expect(lastArt.hitTestable(), findsOneWidget);
        final preview = find.text('Preview image URL');
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        expect(preview.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeWorkspace(tester);
        await openWorkspace(tester, f, WorkspacePage.tokenSummary, size);
        final lastVariable = find.text('3 × Variable 23 (*/*)');
        await tester.ensureVisible(lastVariable);
        await tester.pumpAndSettle();
        expect(lastVariable.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeWorkspace(tester);
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

const art =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  testWidgets(
    'utility artwork stages credit and retains candidate on failed Apply',
    (tester) async {
      final state = TabletState.initial();
      final utility = state.session.players.first.utilities.firstWhere(
        (u) => u.kind == 'storm_count',
      );
      utility.configuration['artworkOptions'] = [
        {'url': art, 'set': 'TEST', 'artist': 'Credited Artist'},
      ];
      final fixture = TableFixture(state);
      await fixture.initialize();
      addTearDown(fixture.dispose);
      fixture.catalog.loaded = true;
      tester.view.physicalSize = const Size(1133, 744);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
                  initialPage: WorkspacePage.utilities,
                  itemId: utility.id,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Credited Artist'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Preview — not saved'), findsOneWidget);
      expect(
        fixture.player.utilities
            .firstWhere((u) => u.id == utility.id)
            .artworkUrl,
        isNull,
      );
      fixture.repository.failSave = true;
      await tester.ensureVisible(find.text('Use this artwork'));
      await tester.tap(find.text('Use this artwork'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        fixture.player.utilities
            .firstWhere((u) => u.id == utility.id)
            .artworkUrl,
        isNull,
      );
      expect(find.text('Use this artwork'), findsOneWidget);
      fixture.repository.failSave = false;
      await tester.ensureVisible(find.text('Use this artwork'));
      await tester.tap(find.text('Use this artwork'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      final saved = fixture.player.utilities.firstWhere(
        (u) => u.id == utility.id,
      );
      expect(saved.artworkUrl, art);
      expect(
        (saved.configuration['artworkOptions'] as List).single['artist'],
        'Credited Artist',
      );
      final restored = TabletState.fromJson(
        jsonMap(jsonDecode(fixture.repository.encoded)),
      );
      expect(
        restored.session.players.first.utilities
            .firstWhere((u) => u.id == utility.id)
            .artworkUrl,
        art,
      );
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

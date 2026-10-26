import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  for (final entry in [
    (
      WorkspacePage.tokens,
      'Add tokens',
      'Search tokens, abilities, type, or P/T',
    ),
    (WorkspacePage.tokenArtwork, 'Token artwork', 'Artwork image URL'),
  ]) {
    testWidgets('${entry.$2} route does not absorb first field action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1133, 744);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      final fixture = TableFixture();
      await fixture.initialize();
      fixture.catalog.loaded = true;
      await fixture.controller.updateState('Test token', (state) {
        state.session.players.first.tokens.add(sampleToken());
      });
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  fixture.controller,
                  catalog: fixture.catalog,
                  seatId: fixture.player.seatId,
                  initialPage: entry.$1,
                  itemId: entry.$1 == WorkspacePage.tokenArtwork
                      ? 'source'
                      : null,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (widget) => widget is PlayerField && widget.label == entry.$3,
      );
      expect(field, findsOneWidget);
      final fieldNode = tester.getSemantics(field);
      expect(fieldNode.getSemanticsData().label, startsWith(entry.$3));
      expect(
        fieldNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(fieldNode.rect.size, tester.getSize(field));
      expect(fieldNode.rect.height, lessThan(100));
      var root = fieldNode;
      while (root.parent != null) {
        root = root.parent!;
      }
      final routeNodes = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().label == entry.$2) routeNodes.add(node);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(root);
      expect(routeNodes, hasLength(1));
      expect(
        routeNodes.single.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(routeNodes.single.id, isNot(fieldNode.id));
      fieldNode.owner!.performAction(fieldNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('q'), findsOneWidget);
      await tester.tap(find.text('q'));
      await tester.pumpAndSettle();
      expect(tester.widget<PlayerField>(field).controller.text, 'q');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    });
  }
}

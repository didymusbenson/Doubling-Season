import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> viewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> workspace(
    WidgetTester tester,
    TableFixture fixture,
    WorkspacePage page,
  ) async {
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
                initialPage: page,
              ),
              child: const Text('Open workspace'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open workspace'));
    await tester.pumpAndSettle();
  }

  testWidgets('successful reset returns to board without stale workspace', (
    tester,
  ) async {
    await viewport(tester);
    final f = TableFixture(stateWithTokens([sampleToken()]));
    await f.initialize();
    addTearDown(f.dispose);
    final original = f.controller.session.id;
    await workspace(tester, f, WorkspacePage.reset);
    await tester.tap(find.text('Reset with current configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive & reset with board'));
    await tester.pumpAndSettle();
    expect(f.controller.session.id, isNot(original));
    expect(find.text('Start a new game'), findsNothing);
    expect(find.textContaining('This game has changed'), findsNothing);
    expect(find.text('Open workspace').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed reset keeps confirmation and original board recoverable',
    (tester) async {
      await viewport(tester);
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      final original = f.controller.session.id;
      await workspace(tester, f, WorkspacePage.reset);
      await tester.tap(find.text('Reset with current configuration'));
      await tester.pumpAndSettle();
      f.repository.failSave = true;
      await tester.tap(find.text('Archive & reset with board'));
      await tester.pumpAndSettle();
      expect(f.controller.session.id, original);
      expect(find.text('Archive & reset with board'), findsOneWidget);
      expect(find.textContaining('Simulated storage failure'), findsOneWidget);
      expect(find.text('Open workspace').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('successful restore dismisses and preserves outgoing archive', (
    tester,
  ) async {
    await viewport(tester);
    final f = TableFixture();
    await f.initialize();
    addTearDown(f.dispose);
    final original = f.controller.session.id;
    await f.controller.resetGame(keepBoard: false, playerCount: 2);
    final outgoing = f.controller.session.id;
    await workspace(tester, f, WorkspacePage.reset);
    final archive = find.text('Before complete reset');
    await tester.ensureVisible(archive);
    await tester.tap(archive);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save current & restore'));
    await tester.pumpAndSettle();
    expect(f.controller.session.id, original);
    expect(f.controller.state.archives.last.session.id, outgoing);
    expect(find.textContaining('This game has changed'), findsNothing);
    expect(find.text('Open workspace').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history shows table origin and affected player separately', (
    tester,
  ) async {
    await viewport(tester);
    final f = TableFixture(stateWithTokens([sampleToken()]));
    await f.initialize();
    addTearDown(f.dispose);
    await f.board.bulk(f.playerId, 'wipe_creatures', gameOrigin: true);
    await workspace(tester, f, WorkspacePage.history);
    expect(find.textContaining('Affected: Player 1'), findsOneWidget);
    expect(find.textContaining('Table ·'), findsOneWidget);
    expect(find.textContaining('wipe_creatures'), findsNothing);
    await tester.tap(find.byTooltip('Close workspace'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'multiline custom keyboard Return inserts newline and Done commits once',
    (tester) async {
      await viewport(tester);
      var draft = 'First';
      final commits = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPlayerKeyboardEditor(
                  context,
                  title: 'Abilities',
                  value: draft,
                  multiline: true,
                  onChanged: (value) => draft = value,
                  onCommit: (value) async => commits.add(value),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(draft, 'First\na');
      expect(commits, isEmpty);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(commits, ['First\na']);
      expect(find.text('Edit').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final turns in [0, 2]) {
    testWidgets(
      'keyboard tapaway commits and consumes table tap at rotation $turns',
      (tester) async {
        await viewport(tester);
        var behindTaps = 0, commits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Stack(
                  children: [
                    Positioned(
                      left: 40,
                      top: 340,
                      child: TextButton(
                        key: const Key('behind'),
                        onPressed: () => behindTaps++,
                        child: const Text('Behind'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showPlayerKeyboardEditor(
                        context,
                        title: 'Name',
                        value: 'Saproling',
                        quarterTurns: turns,
                        onChanged: (_) {},
                        onCommit: (_) async => commits++,
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final behind = tester.getCenter(find.byKey(const Key('behind')));
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(find.byType(PlayerKeyboardHost), findsOneWidget);
        await tester.tapAt(behind);
        await tester.pumpAndSettle();
        expect(commits, 1);
        expect(behindTaps, 0);
        expect(find.text('Edit').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed inline save keeps draft and allows retry', (
    tester,
  ) async {
    await viewport(tester);
    var attempts = 0;
    var draft = 'Saproling';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlayerKeyboardEditor(
                context,
                title: 'Name',
                value: draft,
                onChanged: (value) => draft = value,
                onCommit: (_) async {
                  attempts++;
                  if (attempts == 1) throw StateError('Simulated write error');
                },
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(draft, 'Saprolinga');
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Edit').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

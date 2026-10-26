import 'dart:async';
import 'package:doubling_season/widgets/artwork_credit_caption.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/artwork_credit.dart';
import 'package:tripling_table/ui/artwork_selection.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'support/table_fixture.dart';

void main() {
  test('credit preserves artists and distinguishes source from artist', () {
    expect(tabletArtworkArtist('tablet-art:abc', ''), 'user uploaded');
    expect(
      tabletArtworkArtist('https://example.test/a.png', 'Custom URL'),
      'Artist unknown',
    );
    expect(
      tabletArtworkArtist('https://example.test/a.png', 'Artist A'),
      'Artist A',
    );
    expect(tabletArtworkArtist(null, ''), 'Artist unknown');
  });

  test(
    'native import failure is actionable and preserves platform diagnosis',
    () {
      final message = ArtworkImportException(
        PlatformException(
          code: 'file_picker_error',
          message: 'Failed to process any images',
          details: 'Provider representation unavailable',
        ),
      ).toString();
      expect(message, contains('Try again'));
      expect(message, contains('current artwork is unchanged'));
      expect(message, contains('file_picker_error'));
      expect(message, contains('Provider representation unavailable'));
    },
  );

  testWidgets(
    'caption reuses original nib and one artist accessibility label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TabletArtworkCredit(url: 'tablet-art:abc', artist: ''),
          ),
        ),
      );
      expect(find.byType(ArtworkCreditCaption), findsOneWidget);
      expect(find.bySemanticsLabel('Artist user uploaded'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'invalid URL stays beside draft and never changes saved artwork',
    (tester) async {
      final token = sampleToken();
      final fixture = TableFixture(stateWithTokens([token]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = fixture.repository.encoded;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableModalFrame(
              child: PlayerKeyboardHost(
                child: ListView(
                  children: [
                    TabletArtworkSelection(
                      board: fixture.board,
                      catalog: fixture.catalog,
                      player: fixture.player,
                      token: fixture.token('source'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final field = tester.widget<PlayerField>(find.byType(PlayerField));
      field.controller.text = 'not an image URL';
      await tester.tap(find.text('Preview image URL'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a complete'), findsOneWidget);
      expect(field.controller.text, 'not an image URL');
      expect(fixture.repository.encoded, before);
      expect(find.text('Use this artwork'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'URL preview is staged; failed Apply retains candidate and retry saves',
    (tester) async {
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final pending = Completer<void>();
      var calls = 0;
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = fixture.repository.encoded;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableModalFrame(
              child: PlayerKeyboardHost(
                child: ListenableBuilder(
                  listenable: fixture.controller,
                  builder: (context, _) => ListView(
                    children: [
                      TabletArtworkSelection(
                        board: fixture.board,
                        catalog: fixture.catalog,
                        player: fixture.player,
                        token: fixture.token('source'),
                        validate: (_) {
                          calls++;
                          return calls == 1 ? pending.future : Future.value();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      tester.widget<PlayerField>(find.byType(PlayerField)).controller.text =
          'https://example.test/art.png';
      await tester.tap(find.text('Preview image URL'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(fixture.repository.encoded, before);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Preview — not saved'), findsOneWidget);
      expect(find.text('Use this artwork'), findsOneWidget);
      expect(find.text('Artist unknown'), findsOneWidget);
      expect(fixture.repository.encoded, before);
      fixture.repository.failSave = true;
      await tester.ensureVisible(find.text('Use this artwork'));
      await tester.tap(find.text('Use this artwork'));
      await tester.pumpAndSettle();
      expect(find.text('Preview — not saved'), findsOneWidget);
      expect(find.textContaining('Simulated storage failure'), findsOneWidget);
      expect(fixture.repository.encoded, before);
      fixture.repository.failSave = false;
      await tester.ensureVisible(find.text('Use this artwork'));
      await tester.tap(find.text('Use this artwork'));
      await tester.pumpAndSettle();
      expect(
        fixture.token('source').artworkUrl,
        'https://example.test/art.png',
      );
      expect(find.text('Use this artwork'), findsNothing);
      expect(find.text('Current artwork'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

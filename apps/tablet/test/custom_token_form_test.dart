import 'support/control_finders.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/widgets/mana/mana_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/custom_token_fields.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

class _FormArtworkPicker extends FilePicker {
  bool fail = true;
  int calls = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls++;
    expect(type, FileType.image);
    expect(withData, isTrue);
    if (fail) {
      throw PlatformException(code: 'test_picker', message: 'Pick failed');
    }
    return null;
  }
}

void main() {
  late TableFixture fixture;

  setUp(() {
    fixture = TableFixture();
  });
  tearDown(() => fixture.dispose());

  PlayerField field(WidgetTester tester, String label) => tester.widget(
    find.byWidgetPredicate(
      (widget) => widget is PlayerField && widget.label == label,
    ),
  );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {int turns = 0}) async {
    await fixture.initialize();
    fixture.catalog.loaded = true;
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                initialPage: WorkspacePage.tokens,
                quarterTurns: turns,
              ),
              child: const Text('Open test form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open test form'));
    await tester.pumpAndSettle();
    if (find.byType(CustomTokenColorPicker).evaluate().isEmpty) {
      await tap(tester, find.text('Custom token'));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Finder color(String code) => find.byKey(ValueKey('custom-token-color-$code'));

  testWidgets('mana buttons save multicolor and symbolic P/T unchanged', (
    tester,
  ) async {
    await fixture.initialize();
    final existing = TokenDefinition(
      name: 'Existing token',
      pt: '1+*/*',
      type: 'Creature',
      colors: 'GW',
      abilities: '',
      popularity: 0,
    );
    await fixture.catalog.saveCustom(existing);
    final existingJson = jsonEncode(existing.toJson());
    await open(tester);
    field(tester, 'Name').controller.text = 'New token';
    field(tester, 'Power').controller.text = '*';
    field(tester, 'Toughness').controller.text = '1+*';
    expect(field(tester, 'Power').numeric, isFalse);
    expect(field(tester, 'Toughness').numeric, isFalse);
    expect(find.byIcon(ManaIcons.power), findsOneWidget);
    expect(find.byIcon(ManaIcons.toughness), findsOneWidget);
    await tap(tester, color('G'));
    await tap(tester, color('W'));
    await tap(tester, color('B'));
    await tap(tester, find.text('Save custom token'));
    final saved = fixture.catalog.customTokens.singleWhere(
      (token) => token.name == 'New token',
    );
    expect(saved.colors, 'WBG');
    expect(saved.pt, '*/1+*');
    expect(saved.type, 'Creature');
    expect(
      jsonEncode(fixture.catalog.byId(existing.id)!.toJson()),
      existingJson,
    );
    expect(fixture.player.tokens, isEmpty);
    expect(fixture.controller.session.history, isEmpty);
    expect(fixture.repository.encoded, contains('*/1+*'));
    expect(find.text('Custom token saved.'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('colorless clears all colors and empty stats remain empty', (
    tester,
  ) async {
    await open(tester);
    field(tester, 'Name').controller.text = 'Blank treasure';
    field(tester, 'Type').controller.text = 'Artifact — Treasure';
    for (final code in ['W', 'U', 'B', 'R', 'G']) {
      await tap(tester, color(code));
    }
    await tap(tester, color('C'));
    final picker = tester.widget<CustomTokenColorPicker>(
      find.byType(CustomTokenColorPicker),
    );
    expect(picker.controller.text, isEmpty);
    await tap(tester, color('U'));
    await tap(tester, color('U'));
    expect(picker.controller.text, isEmpty);
    await tap(tester, find.text('Save custom token'));
    final saved = fixture.catalog.customTokens.single;
    expect(saved.colors, isEmpty);
    expect(saved.pt, isEmpty);
    expect(saved.type, 'Artifact — Treasure');
    expect(saved.artwork, isEmpty);
    await close(tester);
  });

  testWidgets('name and incomplete stats validate without discarding input', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.text('Save custom token'));
    expect(find.textContaining('A token needs a name.'), findsOneWidget);
    await reveal(tester, find.byType(CustomTokenColorPicker));
    field(tester, 'Name').controller.text = 'Variable creature';
    field(tester, 'Power').controller.text = '-1';
    await tap(tester, color('R'));
    await tap(tester, find.text('Save custom token'));
    expect(
      find.textContaining(
        'Enter both power and toughness, or leave both empty.',
      ),
      findsOneWidget,
    );
    expect(fixture.catalog.customTokens, isEmpty);
    await reveal(tester, find.byType(CustomTokenColorPicker));
    expect(field(tester, 'Power').controller.text, '-1');
    field(tester, 'Toughness').controller.text = '*';
    await tap(tester, find.text('Save custom token'));
    expect(fixture.catalog.customTokens.single.pt, '-1/*');
    expect(fixture.catalog.customTokens.single.colors, 'R');
    await close(tester);
  });

  testWidgets('failed save recovers split fields and colors before one retry', (
    tester,
  ) async {
    await open(tester);
    field(tester, 'Name').controller.text = 'Recovered token';
    field(tester, 'Power').controller.text = '*';
    field(tester, 'Toughness').controller.text = '2';
    await tap(tester, color('U'));
    await tap(tester, color('R'));
    final before = fixture.repository.encoded;
    fixture.repository.failSave = true;
    await tap(tester, find.text('Save custom token'));
    expect(fixture.repository.encoded, before);
    expect(fixture.catalog.customTokens, isEmpty);
    await close(tester);
    await open(tester);
    expect(field(tester, 'Name').controller.text, 'Recovered token');
    expect(field(tester, 'Power').controller.text, '*');
    expect(field(tester, 'Toughness').controller.text, '2');
    expect(
      tester
          .widget<CustomTokenColorPicker>(find.byType(CustomTokenColorPicker))
          .controller
          .text,
      'UR',
    );
    fixture.repository.failSave = false;
    await tap(tester, find.text('Save custom token'));
    expect(fixture.catalog.customTokens.single.pt, '*/2');
    expect(fixture.catalog.customTokens.single.colors, 'UR');
    await close(tester);
  });

  testWidgets('picker failure and cancellation retain the custom-token draft', (
    tester,
  ) async {
    final picker = _FormArtworkPicker();
    FilePicker.platform = picker;
    await open(tester);
    field(tester, 'Name').controller.text = 'Artwork draft';
    field(tester, 'Power').controller.text = '1+*';
    field(tester, 'Toughness').controller.text = '*';
    await tap(tester, color('G'));
    final before = fixture.repository.encoded;
    await tap(tester, find.text('Choose artwork'));
    expect(find.textContaining('Pick failed'), findsOneWidget);
    picker.fail = false;
    await tap(tester, find.text('Choose artwork'));
    expect(picker.calls, 2);
    expect(fixture.repository.encoded, before);
    await reveal(tester, find.byType(CustomTokenColorPicker));
    expect(field(tester, 'Name').controller.text, 'Artwork draft');
    expect(field(tester, 'Power').controller.text, '1+*');
    expect(field(tester, 'Toughness').controller.text, '*');
    expect(
      tester
          .widget<CustomTokenColorPicker>(find.byType(CustomTokenColorPicker))
          .controller
          .text,
      'G',
    );
    await tap(tester, find.text('Save custom token'));
    expect(fixture.catalog.customTokens.single.artwork, isEmpty);
    expect(fixture.catalog.customTokens.single.pt, '1+*/*');
    await close(tester);
  });

  testWidgets(
    'color toggles expose enabled selected semantics and 48px targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CustomTokenColorPicker(controller: controller)),
        ),
      );
      for (final code in ['W', 'U', 'B', 'R', 'G', 'C']) {
        expect(tester.getSize(color(code)), const Size(48, 48));
        final data = tester.getSemantics(color(code)).getSemanticsData();
        expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      }
      expect(
        tester
            .getSemantics(color('C'))
            .getSemanticsData()
            .flagsCollection
            .isToggled,
        ui.Tristate.isTrue,
      );
      await tester.tap(color('W'));
      await tester.pumpAndSettle();
      expect(controller.text, 'W');
      expect(
        tester
            .getSemantics(color('C'))
            .getSemanticsData()
            .flagsCollection
            .isToggled,
        ui.Tristate.isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      semantics.dispose();
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:doubling_season/widgets/mana/mana_symbol.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

const _capture = ValueKey('keyboard-capture');
const _strip = ValueKey('player-keyboard-mana-shortcuts');
const _codes = [
  'W',
  'U',
  'B',
  'R',
  'G',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
];
final _captureDir = kIsWeb ? null : Platform.environment['MANA_KEYS_CAPTURE'];

void main() {
  setUpAll(() async {
    if (_captureDir == null) return;
    await Directory(_captureDir!).create(recursive: true);
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
  });

  Future<void> capture(WidgetTester tester, String title) async {
    if (_captureDir == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_capture),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$_captureDir/$title.png',
        ).writeAsBytes(png.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final (size, modal) in [
    (const Size(1133, 744), true),
    (const Size(744, 1133), true),
    (const Size(1133, 744), false),
    (const Size(744, 1133), false),
  ]) {
    testWidgets('mana strip has grouped external gaps at $size modal=$modal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      final editor = PlayerKeyboardHost(
        focusTextEntry: true,
        child: PlayerField(controller: controller, label: 'Rules text'),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: tableTheme(Brightness.dark),
            home: Scaffold(
              body: modal ? TableModalFrame(child: editor) : editor,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PlayerField));
      await tester.pumpAndSettle();
      final strip = find.byKey(_strip);
      final viewport = tester.getRect(strip);
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: strip, matching: find.byType(Scrollable)),
      );
      Finder key(String code) => find.byKey(ValueKey('mana-shortcut-$code'));
      Finder button(String code) =>
          find.descendant(of: key(code), matching: find.byType(FilledButton));
      Finder symbol(String code) =>
          find.descendant(of: key(code), matching: find.byType(ManaSymbol));

      expect(
        viewport.width,
        modal
            ? 720
            : size.width > 830
            ? 830
            : size.width,
      );
      expect(tester.getRect(button('W')).left - viewport.left, 12);
      for (var index = 0; index < _codes.length; index++) {
        final code = _codes[index];
        expect(tester.getSize(button(code)), const Size(44, 44));
        expect(tester.widget<ManaSymbol>(symbol(code)).size, 24);
        if (index > 0) {
          expect(
            tester.getRect(button(code)).left -
                tester.getRect(button(_codes[index - 1])).right,
            index == 5 || index == 15 ? 12 : 6,
          );
        }
      }
      final overflows = viewport.width < 830;
      expect(scroll.position.maxScrollExtent, 830 - viewport.width);
      final scrollbar = tester.widget<Scrollbar>(
        find.ancestor(of: strip, matching: find.byType(Scrollbar)).first,
      );
      expect(scrollbar.thumbVisibility, overflows);
      if (!overflows) expect(viewport.center.dx, size.width / 2);
      final name =
          '${size.width.toInt()}x${size.height.toInt()}-${modal ? 'modal' : 'full'}';
      await capture(tester, name);
      expect(find.bySemanticsLabel('Insert one white mana'), findsOneWidget);

      // Traverse the real focusable keys. Flutter's focus policy reveals the
      // outgoing end of the row before the focused key is activated.
      Focus.of(tester.element(symbol('W'))).requestFocus();
      await tester.pumpAndSettle();
      for (final code in _codes.skip(1)) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          Focus.of(tester.element(symbol(code))).hasPrimaryFocus,
          isTrue,
          reason: code,
        );
      }
      expect(key('T').hitTestable(), findsOneWidget);
      expect(find.bySemanticsLabel('Insert tap'), findsOneWidget);
      if (overflows) {
        expect(scroll.position.pixels, greaterThan(0));
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(viewport.right - tester.getRect(button('T')).right, 12);
        await capture(tester, '$name-end');
      }
      await tester.tap(key('T'));
      await tester.pumpAndSettle();
      expect(controller.text, '{T}');
      expect(tester.takeException(), isNull);
      semantics.dispose();

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

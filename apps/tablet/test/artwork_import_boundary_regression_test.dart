import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/artwork_selection.dart';

class MemoryPicker extends FilePicker {
  int calls = 0;
  PlatformException? failure;
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
    if (failure != null) throw failure!;
    expect(type, FileType.image);
    expect(withData, isTrue);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    return FilePickerResult([
      PlatformFile(name: 'image.png', size: bytes.length, bytes: bytes),
    ]);
  }
}

void main() {
  testWidgets(
    'platform failure reports diagnostic and a later retry remains possible',
    (tester) async {
      final picker = MemoryPicker()
        ..failure = PlatformException(
          code: 'file_picker_error',
          message: 'Failed to process any images',
          details: 'Provider failed',
        );
      FilePicker.platform = picker;
      Object? failure;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  try {
                    await pickTabletArtwork(context);
                  } catch (error) {
                    failure = error;
                  }
                },
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(failure, isA<ArtworkImportException>());
      expect(failure.toString(), contains('Provider failed'));
      expect(find.text('Use crop'), findsNothing);
      picker.failure = null;
      await tester.runAsync(() async {
        await tester.tap(find.text('Import'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(picker.calls, 2);
      expect(find.text('Use crop'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'image bytes reach player-facing crop, cancellation does not save',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);
      final picker = MemoryPicker();
      FilePicker.platform = picker;
      String? result = 'pending';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await pickTabletArtwork(context, quarterTurns: 2);
                },
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Import'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.text('Use crop'), findsOneWidget);
      final shell = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('table-modal-surface')),
      );
      expect(shell.size, const Size(720, 524));
      final rect = MatrixUtils.transformRect(
        shell.getTransformTo(null),
        Offset.zero & shell.size,
      );
      expect(rect.left, closeTo(40, .01));
      expect(rect.top, closeTo(40, .01));
      expect(rect.right, closeTo(760, .01));
      expect(rect.bottom, closeTo(564, .01));
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns,
        2,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

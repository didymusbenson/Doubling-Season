import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/artwork_selection.dart';

class MemoryPicker extends FilePicker {
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
    'image bytes reach player-facing crop, cancellation does not save',
    (tester) async {
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

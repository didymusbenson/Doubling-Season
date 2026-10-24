import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_artwork.dart';

// Explicit opt-in integration gate: uses the real catalog/CDN, not test imagery.
// flutter test --platform chrome --dart-define=TABLET_NETWORK_IMAGE_TEST=true ...
void main() {
  testWidgets(
    'actual Soldier art renders from the same validated web bytes',
    (tester) async {
      const canonical =
          'https://cards.scryfall.io/large/front/c/8/c8ae31d1-9a6e-43f3-9b04-bd15699f73d6.jpg';
      const crop =
          'https://cards.scryfall.io/art_crop/front/c/8/c8ae31d1-9a6e-43f3-9b04-bd15699f73d6.jpg';
      final decoded = await tester.runAsync(
        () => TableArtwork.validatedBytes(crop),
      );
      expect(decoded, isNotNull);
      Widget view() => const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: TableArtwork(
              url: canonical,
              crop: true,
              showLoadStatus: true,
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(identical((image.image as MemoryImage).bytes, decoded), isTrue);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(
        identical(
          (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
          decoded,
        ),
        isTrue,
      );
      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb || !const bool.fromEnvironment('TABLET_NETWORK_IMAGE_TEST'),
  );
}

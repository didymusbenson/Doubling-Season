import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../models/token_counter.dart';
import '../models/deck.dart';
import '../models/token_template.dart';
import '../models/token_definition.dart';
import '../models/token_artwork_preference.dart';

Future<void> initHive() async {
  await Hive.initFlutter();

  // Register all TypeAdapters
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(TokenCounterAdapter());
  Hive.registerAdapter(DeckAdapter());
  Hive.registerAdapter(TokenTemplateAdapter());
  Hive.registerAdapter(ArtworkVariantAdapter());
  Hive.registerAdapter(TokenArtworkPreferenceAdapter()); // NEW - Custom Artwork Feature

  // Open boxes in parallel for optimal startup performance
  await Future.wait([
    Hive.openBox<Item>('items'),
    Hive.openLazyBox<Deck>('decks'),
    Hive.openBox<TokenArtworkPreference>('artworkPreferences'), // NEW - Custom Artwork Feature
  ]);
}

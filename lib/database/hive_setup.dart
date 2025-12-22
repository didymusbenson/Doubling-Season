import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../models/token_counter.dart';
import '../models/deck.dart';
import '../models/token_template.dart';
import '../models/token_definition.dart';
import '../models/token_artwork_preference.dart';
import '../models/tracker_widget.dart'; // NEW - Widget Cards Feature
import '../models/toggle_widget.dart'; // NEW - Widget Cards Feature
import '../models/tracker_widget_template.dart'; // NEW - Deck templates for utilities
import '../models/toggle_widget_template.dart'; // NEW - Deck templates for utilities

Future<void> initHive() async {
  await Hive.initFlutter();

  // Register all TypeAdapters
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(TokenCounterAdapter());
  Hive.registerAdapter(DeckAdapter());
  Hive.registerAdapter(TokenTemplateAdapter());
  Hive.registerAdapter(ArtworkVariantAdapter());
  Hive.registerAdapter(TokenArtworkPreferenceAdapter()); // NEW - Custom Artwork Feature
  Hive.registerAdapter(TrackerWidgetAdapter()); // NEW - Widget Cards Feature
  Hive.registerAdapter(ToggleWidgetAdapter()); // NEW - Widget Cards Feature
  Hive.registerAdapter(TrackerWidgetTemplateAdapter()); // NEW - Deck templates for utilities
  Hive.registerAdapter(ToggleWidgetTemplateAdapter()); // NEW - Deck templates for utilities

  // Open boxes in parallel for optimal startup performance
  await Future.wait([
    Hive.openBox<Item>('items'),
    Hive.openLazyBox<Deck>('decks'),
    Hive.openBox<TokenArtworkPreference>('artworkPreferences'), // NEW - Custom Artwork Feature
    Hive.openBox<TrackerWidget>('trackerWidgets'), // NEW - Widget Cards Feature
    Hive.openBox<ToggleWidget>('toggleWidgets'), // NEW - Widget Cards Feature
  ]);
}

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/deck.dart';

class DeckProvider extends ChangeNotifier {
  late LazyBox<Deck> _decksBox; // Use LazyBox for memory optimization
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> init() async {
    _decksBox = await Hive.openLazyBox<Deck>('decks');
    _initialized = true;
    notifyListeners();
  }

  Future<List<Deck>> get decks async {
    final keys = _decksBox.keys.toList();
    final deckList = <Deck>[];

    for (final key in keys) {
      final deck = await _decksBox.get(key);
      if (deck != null) deckList.add(deck);
    }

    return deckList;
  }

  Future<void> saveDeck(Deck deck) async {
    await _decksBox.add(deck);
    notifyListeners();
  }

  Future<void> deleteDeck(Deck deck) async {
    await deck.delete();
    notifyListeners();
  }

  @override
  void dispose() {
    _decksBox.close();
    super.dispose();
  }
}

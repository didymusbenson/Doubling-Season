import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/deck.dart';
import '../utils/constants.dart';

class DeckProvider extends ChangeNotifier {
  late Box<Deck> _decksBox;
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> init() async {
    _decksBox = Hive.box<Deck>(DatabaseConstants.decksBox);
    _initialized = true;
    notifyListeners();
  }

  List<Deck> get decks {
    return _decksBox.values.toList();
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

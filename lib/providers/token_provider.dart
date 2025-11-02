import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';

class TokenProvider extends ChangeNotifier {
  late Box<Item> _itemsBox;
  bool _initialized = false;

  bool get initialized => _initialized;

  // Expose Hive's listenable for reactive updates (OPTIMIZATION)
  ValueListenable<Box<Item>> get listenable => _itemsBox.listenable();

  Future<void> init() async {
    _itemsBox = await Hive.openBox<Item>('items');
    _initialized = true;
    notifyListeners();
  }

  List<Item> get items {
    final allItems = _itemsBox.values.toList();
    allItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allItems;
  }

  Future<void> insertItem(Item item) async {
    await _itemsBox.add(item);
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await item.save(); // HiveObject method
    notifyListeners();
  }

  Future<void> deleteItem(Item item) async {
    await item.delete(); // HiveObject method
    notifyListeners();
  }

  // Token manipulation methods
  Future<void> addTokens(Item item, int amount, bool summoningSicknessEnabled) async {
    item.amount += amount;
    if (summoningSicknessEnabled) {
      item.summoningSick += amount;
    }
    await item.save();
    notifyListeners();
  }

  Future<void> removeTokens(Item item, int amount) async {
    final toRemove = amount.clamp(0, item.amount);
    item.amount -= toRemove;

    // Adjust tapped count proportionally
    if (item.tapped > item.amount) {
      item.tapped = item.amount;
    }

    // Adjust summoning sick count
    if (item.summoningSick > item.amount) {
      item.summoningSick = item.amount;
    }

    await item.save();
    notifyListeners();
  }

  Future<void> tapTokens(Item item, int amount) async {
    final untapped = item.amount - item.tapped;
    final toTap = amount.clamp(0, untapped);
    item.tapped += toTap;
    await item.save();
    notifyListeners();
  }

  Future<void> untapTokens(Item item, int amount) async {
    final toUntap = amount.clamp(0, item.tapped);
    item.tapped -= toUntap;
    await item.save();
    notifyListeners();
  }

  Future<void> copyToken(Item item, bool summoningSicknessEnabled) async {
    final newItem = Item(
      name: item.name,
      pt: item.pt,
      abilities: item.abilities,
      colors: item.colors,
      amount: item.amount,
      tapped: item.tapped,
      summoningSick: summoningSicknessEnabled ? item.amount : 0,
    );

    // Add to box FIRST, then set properties that call save()
    await _itemsBox.add(newItem);

    // Copy power/toughness counters (these setters call save())
    newItem.plusOneCounters = item.plusOneCounters;
    newItem.minusOneCounters = item.minusOneCounters;

    // Copy custom counters
    for (final counter in item.counters) {
      newItem.counters.add(counter);
    }
    await newItem.save();

    notifyListeners();
  }

  Future<void> untapAll() async {
    for (final item in items) {
      item.tapped = 0;
    }
    notifyListeners();
  }

  Future<void> clearSummoningSickness() async {
    for (final item in items) {
      item.summoningSick = 0;
    }
    notifyListeners();
  }

  Future<void> boardWipeZero() async {
    for (final item in items) {
      item.amount = 0;
      item.tapped = 0;
      item.summoningSick = 0;
    }
    notifyListeners();
  }

  Future<void> boardWipeDelete() async {
    await _itemsBox.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _itemsBox.close();
    super.dispose();
  }
}

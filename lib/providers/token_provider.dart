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

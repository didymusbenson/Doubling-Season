import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';

class TokenProvider extends ChangeNotifier {
  late Box<Item> _itemsBox;
  bool _initialized = false;
  String? _errorMessage;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

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
    try {
      await _itemsBox.add(item);
      _errorMessage = null; // Clear any previous errors
      notifyListeners();
      debugPrint('TokenProvider: Successfully created token "${item.name}" with amount ${item.amount}');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating token: Unable to save to storage. This might happen if device storage is full or the database is corrupted.';
      debugPrint('TokenProvider.insertItem: HiveError while adding item "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow; // Re-throw so UI can handle it if needed
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating token. Please try again or restart the app if the problem persists.';
      debugPrint('TokenProvider.insertItem: Unexpected error while adding item "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateItem(Item item) async {
    try {
      await item.save(); // HiveObject method
      _errorMessage = null; // Clear any previous errors
      notifyListeners();
      debugPrint('TokenProvider: Successfully updated token "${item.name}" (amount: ${item.amount}, tapped: ${item.tapped})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while updating token: Changes could not be saved to storage. Your device might be low on storage space.';
      debugPrint('TokenProvider.updateItem: HiveError while saving item "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while updating token. Changes may not have been saved.';
      debugPrint('TokenProvider.updateItem: Unexpected error while saving item "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteItem(Item item) async {
    try {
      await item.delete(); // HiveObject method
      _errorMessage = null; // Clear any previous errors
      notifyListeners();
      debugPrint('TokenProvider: Successfully deleted token "${item.name}"');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while deleting token: Unable to remove from storage. The token may still appear after restarting the app.';
      debugPrint('TokenProvider.deleteItem: HiveError while deleting item "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while deleting token. The token may not have been removed.';
      debugPrint('TokenProvider.deleteItem: Unexpected error while deleting item "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  // Token manipulation methods
  Future<void> addTokens(Item item, int amount, bool summoningSicknessEnabled) async {
    try {
      final oldAmount = item.amount;
      item.amount += amount;
      if (summoningSicknessEnabled) {
        item.summoningSick += amount;
      }
      await item.save();
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Added $amount tokens to "${item.name}" (${oldAmount} → ${item.amount})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while adding tokens: Changes could not be saved. Your token count may not have increased.';
      debugPrint('TokenProvider.addTokens: HiveError adding $amount to "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while adding tokens. The operation may have failed.';
      debugPrint('TokenProvider.addTokens: Unexpected error adding $amount to "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeTokens(Item item, int amount) async {
    try {
      final oldAmount = item.amount;
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
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Removed $toRemove tokens from "${item.name}" (${oldAmount} → ${item.amount})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while removing tokens: Changes could not be saved. Your token count may not have decreased.';
      debugPrint('TokenProvider.removeTokens: HiveError removing $amount from "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while removing tokens. The operation may have failed.';
      debugPrint('TokenProvider.removeTokens: Unexpected error removing $amount from "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> tapTokens(Item item, int amount) async {
    try {
      final oldTapped = item.tapped;
      final untapped = item.amount - item.tapped;
      final toTap = amount.clamp(0, untapped);
      item.tapped += toTap;
      await item.save();
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Tapped $toTap tokens of "${item.name}" (tapped: ${oldTapped} → ${item.tapped})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while tapping tokens: Changes could not be saved. Tap state may not have changed.';
      debugPrint('TokenProvider.tapTokens: HiveError tapping $amount of "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while tapping tokens. The operation may have failed.';
      debugPrint('TokenProvider.tapTokens: Unexpected error tapping $amount of "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> untapTokens(Item item, int amount) async {
    try {
      final oldTapped = item.tapped;
      final toUntap = amount.clamp(0, item.tapped);
      item.tapped -= toUntap;
      await item.save();
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Untapped $toUntap tokens of "${item.name}" (tapped: ${oldTapped} → ${item.tapped})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while untapping tokens: Changes could not be saved. Tap state may not have changed.';
      debugPrint('TokenProvider.untapTokens: HiveError untapping $amount of "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while untapping tokens. The operation may have failed.';
      debugPrint('TokenProvider.untapTokens: Unexpected error untapping $amount of "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> copyToken(Item item, bool summoningSicknessEnabled) async {
    try {
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

      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully copied token "${item.name}" (amount: ${item.amount}, counters: ${item.counters.length})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while copying token: Unable to create duplicate. Your device may be low on storage.';
      debugPrint('TokenProvider.copyToken: HiveError copying "${item.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while copying token. The duplicate may not have been created.';
      debugPrint('TokenProvider.copyToken: Unexpected error copying "${item.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> untapAll() async {
    try {
      final itemList = items;
      for (final item in itemList) {
        item.tapped = 0;
        await item.save(); // Explicitly await save for bulk operations
      }
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully untapped all tokens (${itemList.length} token stacks)');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while untapping all: Some tokens may not have been untapped. Try untapping individual stacks.';
      debugPrint('TokenProvider.untapAll: HiveError during bulk untap operation. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while untapping all tokens. Some may not have been untapped.';
      debugPrint('TokenProvider.untapAll: Unexpected error during bulk untap. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearSummoningSickness() async {
    try {
      final itemList = items;
      for (final item in itemList) {
        item.summoningSick = 0;
        await item.save(); // Explicitly await save for bulk operations
      }
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully cleared summoning sickness from all tokens (${itemList.length} token stacks)');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while clearing summoning sickness: Some tokens may still have summoning sickness. Try clearing individual stacks.';
      debugPrint('TokenProvider.clearSummoningSickness: HiveError during bulk clear operation. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while clearing summoning sickness. Some tokens may not have been updated.';
      debugPrint('TokenProvider.clearSummoningSickness: Unexpected error during bulk clear. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> boardWipeZero() async {
    try {
      final itemList = items;
      for (final item in itemList) {
        item.amount = 0;
        item.tapped = 0;
        item.summoningSick = 0;
        await item.save(); // Explicitly await save for bulk operations
      }
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully performed board wipe (set all token amounts to 0, ${itemList.length} stacks affected)');
    } on HiveError catch (e) {
      _errorMessage = 'Database error during board wipe: Some tokens may not have been reset to zero. You may need to manually adjust them.';
      debugPrint('TokenProvider.boardWipeZero: HiveError during board wipe operation. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error during board wipe. Some tokens may not have been reset.';
      debugPrint('TokenProvider.boardWipeZero: Unexpected error during board wipe. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> boardWipeDelete() async {
    try {
      final itemCount = _itemsBox.length;
      await _itemsBox.clear();
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully deleted all tokens from board ($itemCount token stacks removed)');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while deleting all tokens: The board may not have been completely cleared. Try deleting tokens individually.';
      debugPrint('TokenProvider.boardWipeDelete: HiveError clearing items box. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while deleting all tokens. Some tokens may remain on the board.';
      debugPrint('TokenProvider.boardWipeDelete: Unexpected error clearing box. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _itemsBox.close();
    super.dispose();
  }
}

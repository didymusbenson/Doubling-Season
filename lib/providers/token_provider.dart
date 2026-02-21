import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../models/token_definition.dart';
import '../utils/constants.dart';
import '../utils/game_events.dart';

class TokenProvider extends ChangeNotifier {
  late Box<Item> _itemsBox;
  bool _initialized = false;
  String? _errorMessage;

  // Cache for Scute Swarm definition (loaded once per session)
  TokenDefinition? _scuteSwarmCache;

  // Cache for basic Goblin definition (loaded once per session)
  TokenDefinition? _basicGoblinCache;

  // Cache for Academy Manufactor token definitions (loaded once per session)
  TokenDefinition? _clueCache;
  TokenDefinition? _foodCache;
  TokenDefinition? _treasureCache;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

  // Expose Hive's listenable for reactive updates (OPTIMIZATION)
  ValueListenable<Box<Item>> get listenable => _itemsBox.listenable();

  Future<void> init() async {
    try {
      debugPrint('TokenProvider.init: Opening items box...');
      _itemsBox = await Hive.openBox<Item>(DatabaseConstants.itemsBox);
      debugPrint('TokenProvider.init: Box opened, has ${_itemsBox.length} items');

      debugPrint('TokenProvider.init: Running migration...');
      _ensureOrdersAssigned(); // Silent migration for order field
      debugPrint('TokenProvider.init: Migration complete');

      _initialized = true;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('TokenProvider.init: ERROR during initialization');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'Failed to load tokens: $e';
      rethrow; // Let main.dart error handler catch this
    }
  }

  void _ensureOrdersAssigned() {
    try {
      debugPrint('TokenProvider._ensureOrdersAssigned: Reading items...');
      final items = _itemsBox.values.toList();
      debugPrint('TokenProvider._ensureOrdersAssigned: Got ${items.length} items');

      bool needsReorder = items.any((item) => item.order == 0);

      if (needsReorder) {
        debugPrint('TokenProvider._ensureOrdersAssigned: Migrating ${items.length} items with missing order');
        // Assign sequential orders based on current position
        for (int i = 0; i < items.length; i++) {
          items[i].order = i.toDouble();
          items[i].save();
        }
        debugPrint('TokenProvider: Migrated ${items.length} tokens to use order field');
      } else {
        debugPrint('TokenProvider._ensureOrdersAssigned: All items already have order assigned');
      }
    } catch (e, stackTrace) {
      debugPrint('TokenProvider._ensureOrdersAssigned: ERROR during migration');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  List<Item> get items {
    final allItems = _itemsBox.values.toList();
    allItems.sort((a, b) => a.order.compareTo(b.order));
    return allItems;
  }

  Future<void> insertItem(Item item) async {
    try {
      // Assign order to new token if not already set
      if (item.order == 0.0) {
        final items = _itemsBox.values.toList();
        if (items.isEmpty) {
          item.order = 0.0;
        } else {
          // Find max order and add 1.0 (whole number for new items)
          final maxOrder = items.map((i) => i.order).reduce(max);
          item.order = maxOrder.floor() + 1.0;
        }
      }

      await _itemsBox.add(item);

      // Fire ETB event for creatures
      if (item.hasPowerToughness) {
        GameEvents.instance.notifyCreatureEntered(item, item.amount);
      }

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

  Future<void> insertItemWithExplicitOrder(Item item) async {
    // Item.order is already set - don't override it
    await _itemsBox.add(item);
    _errorMessage = null;
    notifyListeners();
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
      // Apply summoning sickness if enabled AND token is a creature without Haste
      if (summoningSicknessEnabled && item.hasPowerToughness && !item.hasHaste) {
        item.summoningSick += amount;
      }
      await item.save();

      // Fire ETB event for added creatures
      if (item.hasPowerToughness) {
        GameEvents.instance.notifyCreatureEntered(item, amount);
      }

      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Added $amount tokens to "${item.name}" ($oldAmount → $item.amount)');
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
      debugPrint('TokenProvider: Removed $toRemove tokens from "${item.name}" ($oldAmount → $item.amount)');
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
      debugPrint('TokenProvider: Tapped $toTap tokens of "${item.name}" (tapped: $oldTapped → $item.tapped)');
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
      debugPrint('TokenProvider: Untapped $toUntap tokens of "${item.name}" (tapped: $oldTapped → $item.tapped)');
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

  Future<void> copyToken(Item original, bool summoningSicknessEnabled) async {
    try {
      // Find the next item after the original
      final items = _itemsBox.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final originalIndex = items.indexWhere((i) => i.key == original.key);

      double newOrder;
      if (originalIndex == items.length - 1) {
        // Original is last item - add 1.0
        newOrder = original.order + 1.0;
      } else {
        // Insert between original and next item (fractional)
        final nextOrder = items[originalIndex + 1].order;
        newOrder = (original.order + nextOrder) / 2.0;
      }

      // Create single new token that is summoning sick if appropriate
      final shouldBeSummoningSick = summoningSicknessEnabled &&
                                    original.hasPowerToughness &&
                                    !original.hasHaste;

      final newItem = Item(
        name: original.name,
        pt: original.pt,
        abilities: original.abilities,
        colors: original.colors,
        type: original.type,
        amount: 1, // Always create just 1 token
        tapped: 0, // New token is untapped
        summoningSick: shouldBeSummoningSick ? 1 : 0, // Summoning sick if creature without haste
        order: newOrder,
        artworkUrl: original.artworkUrl,
        artworkSet: original.artworkSet,
        artworkOptions: original.artworkOptions != null
            ? List.from(original.artworkOptions!)
            : null,
      );

      // Add to box FIRST, then set properties that call save()
      await _itemsBox.add(newItem);

      // Copying counters was removed in version 1.8, uncomment to re-implement
      // newItem.plusOneCounters = original.plusOneCounters;
      // newItem.minusOneCounters = original.minusOneCounters;

      // Counter copying disabled in version 1.8
      // Rationale: Copy button creates fresh stacks for independent tracking.
      // Users should use "Split Stack" feature to preserve counters.
      //
      // Previous implementation had a bug where custom counters were shallow-copied,
      // causing counter modifications on one token to affect all copies.
      // The fix below creates proper deep copies, but counter copying itself
      // was disabled as the better UX choice.
      //
      // To re-enable counter copying (with proper deep copy):
      // for (final counter in original.counters) {
      //   newItem.counters.add(TokenCounter(
      //     name: counter.name,
      //     amount: counter.amount,
      //   ));
      // }

      await newItem.save();

      // Fire ETB event for copied creature
      if (newItem.hasPowerToughness) {
        GameEvents.instance.notifyCreatureEntered(newItem, newItem.amount);
      }

      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully copied token "${original.name}" (amount: ${original.amount}, counters: ${original.counters.length})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while copying token: Unable to create duplicate. Your device may be low on storage.';
      debugPrint('TokenProvider.copyToken: HiveError copying "${original.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while copying token. The duplicate may not have been created.';
      debugPrint('TokenProvider.copyToken: Unexpected error copying "${original.name}". Error: $e');
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

  Future<void> addPlusOneToAll() async {
    try {
      // Snapshot tokens with P/T at operation start (handles concurrent modifications safely)
      final tokensToModify = items.where((item) => item.pt.isNotEmpty).toList();

      for (final item in tokensToModify) {
        // Check if token still exists before modifying (handles deletions during operation)
        if (item.isInBox) {
          item.addPowerToughnessCounters(1);
          await item.save(); // Explicitly await save for bulk operations
        }
      }
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully added +1/+1 to all tokens with P/T (${tokensToModify.length} token stacks affected)');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while adding +1/+1 counters: Some tokens may not have received counters. Try adding counters individually.';
      debugPrint('TokenProvider.addPlusOneToAll: HiveError during bulk counter operation. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while adding +1/+1 counters. Some tokens may not have been updated.';
      debugPrint('TokenProvider.addPlusOneToAll: Unexpected error during bulk counter operation. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addMinusOneToAll() async {
    try {
      // Snapshot tokens with P/T at operation start (handles concurrent modifications safely)
      final tokensToModify = items.where((item) => item.pt.isNotEmpty).toList();

      for (final item in tokensToModify) {
        // Check if token still exists before modifying (handles deletions during operation)
        if (item.isInBox) {
          item.addPowerToughnessCounters(-1);
          await item.save(); // Explicitly await save for bulk operations
        }
      }
      _errorMessage = null;
      notifyListeners();
      debugPrint('TokenProvider: Successfully added -1/-1 to all tokens with P/T (${tokensToModify.length} token stacks affected)');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while adding -1/-1 counters: Some tokens may not have received counters. Try adding counters individually.';
      debugPrint('TokenProvider.addMinusOneToAll: HiveError during bulk counter operation. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while adding -1/-1 counters. Some tokens may not have been updated.';
      debugPrint('TokenProvider.addMinusOneToAll: Unexpected error during bulk counter operation. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  /// Scute Swarm special ability: creates new tokens based on total Scute Swarm count
  ///
  /// This method:
  /// 1. Counts all Scute Swarm tokens on the board (amount > 0)
  /// 2. Calculates finalAmount = count * multiplier
  /// 3. Finds first Scute Swarm stack without counters to add tokens to
  /// 4. If no such stack exists, creates a new stack from database definition
  /// Creates Scute Swarm tokens
  ///
  /// [insertionOrder] - The order value for new token if creating new stack (calculated by caller from all board items)
  Future<void> createScuteSwarmTokens(Item sourceToken, int multiplier, bool summoningSicknessEnabled, double insertionOrder) async {
    try {
      // Step 1: Count all Scute Swarm tokens (case-insensitive substring match, amount > 0)
      final allItems = items;
      int totalScuteCount = 0;
      for (final item in allItems) {
        if (item.name.toLowerCase().contains(GameConstants.scuteSwarmName) && item.amount > 0) {
          totalScuteCount += item.amount;
        }
      }

      // Step 2: Calculate final amount to create
      final finalAmount = totalScuteCount * multiplier;
      if (finalAmount <= 0) {
        debugPrint('TokenProvider.createScuteSwarmTokens: No tokens to create (count: $totalScuteCount, multiplier: $multiplier)');
        return;
      }

      // Step 3: Find target stack (first Scute Swarm with no counters)
      Item? targetStack;
      for (final item in allItems) {
        if (item.name.toLowerCase().contains(GameConstants.scuteSwarmName) &&
            item.plusOneCounters == 0 &&
            item.minusOneCounters == 0 &&
            item.counters.isEmpty) {
          targetStack = item;
          break;
        }
      }

      if (targetStack != null) {
        // Add to existing stack
        debugPrint('TokenProvider.createScuteSwarmTokens: Adding $finalAmount tokens to existing stack');
        targetStack.amount += finalAmount;

        // Add summoning sickness to new tokens only
        if (summoningSicknessEnabled && targetStack.hasPowerToughness && !targetStack.hasHaste) {
          targetStack.summoningSick += finalAmount;
        }

        await targetStack.save();

        // Fire ETB event for created creatures
        if (targetStack.hasPowerToughness) {
          GameEvents.instance.notifyCreatureEntered(targetStack, finalAmount);
        }

        _errorMessage = null;
        notifyListeners();
        debugPrint('TokenProvider.createScuteSwarmTokens: Successfully added $finalAmount Scute Swarms to existing stack');
      } else {
        // Step 4: Create new stack from database definition
        debugPrint('TokenProvider.createScuteSwarmTokens: Creating new stack with $finalAmount tokens');

        // Load token database and find Scute Swarm (cached for performance)
        if (_scuteSwarmCache == null) {
          final jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);
          final List<dynamic> jsonList = jsonDecode(jsonString);
          final scuteSwarmJson = jsonList.firstWhere(
            (json) => (json['name'] as String).toLowerCase().contains(GameConstants.scuteSwarmName),
            orElse: () => throw Exception('Scute Swarm not found in token database'),
          );
          _scuteSwarmCache = TokenDefinition.fromJson(scuteSwarmJson as Map<String, dynamic>);
        }

        final scuteSwarmDefinition = _scuteSwarmCache!;

        debugPrint('TokenProvider.createScuteSwarmTokens: Using insertion order $insertionOrder');

        // Create new item with database values and source artwork
        final shouldBeSummoningSick = summoningSicknessEnabled &&
                                      scuteSwarmDefinition.pt.isNotEmpty &&
                                      !scuteSwarmDefinition.abilities.toLowerCase().contains('haste');

        final newItem = Item(
          name: scuteSwarmDefinition.name,
          pt: scuteSwarmDefinition.pt,
          abilities: scuteSwarmDefinition.abilities,
          colors: scuteSwarmDefinition.colors,
          type: scuteSwarmDefinition.type,
          amount: finalAmount,
          tapped: 0, // Enters untapped
          summoningSick: shouldBeSummoningSick ? finalAmount : 0,
          order: insertionOrder,
          artworkUrl: sourceToken.artworkUrl,
          artworkSet: sourceToken.artworkSet,
          artworkOptions: sourceToken.artworkOptions != null
              ? List.from(sourceToken.artworkOptions!)
              : scuteSwarmDefinition.artwork.isNotEmpty
                  ? List.from(scuteSwarmDefinition.artwork)
                  : null,
        );

        // insertItem handles ETB events automatically
        await insertItem(newItem);

        debugPrint('TokenProvider.createScuteSwarmTokens: Successfully created new stack with $finalAmount Scute Swarms');
      }
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating Scute Swarm tokens: Changes could not be saved.';
      debugPrint('TokenProvider.createScuteSwarmTokens: HiveError. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating Scute Swarm tokens: ${e.toString()}';
      debugPrint('TokenProvider.createScuteSwarmTokens: Unexpected error. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  /// Creates Krenko goblin tokens with all available artwork options from database
  ///
  /// This method:
  /// 1. Loads the basic 1/1 red Goblin from token database (cached for performance)
  /// 2. Checks for existing Goblin stack without counters
  /// 3. Either adds to existing stack or creates new stack at specified order
  /// 4. Downloads default artwork in background (non-blocking)
  /// 5. Fires ETB events for Cathar's Crusade and other listeners
  ///
  /// [insertionOrder] - The order value for the new token (should be calculated from all board items)
  Future<void> createKrenkoGoblins(int amount, bool summoningSicknessEnabled, double insertionOrder) async {
    try {
      if (amount <= 0) {
        debugPrint('TokenProvider.createKrenkoGoblins: No tokens to create (amount: $amount)');
        return;
      }

      // Step 1: Load basic Goblin from database (cached for performance)
      if (_basicGoblinCache == null) {
        final jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final goblinJson = jsonList.firstWhere(
          (json) => (json['name'] as String) == 'Goblin' &&
                    (json['pt'] as String) == '1/1' &&
                    (json['colors'] as String) == 'R' &&
                    (json['abilities'] as String).isEmpty,
          orElse: () => throw Exception('Basic 1/1 red Goblin not found in token database'),
        );
        _basicGoblinCache = TokenDefinition.fromJson(goblinJson as Map<String, dynamic>);
      }
      final goblinDefinition = _basicGoblinCache!;

      // Step 2: Check if matching goblin token WITHOUT counters already exists
      final existingGoblinWithoutCounters = items.firstWhere(
        (item) {
          // Check if it matches goblin criteria
          final isMatchingGoblin = item.name == 'Goblin' &&
              item.pt == '1/1' &&
              item.colors == 'R' &&
              item.type.toLowerCase().contains('goblin') &&
              item.abilities.isEmpty;

          // Check if it has NO counters (any type)
          final hasNoCounters = item.plusOneCounters == 0 &&
              item.minusOneCounters == 0 &&
              item.counters.isEmpty;

          return isMatchingGoblin && hasNoCounters;
        },
        orElse: () => Item(name: '', pt: '', abilities: '', colors: '', type: ''), // Sentinel value
      );

      if (existingGoblinWithoutCounters.name.isNotEmpty) {
        // Add to existing token without counters
        debugPrint('TokenProvider.createKrenkoGoblins: Adding $amount goblins to existing stack');
        existingGoblinWithoutCounters.amount += amount;

        // Add summoning sickness to new tokens only
        if (summoningSicknessEnabled && !existingGoblinWithoutCounters.hasHaste) {
          existingGoblinWithoutCounters.summoningSick += amount;
        }

        await existingGoblinWithoutCounters.save();

        // Fire ETB event for Cathar's Crusade and other listeners
        GameEvents.instance.notifyCreatureEntered(existingGoblinWithoutCounters, amount);

        _errorMessage = null;
        notifyListeners();
        debugPrint('TokenProvider.createKrenkoGoblins: Successfully added $amount Goblins to existing stack');
      } else {
        // Step 3: Create new stack from database definition
        debugPrint('TokenProvider.createKrenkoGoblins: Creating new stack with $amount goblins at order $insertionOrder');

        // Create new item with database values and default artwork
        final shouldBeSummoningSick = summoningSicknessEnabled && !goblinDefinition.abilities.toLowerCase().contains('haste');

        final newGoblin = Item(
          name: goblinDefinition.name,
          pt: goblinDefinition.pt,
          abilities: goblinDefinition.abilities,
          colors: goblinDefinition.colors,
          type: goblinDefinition.type,
          amount: amount,
          tapped: 0,
          summoningSick: shouldBeSummoningSick ? amount : 0,
          order: insertionOrder,
          artworkUrl: goblinDefinition.artwork.isNotEmpty ? goblinDefinition.artwork.first.url : null,
          artworkSet: goblinDefinition.artwork.isNotEmpty ? goblinDefinition.artwork.first.set : null,
          artworkOptions: goblinDefinition.artwork.isNotEmpty ? List.from(goblinDefinition.artwork) : null,
        );

        // insertItem handles ETB events and notifyListeners automatically
        await insertItem(newGoblin);

        debugPrint('TokenProvider.createKrenkoGoblins: Successfully created new stack with $amount Goblins (${goblinDefinition.artwork.length} artwork options available)');
      }
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating Goblin tokens: Changes could not be saved.';
      debugPrint('TokenProvider.createKrenkoGoblins: HiveError. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating Goblin tokens: ${e.toString()}';
      debugPrint('TokenProvider.createKrenkoGoblins: Unexpected error. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  /// Creates Academy Manufactor tokens (Clue, Food, Treasure) with stacking behavior
  ///
  /// This method:
  /// 1. Loads Clue, Food, Treasure definitions from token database (cached for performance)
  /// 2. For each type: checks for existing matching stack without counters
  /// 3. Either adds to existing stack or creates new stack at specified order
  /// 4. Does NOT fire ETB events (these are artifacts without P/T)
  ///
  /// [amountPerType] - Number of tokens to create for each type
  /// [summoningSicknessEnabled] - Whether summoning sickness is enabled (not applied to these artifacts)
  /// [insertionOrder] - The order value for new tokens (should be calculated from all board items)
  Future<void> createAcademyManufactorTokens(int amountPerType, bool summoningSicknessEnabled, double insertionOrder) async {
    try {
      if (amountPerType <= 0) {
        debugPrint('TokenProvider.createAcademyManufactorTokens: No tokens to create (amount: $amountPerType)');
        return;
      }

      // Step 1: Load token definitions from database (cached for performance)
      if (_clueCache == null || _foodCache == null || _treasureCache == null) {
        final jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);
        final List<dynamic> jsonList = jsonDecode(jsonString);

        if (_clueCache == null) {
          final clueJson = jsonList.firstWhere(
            (json) => (json['name'] as String) == 'Clue',
            orElse: () => throw Exception('Clue not found in token database'),
          );
          _clueCache = TokenDefinition.fromJson(clueJson as Map<String, dynamic>);
        }

        if (_foodCache == null) {
          final foodJson = jsonList.firstWhere(
            (json) => (json['name'] as String) == 'Food',
            orElse: () => throw Exception('Food not found in token database'),
          );
          _foodCache = TokenDefinition.fromJson(foodJson as Map<String, dynamic>);
        }

        if (_treasureCache == null) {
          final treasureJson = jsonList.firstWhere(
            (json) => (json['name'] as String) == 'Treasure',
            orElse: () => throw Exception('Treasure not found in token database'),
          );
          _treasureCache = TokenDefinition.fromJson(treasureJson as Map<String, dynamic>);
        }
      }

      // Step 2: Create each token type
      final tokenTypes = [
        ('Clue', _clueCache!),
        ('Food', _foodCache!),
        ('Treasure', _treasureCache!),
      ];

      double currentOrder = insertionOrder;

      for (final (typeName, definition) in tokenTypes) {
        // Check for existing matching stack without counters
        final existingStack = items.firstWhere(
          (item) {
            final isMatching = item.name == definition.name &&
                item.pt == definition.pt &&
                item.colors == definition.colors &&
                item.abilities == definition.abilities;

            final hasNoCounters = item.plusOneCounters == 0 &&
                item.minusOneCounters == 0 &&
                item.counters.isEmpty;

            return isMatching && hasNoCounters;
          },
          orElse: () => Item(name: '', pt: '', abilities: '', colors: '', type: ''), // Sentinel value
        );

        if (existingStack.name.isNotEmpty) {
          // Add to existing stack
          debugPrint('TokenProvider.createAcademyManufactorTokens: Adding $amountPerType $typeName to existing stack');
          existingStack.amount += amountPerType;

          // No summoning sickness for artifacts without P/T
          await existingStack.save();

          _errorMessage = null;
          notifyListeners();
          debugPrint('TokenProvider.createAcademyManufactorTokens: Successfully added $amountPerType $typeName to existing stack');
        } else {
          // Create new stack from database definition
          debugPrint('TokenProvider.createAcademyManufactorTokens: Creating new $typeName stack with $amountPerType at order $currentOrder');

          final newToken = Item(
            name: definition.name,
            pt: definition.pt,
            abilities: definition.abilities,
            colors: definition.colors,
            type: definition.type,
            amount: amountPerType,
            tapped: 0,
            summoningSick: 0, // Artifacts without P/T - no summoning sickness
            order: currentOrder,
            artworkUrl: definition.artwork.isNotEmpty ? definition.artwork.first.url : null,
            artworkSet: definition.artwork.isNotEmpty ? definition.artwork.first.set : null,
            artworkOptions: definition.artwork.isNotEmpty ? List.from(definition.artwork) : null,
          );

          // Use insertItemWithExplicitOrder to avoid overriding order
          // and skip ETB events (these are artifacts, no P/T)
          await _itemsBox.add(newToken);
          _errorMessage = null;
          notifyListeners();

          currentOrder += 1.0;

          debugPrint('TokenProvider.createAcademyManufactorTokens: Successfully created new stack with $amountPerType $typeName');
        }
      }
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating Academy Manufactor tokens: Changes could not be saved.';
      debugPrint('TokenProvider.createAcademyManufactorTokens: HiveError. Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating Academy Manufactor tokens: ${e.toString()}';
      debugPrint('TokenProvider.createAcademyManufactorTokens: Unexpected error. Error: $e');
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
      // Fire board wipe event to reset Cathar's counters
      GameEvents.instance.notifyBoardWiped();

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

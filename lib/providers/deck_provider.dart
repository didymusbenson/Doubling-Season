import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/deck.dart';
import '../models/token_definition.dart';
import '../models/token_template.dart';
import '../models/tracker_widget_template.dart';
import '../models/toggle_widget_template.dart';
import '../providers/token_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';
import '../utils/constants.dart';

// Helper class for preserving exact order when loading decks
class _TemplateForLoad {
  final dynamic template; // TokenTemplate, TrackerWidgetTemplate, or ToggleWidgetTemplate
  final double order;
  final String type; // 'token', 'tracker', 'toggle'

  _TemplateForLoad(this.template, this.order, this.type);
}

class DeckProvider extends ChangeNotifier {
  late Box<Deck> _decksBox;
  bool _initialized = false;

  bool get initialized => _initialized;

  /// Expose Hive's listenable for reactive UI via ValueListenableBuilder
  ValueListenable<Box<Deck>> get listenable => _decksBox.listenable();

  Future<void> init() async {
    _decksBox = Hive.box<Deck>(DatabaseConstants.decksBox);
    _initialized = true;
    migrateExistingDecks();
    notifyListeners();
  }

  /// Returns all decks sorted by order
  List<Deck> get decks {
    final allDecks = _decksBox.values.toList();
    allDecks.sort((a, b) => a.order.compareTo(b.order));
    return allDecks;
  }

  /// Save a new deck to the box
  Future<void> saveDeck(Deck deck) async {
    // Set timestamps
    deck.createdAt = DateTime.now();
    deck.lastModifiedAt = DateTime.now();

    // Assign order = max + 1
    final allDecks = _decksBox.values.toList();
    if (allDecks.isEmpty) {
      deck.order = 0.0;
    } else {
      final maxOrder = allDecks.map((d) => d.order).reduce(max);
      deck.order = maxOrder.floor() + 1.0;
    }

    await _decksBox.add(deck);
    notifyListeners();
    debugPrint('DeckProvider: Saved deck "${deck.name}" with ${deck.templates.length} tokens, order=${deck.order}');
  }

  Future<void> deleteDeck(Deck deck) async {
    final name = deck.name;
    await deck.delete();
    notifyListeners();
    debugPrint('DeckProvider: Deleted deck "$name"');
  }

  /// Reorder decks using fractional order pattern
  void reorderDecks(int oldIndex, int newIndex) {
    final deckList = decks; // already sorted by order
    final movingDown = newIndex > oldIndex;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final deck = deckList[oldIndex];

    double newOrder;
    if (newIndex == 0) {
      newOrder = deckList.first.order - 1.0;
    } else if (newIndex == deckList.length - 1) {
      newOrder = deckList.last.order + 1.0;
    } else {
      if (movingDown) {
        final prevOrder = deckList[newIndex].order;
        final nextOrder = deckList[newIndex + 1].order;
        newOrder = (prevOrder + nextOrder) / 2.0;
      } else {
        final prevOrder = deckList[newIndex - 1].order;
        final nextOrder = deckList[newIndex].order;
        newOrder = (prevOrder + nextOrder) / 2.0;
      }
    }

    deck.order = newOrder;
    deck.save();

    // Check and compact if needed
    _checkAndCompactDeckOrders(decks);

    notifyListeners();
    debugPrint('DeckProvider: Reordered deck "${deck.name}" to order=$newOrder');
  }

  void _checkAndCompactDeckOrders(List<Deck> deckList) {
    deckList.sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < deckList.length - 1; i++) {
      if ((deckList[i + 1].order - deckList[i].order) < 0.001) {
        _compactDeckOrders(deckList);
        debugPrint('DeckProvider: Compacted deck orders');
        return;
      }
    }
  }

  void _compactDeckOrders(List<Deck> deckList) {
    deckList.sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < deckList.length; i++) {
      deckList[i].order = i.toDouble();
      deckList[i].save();
    }
  }

  /// Duplicate a deck with auto-renamed name
  Future<Deck> duplicateDeck(Deck original) async {
    // Auto-rename: "Name" -> "Name (2)", "Name (2)" -> "Name (3)", etc.
    final newName = _generateUniqueName(original.name);

    // Deep-copy templates
    final newTemplates = original.templates.map((t) => TokenTemplate(
      name: t.name,
      pt: t.pt,
      abilities: t.abilities,
      colors: t.colors,
      type: t.type,
      order: t.order,
      artworkUrl: t.artworkUrl,
      artworkSet: t.artworkSet,
      artworkOptions: t.artworkOptions != null ? List.from(t.artworkOptions!) : null,
    )).toList();

    final newTrackers = original.trackerWidgets?.map((t) => TrackerWidgetTemplate(
      name: t.name,
      description: t.description,
      colorIdentity: t.colorIdentity,
      artworkUrl: t.artworkUrl,
      artworkSet: t.artworkSet,
      artworkOptions: t.artworkOptions != null ? List.from(t.artworkOptions!) : null,
      defaultValue: t.defaultValue,
      tapIncrement: t.tapIncrement,
      longPressIncrement: t.longPressIncrement,
      hasAction: t.hasAction,
      actionButtonText: t.actionButtonText,
      actionType: t.actionType,
      isCustom: t.isCustom,
      order: t.order,
    )).toList();

    final newToggles = original.toggleWidgets?.map((t) => ToggleWidgetTemplate(
      name: t.name,
      colorIdentity: t.colorIdentity,
      artworkUrl: t.artworkUrl,
      artworkSet: t.artworkSet,
      artworkOptions: t.artworkOptions != null ? List.from(t.artworkOptions!) : null,
      onDescription: t.onDescription,
      offDescription: t.offDescription,
      onArtworkUrl: t.onArtworkUrl,
      offArtworkUrl: t.offArtworkUrl,
      isCustom: t.isCustom,
      order: t.order,
    )).toList();

    final allDecks = _decksBox.values.toList();
    final maxOrder = allDecks.isEmpty ? 0.0 : allDecks.map((d) => d.order).reduce(max);

    final newDeck = Deck(
      name: newName,
      templates: newTemplates,
      trackerWidgets: newTrackers,
      toggleWidgets: newToggles,
      colorIdentity: original.colorIdentity,
      order: maxOrder.floor() + 1.0,
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      customArtworkUrl: original.customArtworkUrl,
    );

    await _decksBox.add(newDeck);
    notifyListeners();
    debugPrint('DeckProvider: Duplicated deck "${original.name}" as "$newName"');
    return newDeck;
  }

  /// Generate a unique name like "Name (2)", "Name (3)", etc.
  String _generateUniqueName(String baseName) {
    final existingNames = _decksBox.values.map((d) => d.name).toSet();

    // Strip existing suffix like " (2)" to get base
    final suffixPattern = RegExp(r' \((\d+)\)$');
    final match = suffixPattern.firstMatch(baseName);
    final cleanBase = match != null ? baseName.substring(0, match.start) : baseName;

    int counter = 2;
    String candidate = '$cleanBase ($counter)';
    while (existingNames.contains(candidate)) {
      counter++;
      candidate = '$cleanBase ($counter)';
    }
    return candidate;
  }

  /// Auto-detect color identity from all contained templates
  String autoDetectColorIdentity(Deck deck) {
    final colors = <String>{};
    for (final template in deck.templates) {
      for (int i = 0; i < template.colors.length; i++) {
        colors.add(template.colors[i]);
      }
    }
    if (deck.trackerWidgets != null) {
      for (final tracker in deck.trackerWidgets!) {
        for (int i = 0; i < tracker.colorIdentity.length; i++) {
          colors.add(tracker.colorIdentity[i]);
        }
      }
    }
    if (deck.toggleWidgets != null) {
      for (final toggle in deck.toggleWidgets!) {
        for (int i = 0; i < toggle.colorIdentity.length; i++) {
          colors.add(toggle.colorIdentity[i]);
        }
      }
    }

    // Return in WUBRG order
    final orderedColors = StringBuffer();
    for (final c in ['W', 'U', 'B', 'R', 'G']) {
      if (colors.contains(c)) orderedColors.write(c);
    }
    return orderedColors.toString();
  }

  /// Resolve the artwork URL for a deck: custom art first, else first template with artwork
  static String? resolveArtworkUrl(Deck deck) {
    if (deck.customArtworkUrl != null && deck.customArtworkUrl!.isNotEmpty) {
      return deck.customArtworkUrl;
    }

    // Collect all templates sorted by order, find first with artworkUrl
    final allTemplates = <({double order, String? artworkUrl})>[];
    for (final t in deck.templates) {
      allTemplates.add((order: t.order, artworkUrl: t.artworkUrl));
    }
    if (deck.trackerWidgets != null) {
      for (final t in deck.trackerWidgets!) {
        allTemplates.add((order: t.order, artworkUrl: t.artworkUrl));
      }
    }
    if (deck.toggleWidgets != null) {
      for (final t in deck.toggleWidgets!) {
        allTemplates.add((order: t.order, artworkUrl: t.artworkUrl));
      }
    }
    allTemplates.sort((a, b) => a.order.compareTo(b.order));

    for (final t in allTemplates) {
      if (t.artworkUrl != null && t.artworkUrl!.isNotEmpty) {
        return t.artworkUrl;
      }
    }
    return null;
  }

  /// Export a deck to pretty-printed JSON with metadata
  Future<String> exportDeckToJson(Deck deck) async {
    final packageInfo = await PackageInfo.fromPlatform();

    final Map<String, dynamic> exportData = {
      'schemaVersion': 2,
      'appVersion': packageInfo.version,
      'exportDate': DateTime.now().toIso8601String(),
      'deck': {
        'name': deck.name,
        'colorIdentity': deck.colorIdentity,
        'templates': deck.templates.map((t) => {
          'name': t.name,
          'pt': t.pt,
          'abilities': t.abilities,
          'colors': t.colors,
          'type': t.type,
          'order': t.order,
          'artworkUrl': t.artworkUrl,
          'artworkSet': t.artworkSet,
          'artworkOptions': t.artworkOptions?.map((a) => a.toJson()).toList(),
        }).toList(),
        'trackerWidgets': deck.trackerWidgets?.map((t) => {
          'name': t.name,
          'description': t.description,
          'colorIdentity': t.colorIdentity,
          'defaultValue': t.defaultValue,
          'tapIncrement': t.tapIncrement,
          'longPressIncrement': t.longPressIncrement,
          'hasAction': t.hasAction,
          'actionButtonText': t.actionButtonText,
          'actionType': t.actionType,
          'isCustom': t.isCustom,
          'order': t.order,
          'artworkUrl': t.artworkUrl,
          'artworkSet': t.artworkSet,
          'artworkOptions': t.artworkOptions?.map((a) => a.toJson()).toList(),
        }).toList(),
        'toggleWidgets': deck.toggleWidgets?.map((t) => {
          'name': t.name,
          'colorIdentity': t.colorIdentity,
          'onDescription': t.onDescription,
          'offDescription': t.offDescription,
          'isCustom': t.isCustom,
          'order': t.order,
          'artworkUrl': t.artworkUrl,
          'artworkSet': t.artworkSet,
          'artworkOptions': t.artworkOptions?.map((a) => a.toJson()).toList(),
          'onArtworkUrl': t.onArtworkUrl,
          'offArtworkUrl': t.offArtworkUrl,
        }).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    debugPrint('DeckProvider: Exported deck "${deck.name}" (${deck.templates.length} tokens, schema v2)');
    return jsonString;
  }

  /// Import a deck from JSON string. Returns the imported deck or throws on error.
  Future<Deck> importDeckFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Validate schema version
      final schemaVersion = data['schemaVersion'] as int?;
      if (schemaVersion == null) {
        throw FormatException('Missing schemaVersion in imported file');
      }
      if (schemaVersion > 2) {
        throw FormatException('Unsupported schema version $schemaVersion. Please update the app.');
      }
      debugPrint('DeckProvider: Import - schema version $schemaVersion');

      final deckData = data['deck'] as Map<String, dynamic>?;
      if (deckData == null) {
        throw FormatException('Missing deck data in imported file');
      }

      // Parse templates
      final templatesJson = deckData['templates'] as List<dynamic>? ?? [];
      final templates = templatesJson.map((t) {
        final map = t as Map<String, dynamic>;
        final artworkOptionsJson = map['artworkOptions'] as List<dynamic>?;
        final artworkOptions = artworkOptionsJson
            ?.map((a) => ArtworkVariant.fromJson(a as Map<String, dynamic>))
            .toList();
        return TokenTemplate(
          name: map['name'] as String? ?? '',
          pt: map['pt'] as String? ?? '',
          abilities: map['abilities'] as String? ?? '',
          colors: map['colors'] as String? ?? '',
          type: map['type'] as String? ?? '',
          order: (map['order'] as num?)?.toDouble() ?? 0.0,
          artworkUrl: map['artworkUrl'] as String?,
          artworkSet: map['artworkSet'] as String?,
          artworkOptions: artworkOptions,
        );
      }).toList();

      // Parse tracker widgets
      List<TrackerWidgetTemplate>? trackerTemplates;
      final trackersJson = deckData['trackerWidgets'] as List<dynamic>?;
      if (trackersJson != null && trackersJson.isNotEmpty) {
        trackerTemplates = trackersJson.map((t) {
          final map = t as Map<String, dynamic>;
          final artworkOptionsJson = map['artworkOptions'] as List<dynamic>?;
          final artworkOptions = artworkOptionsJson
              ?.map((a) => ArtworkVariant.fromJson(a as Map<String, dynamic>))
              .toList();
          return TrackerWidgetTemplate(
            name: map['name'] as String? ?? '',
            description: map['description'] as String? ?? '',
            colorIdentity: map['colorIdentity'] as String? ?? '',
            defaultValue: map['defaultValue'] as int? ?? 0,
            tapIncrement: map['tapIncrement'] as int? ?? 1,
            longPressIncrement: map['longPressIncrement'] as int? ?? 5,
            hasAction: map['hasAction'] as bool? ?? false,
            actionButtonText: map['actionButtonText'] as String?,
            actionType: map['actionType'] as String?,
            isCustom: map['isCustom'] as bool? ?? false,
            order: (map['order'] as num?)?.toDouble() ?? 0.0,
            artworkUrl: map['artworkUrl'] as String?,
            artworkSet: map['artworkSet'] as String?,
            artworkOptions: artworkOptions,
          );
        }).toList();
      }

      // Parse toggle widgets
      List<ToggleWidgetTemplate>? toggleTemplates;
      final togglesJson = deckData['toggleWidgets'] as List<dynamic>?;
      if (togglesJson != null && togglesJson.isNotEmpty) {
        toggleTemplates = togglesJson.map((t) {
          final map = t as Map<String, dynamic>;
          final artworkOptionsJson = map['artworkOptions'] as List<dynamic>?;
          final artworkOptions = artworkOptionsJson
              ?.map((a) => ArtworkVariant.fromJson(a as Map<String, dynamic>))
              .toList();
          return ToggleWidgetTemplate(
            name: map['name'] as String? ?? '',
            colorIdentity: map['colorIdentity'] as String? ?? '',
            onDescription: map['onDescription'] as String? ?? '',
            offDescription: map['offDescription'] as String? ?? '',
            isCustom: map['isCustom'] as bool? ?? false,
            order: (map['order'] as num?)?.toDouble() ?? 0.0,
            artworkUrl: map['artworkUrl'] as String?,
            artworkSet: map['artworkSet'] as String?,
            artworkOptions: artworkOptions,
            onArtworkUrl: map['onArtworkUrl'] as String?,
            offArtworkUrl: map['offArtworkUrl'] as String?,
          );
        }).toList();
      }

      // Auto-rename if duplicate name
      String deckName = deckData['name'] as String? ?? 'Imported Deck';
      final existingNames = _decksBox.values.map((d) => d.name).toSet();
      if (existingNames.contains(deckName)) {
        deckName = _generateUniqueName(deckName);
        debugPrint('DeckProvider: Import auto-renamed to "$deckName"');
      }

      final allDecks = _decksBox.values.toList();
      final maxOrder = allDecks.isEmpty ? 0.0 : allDecks.map((d) => d.order).reduce(max);

      final deck = Deck(
        name: deckName,
        templates: templates,
        trackerWidgets: trackerTemplates,
        toggleWidgets: toggleTemplates,
        colorIdentity: deckData['colorIdentity'] as String?,
        order: maxOrder.floor() + 1.0,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );

      // Auto-detect color identity if not provided
      if (deck.colorIdentity == null || deck.colorIdentity!.isEmpty) {
        deck.colorIdentity = autoDetectColorIdentity(deck);
      }

      await _decksBox.add(deck);
      notifyListeners();
      debugPrint('DeckProvider: Imported deck "$deckName" with ${templates.length} tokens');
      return deck;
    } on FormatException catch (e) {
      debugPrint('DeckProvider: Import failed - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('DeckProvider: Import failed - $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Migrate existing decks: assign sequential orders where order == 0.0, auto-detect colorIdentity where null
  void migrateExistingDecks() {
    final allDecks = _decksBox.values.toList();
    if (allDecks.isEmpty) return;

    int migratedCount = 0;

    // Assign sequential orders where all are 0.0 (pre-migration decks)
    final needsOrderMigration = allDecks.every((d) => d.order == 0.0) && allDecks.length > 1;
    if (needsOrderMigration) {
      for (int i = 0; i < allDecks.length; i++) {
        allDecks[i].order = i.toDouble();
        allDecks[i].save();
      }
      debugPrint('DeckProvider: Migrated ${allDecks.length} decks with sequential orders');
      migratedCount += allDecks.length;
    }

    // Auto-detect colorIdentity where null
    for (final deck in allDecks) {
      if (deck.colorIdentity == null) {
        deck.colorIdentity = autoDetectColorIdentity(deck);
        deck.save();
        debugPrint('DeckProvider: Migrated deck "${deck.name}" colorIdentity="${deck.colorIdentity}"');
        migratedCount++;
      }
    }

    if (migratedCount > 0) {
      debugPrint('DeckProvider: Migration complete - $migratedCount decks updated');
    }
  }

  /// Load a deck to the board, clearing existing items first
  Future<void> loadDeckClearBoard(
    Deck deck,
    TokenProvider tokenProvider,
    TrackerProvider trackerProvider,
    ToggleProvider toggleProvider,
  ) async {
    debugPrint('DeckProvider: Loading deck "${deck.name}" (clear & load, ${deck.templates.length} tokens)');

    await tokenProvider.boardWipeDelete();
    await trackerProvider.deleteAll();
    await toggleProvider.deleteAll();

    await _loadDeckItems(tokenProvider, trackerProvider, toggleProvider, deck, startOrder: 0.0);
  }

  /// Load a deck to the board, adding to existing items
  Future<void> loadDeckAddToBoard(
    Deck deck,
    TokenProvider tokenProvider,
    TrackerProvider trackerProvider,
    ToggleProvider toggleProvider,
  ) async {
    debugPrint('DeckProvider: Loading deck "${deck.name}" (add to board, ${deck.templates.length} tokens)');

    // Find max order across all board items
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((i) => i.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce(max);

    await _loadDeckItems(tokenProvider, trackerProvider, toggleProvider, deck, startOrder: maxOrder.floor() + 1.0);
  }

  /// Internal: load deck items into the board at the given starting order
  Future<void> _loadDeckItems(
    TokenProvider tokenProvider,
    TrackerProvider trackerProvider,
    ToggleProvider toggleProvider,
    Deck deck, {
    required double startOrder,
  }) async {
    // Collect all templates with their orders to preserve exact sequence
    final allTemplates = <_TemplateForLoad>[];

    for (final template in deck.templates) {
      allTemplates.add(_TemplateForLoad(template, template.order, 'token'));
    }

    if (deck.trackerWidgets != null) {
      for (final template in deck.trackerWidgets!) {
        allTemplates.add(_TemplateForLoad(template, template.order, 'tracker'));
      }
    }

    if (deck.toggleWidgets != null) {
      for (final template in deck.toggleWidgets!) {
        allTemplates.add(_TemplateForLoad(template, template.order, 'toggle'));
      }
    }

    // Sort by order to restore exact board sequence
    allTemplates.sort((a, b) => a.order.compareTo(b.order));

    // Load items in order
    for (int i = 0; i < allTemplates.length; i++) {
      final templateItem = allTemplates[i];
      final newOrder = startOrder + i.toDouble();

      if (templateItem.type == 'token') {
        final template = templateItem.template as TokenTemplate;
        final item = template.toItem(
          amount: 0, // Initialize with 0 tokens (user adds as needed)
          createTapped: false,
        );
        item.order = newOrder;
        await tokenProvider.insertItemWithExplicitOrder(item);
      } else if (templateItem.type == 'tracker') {
        final template = templateItem.template as TrackerWidgetTemplate;
        final widget = template.toWidget(customOrder: newOrder);
        await trackerProvider.insertTrackerWithExplicitOrder(widget);
      } else if (templateItem.type == 'toggle') {
        final template = templateItem.template as ToggleWidgetTemplate;
        final widget = template.toWidget(customOrder: newOrder);
        await toggleProvider.insertToggleWithExplicitOrder(widget);
      }
    }

    debugPrint('DeckProvider: Loaded ${allTemplates.length} items from deck "${deck.name}"');
  }

  @override
  void dispose() {
    _decksBox.close();
    super.dispose();
  }
}

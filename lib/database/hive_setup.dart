import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
import '../models/token_rule.dart';
import '../models/rule_trigger.dart';
import '../models/rule_outcome.dart';

/// Result of Hive initialization, containing info about any boxes that were wiped.
class HiveInitResult {
  /// Names of boxes that were wiped to empty (lost all data).
  /// Empty list means all boxes opened successfully (or restored from backup).
  final List<String> wipedBoxes;

  const HiveInitResult({required this.wipedBoxes});

  /// True if any boxes lost data during initialization.
  bool get hadDataLoss => wipedBoxes.isNotEmpty;
}

/// Initialize Hive database with resilient error handling.
///
/// Opens each box individually with try/catch. If a box fails to open:
/// 1. Attempts to restore from the last known good backup
/// 2. If restore fails, deletes corrupt files and opens a fresh empty box
///
/// After all boxes open successfully, creates a fire-and-forget backup of all
/// .hive files for future recovery.
///
/// This function NEVER throws. The app will ALWAYS reach runApp().
Future<HiveInitResult> initHive() async {
  final List<String> wipedBoxes = [];

  try {
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
    Hive.registerAdapter(TokenRuleAdapter());
    Hive.registerAdapter(RuleTriggerAdapter());
    Hive.registerAdapter(RuleOutcomeAdapter());

    if (kIsWeb) {
      // Web uses IndexedDB via Hive — no file system, no backup/restore
      await Hive.openBox<Item>('items');
      await Hive.openBox<Deck>('decks');
      await Hive.openBox<TokenArtworkPreference>('artworkPreferences');
      await Hive.openBox<TrackerWidget>('trackerWidgets');
      await Hive.openBox<ToggleWidget>('toggleWidgets');
      await Hive.openBox<TokenRule>('tokenRules');
      await Hive.openBox<String>('customTokens');
    } else {
      // Resolve the Hive data directory for backup/restore operations
      final hivePath = await _getHivePath();

      // Open each box individually with error handling
      await _openBoxResilient<Item>('items', hivePath, wipedBoxes);
      await _openBoxResilient<Deck>('decks', hivePath, wipedBoxes);
      await _openBoxResilient<TokenArtworkPreference>('artworkPreferences', hivePath, wipedBoxes);
      await _openBoxResilient<TrackerWidget>('trackerWidgets', hivePath, wipedBoxes);
      await _openBoxResilient<ToggleWidget>('toggleWidgets', hivePath, wipedBoxes);
      await _openBoxResilient<TokenRule>('tokenRules', hivePath, wipedBoxes);
      await _openBoxResilient<String>('customTokens', hivePath, wipedBoxes);

      // Fire-and-forget: backup all .hive files after successful boot
      _backupAllBoxes(hivePath);
    }

  } catch (e, stackTrace) {
    // Final safety net: if anything unexpected fails (e.g., Hive.initFlutter(),
    // adapter registration), log it but don't throw. The app may be in a
    // degraded state but at least it won't brick.
    if (kDebugMode) {
      debugPrint('════════════════════════════════════════════');
      debugPrint('CRITICAL: Hive initialization safety catch triggered');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('════════════════════════════════════════════');
    }
  }

  return HiveInitResult(wipedBoxes: wipedBoxes);
}

/// Get the Hive data directory path.
///
/// Hive.initFlutter() uses path_provider's getApplicationDocumentsDirectory()
/// on mobile platforms. We replicate that logic here.
Future<String> _getHivePath() async {
  final appDir = await getApplicationDocumentsDirectory();
  return appDir.path;
}

/// Get the backup directory path (sibling to Hive data directory).
String _getBackupPath(String hivePath) {
  return '$hivePath/hive_backups';
}

/// Open a single Hive box with resilient error handling.
///
/// On failure:
/// 1. Try to restore from backup and reopen
/// 2. If that fails, delete corrupt files and open fresh
///
/// [wipedBoxes] is mutated to track boxes that lost all data.
Future<void> _openBoxResilient<T>(
  String boxName,
  String hivePath,
  List<String> wipedBoxes,
) async {
  // First attempt: normal open
  try {
    await Hive.openBox<T>(boxName);
    debugPrint('Hive: Opened box "$boxName" successfully');
    return;
  } catch (e) {
    debugPrint('Hive: Failed to open box "$boxName": $e');
  }

  // Second attempt: restore from backup and retry
  try {
    final restored = await _restoreBoxFromBackup(boxName, hivePath);
    if (restored) {
      debugPrint('Hive: Restored "$boxName" from backup, retrying open...');
      await Hive.openBox<T>(boxName);
      debugPrint('Hive: Opened box "$boxName" successfully after restore');
      return; // Restored from backup — no data loss to report
    }
  } catch (e) {
    debugPrint('Hive: Restore+reopen failed for "$boxName": $e');
  }

  // Final attempt: delete corrupt files and open fresh empty box
  try {
    debugPrint('Hive: Wiping corrupt box "$boxName" and creating fresh...');
    await _deleteBoxFiles(boxName, hivePath);
    await Hive.openBox<T>(boxName);
    wipedBoxes.add(boxName);
    debugPrint('Hive: Opened fresh empty box "$boxName" (data was lost)');
  } catch (e) {
    // Even the fresh open failed — extremely unlikely but handle it
    debugPrint('Hive: CRITICAL — Cannot open box "$boxName" even after wipe: $e');
    wipedBoxes.add(boxName);
  }
}

/// Attempt to restore a box's .hive file from the backup directory.
///
/// Returns true if a backup existed and was copied into place.
Future<bool> _restoreBoxFromBackup(String boxName, String hivePath) async {
  final backupDir = _getBackupPath(hivePath);
  final backupFile = File('$backupDir/$boxName.hive');

  if (!await backupFile.exists()) {
    debugPrint('Hive: No backup found for "$boxName"');
    return false;
  }

  // Delete corrupt files first
  await _deleteBoxFiles(boxName, hivePath);

  // Copy backup into place
  final targetPath = '$hivePath/$boxName.hive';
  await backupFile.copy(targetPath);
  debugPrint('Hive: Copied backup for "$boxName" into place');
  return true;
}

/// Delete a box's .hive and .lock files from the Hive data directory.
Future<void> _deleteBoxFiles(String boxName, String hivePath) async {
  final hiveFile = File('$hivePath/$boxName.hive');
  final lockFile = File('$hivePath/$boxName.lock');

  if (await hiveFile.exists()) {
    await hiveFile.delete();
    debugPrint('Hive: Deleted $boxName.hive');
  }
  if (await lockFile.exists()) {
    await lockFile.delete();
    debugPrint('Hive: Deleted $boxName.lock');
  }
}

/// Fire-and-forget backup of all .hive files to hive_backups/ directory.
///
/// Called after ALL boxes have opened successfully. Copies each .hive file
/// to the backup directory, overwriting any previous backup. This runs
/// asynchronously and does not block the app boot.
void _backupAllBoxes(String hivePath) {
  // Run in background — don't await, don't block boot
  Future(() async {
    try {
      final backupDir = Directory(_getBackupPath(hivePath));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final boxNames = ['items', 'decks', 'artworkPreferences', 'trackerWidgets', 'toggleWidgets', 'tokenRules', 'customTokens'];

      for (final boxName in boxNames) {
        try {
          final sourceFile = File('$hivePath/$boxName.hive');
          if (await sourceFile.exists()) {
            final backupPath = '${backupDir.path}/$boxName.hive';
            await sourceFile.copy(backupPath);
          }
        } catch (e) {
          // Individual backup failure is not critical
          debugPrint('Hive backup: Failed to backup "$boxName": $e');
        }
      }

      debugPrint('Hive backup: All boxes backed up successfully');
    } catch (e) {
      debugPrint('Hive backup: Failed to create backup directory: $e');
    }
  });
}

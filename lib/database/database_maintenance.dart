import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';

/// Service for maintaining database health through periodic compaction.
///
/// Hive databases accumulate "dead space" from deleted entries. Compaction
/// rewrites the database file to reclaim this space, improving performance
/// and reducing storage footprint.
///
/// This is especially important for the items box which experiences high churn:
/// players frequently create and delete tokens during gameplay, leading to
/// significant dead space accumulation over time.
class DatabaseMaintenanceService {
  static const String _lastCompactKey = 'lastDatabaseCompactionDate';
  static const int _compactionIntervalDays = 7; // Run weekly

  /// Checks if compaction is needed and performs it if the interval has elapsed.
  ///
  /// This method is safe to call on every app startup - it only performs
  /// compaction once per week. The operation is atomic and cannot corrupt data.
  ///
  /// Typical performance:
  /// - Small databases (<100KB): 10-50ms
  /// - Medium databases (100KB-1MB): 50-200ms
  /// - Large databases (1MB+): 200-500ms
  ///
  /// Returns true if compaction was performed, false otherwise.
  static Future<bool> compactIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCompactTimestamp = prefs.getInt(_lastCompactKey) ?? 0;
      final lastCompactDate = DateTime.fromMillisecondsSinceEpoch(lastCompactTimestamp);
      final now = DateTime.now();
      final daysSinceLastCompact = now.difference(lastCompactDate).inDays;

      // Check if compaction interval has elapsed
      if (daysSinceLastCompact < _compactionIntervalDays) {
        debugPrint(
          'DatabaseMaintenance: Skipping compaction - last run was $daysSinceLastCompact days ago '
          '(threshold: $_compactionIntervalDays days)',
        );
        return false;
      }

      // Perform compaction on items box (high churn from gameplay)
      debugPrint(
        'DatabaseMaintenance: Starting compaction - last run was $daysSinceLastCompact days ago. '
        'This may take 100-500ms depending on database size.',
      );

      final itemsBox = Hive.box<Item>('items');
      final itemCount = itemsBox.length;

      final stopwatch = Stopwatch()..start();
      await itemsBox.compact();
      stopwatch.stop();

      // Record successful compaction
      await prefs.setInt(_lastCompactKey, now.millisecondsSinceEpoch);

      debugPrint(
        'DatabaseMaintenance: Successfully compacted items box in ${stopwatch.elapsedMilliseconds}ms. '
        'Current active items: $itemCount. Dead space has been reclaimed.',
      );

      return true;
    } on HiveError catch (e) {
      // Compaction failed but this is non-critical - app continues normally
      debugPrint(
        'DatabaseMaintenance: HiveError during compaction - operation skipped. '
        'This can happen if storage is full or database is locked. '
        'Error: ${e.message}',
      );
      return false;
    } catch (e, stackTrace) {
      // Unexpected error during compaction - log but don't crash
      debugPrint(
        'DatabaseMaintenance: Unexpected error during compaction - operation skipped. '
        'App will continue normally. Error: $e',
      );
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Manually triggers compaction regardless of interval.
  ///
  /// Useful for a "Clear Cache" or "Optimize Storage" button in settings.
  /// Returns true if successful, false on error.
  static Future<bool> forceCompact() async {
    try {
      debugPrint('DatabaseMaintenance: Manual compaction requested by user');

      final itemsBox = Hive.box<Item>('items');
      final itemCount = itemsBox.length;

      final stopwatch = Stopwatch()..start();
      await itemsBox.compact();
      stopwatch.stop();

      // Update last compaction date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCompactKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint(
        'DatabaseMaintenance: Manual compaction completed in ${stopwatch.elapsedMilliseconds}ms. '
        'Active items: $itemCount',
      );

      return true;
    } on HiveError catch (e) {
      debugPrint('DatabaseMaintenance: HiveError during manual compaction. Error: ${e.message}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('DatabaseMaintenance: Unexpected error during manual compaction. Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Gets the number of days since last compaction.
  /// Returns null if compaction has never run.
  static Future<int?> getDaysSinceLastCompaction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCompactTimestamp = prefs.getInt(_lastCompactKey);

      if (lastCompactTimestamp == null) {
        return null; // Never compacted
      }

      final lastCompactDate = DateTime.fromMillisecondsSinceEpoch(lastCompactTimestamp);
      final now = DateTime.now();
      return now.difference(lastCompactDate).inDays;
    } catch (e) {
      debugPrint('DatabaseMaintenance: Error checking last compaction date. Error: $e');
      return null;
    }
  }
}

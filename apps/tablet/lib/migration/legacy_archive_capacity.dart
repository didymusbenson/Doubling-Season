import 'dart:io';

import 'legacy_migration_recovery.dart';

/// Explicit, retain-all capacity policy for a source archive, not a lease on
/// free space. The host must budget conversion separately; capture may never
/// consume that headroom. No duration, expiry or automatic cleanup is implied.
///
/// Every physical byte already in the archive counts, including failed attempts.
/// The archive checks before writes and before publishing each verified record.
/// Actual write/flush failures still propagate and preserve unfinished evidence.
class LegacyArchiveCapacity {
  static const maxBudgetBytes = 8 * 1024 * 1024 * 1024;
  final Future<int?> Function(Directory destination) availableBytes;
  final int maxArchiveBytes;
  final int conversionReserveBytes;
  final int safetyReserveBytes;

  LegacyArchiveCapacity({
    required this.availableBytes,
    required this.maxArchiveBytes,
    required this.conversionReserveBytes,
    this.safetyReserveBytes = 64 * 1024 * 1024,
  }) {
    if (maxArchiveBytes < 1 ||
        maxArchiveBytes > maxBudgetBytes ||
        conversionReserveBytes < 1 ||
        conversionReserveBytes > maxBudgetBytes ||
        safetyReserveBytes < 1 ||
        safetyReserveBytes > maxBudgetBytes) {
      throw ArgumentError(
        'Explicit positive archive and reserve budgets required.',
      );
    }
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'retention': 'keep-all-until-explicit-review',
    'maxArchiveBytes': maxArchiveBytes,
    'conversionReserveBytes': conversionReserveBytes,
    'safetyReserveBytes': safetyReserveBytes,
  };

  /// A new archive is charged only for its own planned bytes, never unrelated
  /// files in its parent. The capacity probe receives the actual destination.
  Future<void> checkCreation(Directory parent, int initialBytes) =>
      _check(parent, initialBytes, 0);

  Future<void> checkWrite(Directory archive, int additionalBytes) async {
    var retainedBytes = 0;
    await for (final entry in archive.list(followLinks: false)) {
      if (await FileSystemEntity.type(entry.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Unexpected archive entries require review.');
      }
      final length = await File(entry.path).length();
      if (length > maxArchiveBytes - retainedBytes) {
        throw const LegacyRecoveryCapacityException(
          LegacyRecoveryCapacityFailure.outputLimit,
        );
      }
      retainedBytes += length;
    }
    await _check(archive, additionalBytes, retainedBytes);
  }

  Future<void> _check(
    Directory destination,
    int additional,
    int retained,
  ) async {
    if (additional < 0) throw ArgumentError.value(additional, 'additional');
    if (additional > maxArchiveBytes - retained) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.outputLimit,
      );
    }
    int? available;
    try {
      available = await availableBytes(destination);
    } catch (_) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.unknown,
      );
    }
    if (available == null || available < 0 || available > 0x7fffffffffffffff) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.unknown,
      );
    }
    final reserve = safetyReserveBytes + conversionReserveBytes;
    if (available < reserve || additional > available - reserve) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.insufficient,
      );
    }
  }
}

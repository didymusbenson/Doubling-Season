import 'dart:io';

import 'legacy_archive_capacity.dart';
import 'legacy_migration_recovery.dart';

/// Caller-selected limits for isolated rehearsal writes, not a reservation or
/// production sizing policy. Every retained physical byte counts on every retry.
class LegacyRehearsalCapacity {
  final Future<int?> Function(Directory destination) availableBytes;
  final int maxRetainedBytes;
  final int safetyReserveBytes;

  LegacyRehearsalCapacity({
    required this.availableBytes,
    required this.maxRetainedBytes,
    this.safetyReserveBytes = 64 * 1024 * 1024,
  }) {
    for (final value in [maxRetainedBytes, safetyReserveBytes]) {
      if (value < 1 || value > LegacyArchiveCapacity.maxBudgetBytes) {
        throw ArgumentError('Explicit positive rehearsal limits required.');
      }
    }
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'retention': 'keep-all-until-explicit-review',
    'maxRetainedBytes': maxRetainedBytes,
    'safetyReserveBytes': safetyReserveBytes,
  };

  Future<void> checkCreation(Directory parent, int additional) =>
      _check(parent, additional, 0);

  Future<void> checkWrite(Directory directory, int additional) async {
    var retained = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (await FileSystemEntity.type(entry.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Unexpected rehearsal entries require review.');
      }
      final length = await File(entry.path).length();
      if (length > maxRetainedBytes - retained) {
        throw const LegacyRecoveryCapacityException(
          LegacyRecoveryCapacityFailure.outputLimit,
        );
      }
      retained += length;
    }
    await _check(directory, additional, retained);
  }

  Future<void> _check(Directory directory, int additional, int retained) async {
    if (additional < 0) throw ArgumentError.value(additional, 'additional');
    if (additional > maxRetainedBytes - retained) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.outputLimit,
      );
    }
    int? available;
    try {
      available = await availableBytes(directory);
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
    if (available < safetyReserveBytes ||
        additional > available - safetyReserveBytes) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.insufficient,
      );
    }
  }
}

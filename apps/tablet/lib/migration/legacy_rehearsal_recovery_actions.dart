import 'dart:io';

import '../storage/table_repository.dart';
import 'legacy_migration_coordinator.dart';
import 'legacy_migration_recovery.dart';
import 'legacy_source_reader.dart';

/// Explicit native rehearsal adapter. No production route, source discovery,
/// restore, save destination picker, or original-installation mutation exists.
class LegacyRehearsalRecoveryActions implements LegacyRecoveryActions {
  final LegacyMigrationCoordinator coordinator;
  final Directory? sourceDirectory;
  final LegacySourceLayout layout;
  String? _inspectedTransaction;

  LegacyRehearsalRecoveryActions({
    required this.coordinator,
    required this.layout,
    this.sourceDirectory,
  });

  @override
  Future<LegacyRecoveryReport> inspect() async {
    try {
      final result = await coordinator.inspectRehearsal(
        sourceDirectory: sourceDirectory,
        layout: layout,
      );
      _inspectedTransaction = result.transactionId;
      return _report(result);
    } catch (error) {
      return _failure(error);
    }
  }

  @override
  Future<LegacyRecoveryReport> retry() async {
    // Never trust a stale UI report or an uncertain previous acknowledgement.
    final expected = _inspectedTransaction;
    if (expected == null) return inspect();
    try {
      final checked = await coordinator.inspectRehearsal(
        sourceDirectory: sourceDirectory,
        layout: layout,
      );
      if (checked.transactionId != expected) {
        return LegacyRecoveryReport(
          phase: LegacyRecoveryPhase.blocked,
          transactionId: expected,
          issues: const [
            LegacyRecoveryIssue(
              LegacyRecoveryIssueKind.destinationConflict,
              'The source changed after inspection. Keep both copies and check again.',
            ),
          ],
        );
      }
      if (checked.alreadyPromoted) return _report(checked);
      final promoted = await coordinator.rehearse(
        sourceDirectory: sourceDirectory,
        layout: layout,
        expectedTransactionId: expected,
      );
      return _report(promoted, completed: true);
    } catch (error) {
      return _failure(error);
    }
  }

  @override
  Future<LegacyRecoveryBackup> createBackup() =>
      coordinator.createRecoveryBackup();

  LegacyRecoveryReport _report(
    LegacyMigrationPromotion result, {
    bool completed = false,
  }) => LegacyRecoveryReport(
    phase: completed || result.alreadyPromoted
        ? LegacyRecoveryPhase.completed
        : LegacyRecoveryPhase.ready,
    transactionId: result.transactionId,
    warnings: [
      ...result.warnings,
      'Only an isolated temporary rehearsal was checked. Keep the original '
          'installation and offline copy; temporary files can be removed by the OS.',
    ],
    canRetry: !completed && !result.alreadyPromoted,
  );

  LegacyRecoveryReport _failure(Object error) {
    // Never display raw exception text: it may contain private records/paths.
    final kind = error is FileSystemException
        ? LegacyRecoveryIssueKind.storage
        : error is UnsupportedTableFormat
        ? LegacyRecoveryIssueKind.unsupported
        : LegacyRecoveryIssueKind.integrity;
    return LegacyRecoveryReport(
      phase: LegacyRecoveryPhase.blocked,
      transactionId: _inspectedTransaction,
      issues: [
        LegacyRecoveryIssue(
          kind,
          'The rehearsal could not be verified. All retained files were kept; '
          'save a recovery copy for review before trying a different source or destination.',
        ),
      ],
    );
  }
}

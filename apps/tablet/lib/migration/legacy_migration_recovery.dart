import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// A dormant recovery surface for explicit migration rehearsals. This does not
/// select a production source, start migration at boot, or authorize cutover.
enum LegacyRecoveryPhase { interrupted, blocked, ready, completed }

enum LegacyRecoveryIssueKind {
  storage,
  integrity,
  unsupported,
  missingArtwork,
  destinationConflict,
}

class LegacyRecoveryIssue {
  final LegacyRecoveryIssueKind kind;
  final String message;
  const LegacyRecoveryIssue(this.kind, this.message);

  String get nextStep => switch (kind) {
    LegacyRecoveryIssueKind.storage =>
      'Check available device storage, then check again. Do not clear app data.',
    LegacyRecoveryIssueKind.integrity =>
      'Save a recovery copy and keep the original installation. Do not replace '
          'damaged records with an empty game.',
    LegacyRecoveryIssueKind.unsupported =>
      'Keep this data for a compatible app or mapping update. Repeating this '
          'conversion cannot resolve an unsupported format or utility.',
    LegacyRecoveryIssueKind.missingArtwork =>
      'Keep the original artwork files. Recover the missing or unreadable '
          'files before checking again.',
    LegacyRecoveryIssueKind.destinationConflict =>
      'Keep the existing table. Use a separate rehearsal destination; do not '
          'replace a game that has already progressed.',
  };
}

class LegacyRecoveryReport {
  final LegacyRecoveryPhase phase;
  final String? transactionId;
  final List<LegacyRecoveryIssue> issues;
  final List<String> warnings;
  final bool _canRetry;

  LegacyRecoveryReport({
    required this.phase,
    this.transactionId,
    List<LegacyRecoveryIssue> issues = const [],
    List<String> warnings = const [],
    bool canRetry = false,
  }) : issues = List.unmodifiable(issues),
       warnings = List.unmodifiable(warnings),
       _canRetry = canRetry;

  // A blocked/completed report can never expose an activation override, even
  // if an adapter accidentally marks the report retryable.
  bool get canRetry =>
      _canRetry &&
      issues.isEmpty &&
      (phase == LegacyRecoveryPhase.interrupted ||
          phase == LegacyRecoveryPhase.ready);

  String get title => switch (phase) {
    LegacyRecoveryPhase.interrupted => 'Migration paused',
    LegacyRecoveryPhase.blocked => 'Migration needs attention',
    LegacyRecoveryPhase.ready => 'Ready to retry safely',
    LegacyRecoveryPhase.completed => 'Migration rehearsal verified',
  };

  String get description => switch (phase) {
    LegacyRecoveryPhase.interrupted =>
      'Check the retained records before retrying. An interrupted write may '
          'already have finished; retry must inspect it first.',
    LegacyRecoveryPhase.blocked =>
      'Nothing will be skipped or replaced to finish this migration. Resolve '
          'the issues below, then check again.',
    LegacyRecoveryPhase.ready =>
      'Retry resumes this migration after checking the retained records. '
          'It must not duplicate content or replace later gameplay.',
    LegacyRecoveryPhase.completed =>
      'The copied migration was verified. This does not certify an original '
          'installation update or authorize a release.',
  };

  String get diagnostics => [
    'Tripling Table migration recovery',
    'Status: ${phase.name}',
    if (transactionId != null) 'Transaction: $transactionId',
    for (final issue in issues) ...[
      '${issue.kind.name}: ${issue.message}',
      'Next step: ${issue.nextStep}',
    ],
    for (final warning in warnings) 'Warning: $warning',
    'Keep original app data and recovery copies. Do not uninstall, clear '
        'storage, reset the board, or restore over a newer game.',
  ].join('\n');
}

/// Only a read interface is provided to the exporter. An adapter must enumerate
/// its complete declared migration store, including opaque/unrecognized keys.
/// It must not open the original app's destructive recovery/bootstrap path.
abstract interface class LegacyRecoveryRecordSource {
  String get name;
  Future<List<String>> keys();
  Future<String?> read(String key);
}

class LegacyRecoveryCancelled implements Exception {
  const LegacyRecoveryCancelled();
}

enum LegacyRecoveryCapacityFailure { unknown, insufficient, outputLimit }

class LegacyRecoveryCapacityException implements Exception {
  final LegacyRecoveryCapacityFailure reason;
  const LegacyRecoveryCapacityException(this.reason);
}

class LegacyRecoveryBackup {
  static const format = 'tripling-season-migration-recovery';
  // Legacy JSON is a bounded fallback. Native full exports use a file stream.
  static const maxTotalCharacters = 4 * 1024 * 1024;
  static const maxRecords = 10000;
  final String? _encoded;
  final Stream<List<int>> Function()? _openRead;
  final int? byteLength;
  final bool complete;
  final List<String> problems;
  final String fileName;

  LegacyRecoveryBackup._({
    required String encoded,
    required this.complete,
    required List<String> problems,
    required this.fileName,
  }) : _encoded = encoded,
       _openRead = null,
       byteLength = null,
       problems = List.unmodifiable(problems);

  LegacyRecoveryBackup.streamed({
    required this.fileName,
    required this.byteLength,
    required this.complete,
    required List<String> problems,
    required Stream<List<int>> Function() openRead,
  }) : _encoded = null,
       _openRead = openRead,
       problems = List.unmodifiable(problems);

  bool get isStreamed => _openRead != null;
  Stream<List<int>> openRead() => _openRead?.call() ?? Stream.value(bytes);

  Uint8List get bytes {
    if (_encoded == null) {
      throw UnsupportedError('Consume file-backed recovery with openRead().');
    }
    return Uint8List.fromList(utf8.encode(_encoded));
  }

  /// Copies exact strings, including corrupt/unrecognized envelopes. A partial
  /// copy remains useful but is never represented as a complete backup. Reads
  /// are checked twice; the result is not a live-installation snapshot guarantee.
  static Future<LegacyRecoveryBackup> capture(
    List<LegacyRecoveryRecordSource> sources, {
    DateTime? capturedAt,
  }) async {
    if (sources.isEmpty ||
        sources.length > 32 ||
        sources.any(
          (source) => source.name.isEmpty || source.name.length > 256,
        ) ||
        sources.map((source) => source.name).toSet().length != sources.length) {
      throw ArgumentError('Recovery requires uniquely named record sources.');
    }
    final time = (capturedAt ?? DateTime.now()).toUtc();
    final problems = <String>[];
    final copies = <String, dynamic>{};
    var totalCharacters = 0;
    var totalRecords = 0;
    for (final source in sources) {
      final records = <String, String>{};
      List<String> keys;
      try {
        keys = (await source.keys()).toSet().toList()..sort();
        totalRecords += keys.length;
        totalCharacters += keys.fold<int>(0, (sum, key) => sum + key.length);
        if (totalRecords > maxRecords || totalCharacters > maxTotalCharacters) {
          throw const LegacyRecoveryCapacityException(
            LegacyRecoveryCapacityFailure.outputLimit,
          );
        }
      } on LegacyRecoveryCapacityException {
        rethrow;
      } catch (_) {
        problems.add('${source.name}: record inventory could not be read.');
        copies[source.name] = {'records': records, 'inventoryReadable': false};
        continue;
      }
      final unreadable = <String>[];
      for (final key in keys) {
        try {
          final value = await source.read(key);
          if (value == null) {
            unreadable.add(key);
          } else {
            if (value.length > maxTotalCharacters - totalCharacters) {
              throw const LegacyRecoveryCapacityException(
                LegacyRecoveryCapacityFailure.outputLimit,
              );
            }
            totalCharacters += value.length;
            records[key] = value;
          }
        } on LegacyRecoveryCapacityException {
          rethrow;
        } catch (_) {
          unreadable.add(key);
        }
      }
      if (unreadable.isNotEmpty) {
        problems.add(
          '${source.name}: ${unreadable.length} records unavailable.',
        );
      }
      var stable = true;
      try {
        final finalKeys = (await source.keys()).toSet().toList()..sort();
        if (!listEquals(keys, finalKeys)) stable = false;
        for (final entry in records.entries) {
          if (await source.read(entry.key) != entry.value) stable = false;
        }
      } catch (_) {
        stable = false;
      }
      if (!stable) {
        problems.add(
          '${source.name}: records changed or could not be rechecked.',
        );
      }
      copies[source.name] = {
        'records': records,
        'inventoryReadable': true,
        'stableDuringRead': stable,
        'unavailableKeys': unreadable,
      };
    }
    final payload = jsonEncode({
      'capturedAt': time.toIso8601String(),
      'scope':
          'Only the explicitly supplied migration record stores. '
          'This is not a backup of the original installation or external files.',
      'complete': problems.isEmpty,
      'problems': problems,
      'sources': copies,
    });
    final digest = sha256.convert(utf8.encode(payload)).toString();
    return LegacyRecoveryBackup._(
      encoded: jsonEncode({
        'format': format,
        'version': 1,
        'sha256': digest,
        'payload': payload,
      }),
      complete: problems.isEmpty,
      problems: problems,
      fileName:
          'tripling-recovery-${time.millisecondsSinceEpoch}-'
          '${digest.substring(0, 12)}.json',
    );
  }
}

/// Implementations must inspect before retry, preserve original sources and
/// later gameplay, and never offer a skip/reset/force-activation operation.
abstract interface class LegacyRecoveryActions {
  Future<LegacyRecoveryReport> inspect();
  Future<LegacyRecoveryReport> retry();
  Future<LegacyRecoveryBackup> createBackup();
}

class LegacyRecoveryController extends ChangeNotifier {
  final LegacyRecoveryActions actions;
  LegacyRecoveryReport? report;
  bool busy = false;
  String? actionMessage;
  bool _disposed = false;

  LegacyRecoveryController(this.actions);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> inspect() => _run(() async {
    report = await actions.inspect();
  });

  Future<void> retry() async {
    if (report?.canRetry != true) return;
    await _run(() async {
      report = await actions.retry();
    });
  }

  /// The host supplies an explicit local save flow. false means cancellation,
  /// not success. Saving must create a new file and never target source stores.
  Future<void> saveBackup(
    Future<bool> Function(LegacyRecoveryBackup backup) saveNewFile,
  ) => _run(() async {
    final backup = await actions.createBackup();
    if (_disposed) return;
    final saved = await saveNewFile(backup);
    if (_disposed) return;
    actionMessage = !saved
        ? 'Recovery copy was not saved. Original records remain unchanged.'
        : backup.complete
        ? 'Recovery copy saved for the supplied migration stores. Keep the '
              'original installation and artwork files too.'
        : 'Partial recovery copy saved. ${backup.problems.join(' ')} '
              'Keep the original records; this copy is incomplete.';
  }, inspectionFailure: false);

  Future<void> _run(
    Future<void> Function() operation, {
    bool inspectionFailure = true,
  }) async {
    if (_disposed || busy) return;
    busy = true;
    actionMessage = null;
    _notify();
    try {
      await operation();
    } on LegacyRecoveryCancelled {
      actionMessage =
          'Recovery copy was cancelled. Original records and any '
          'unfinished copy remain unchanged.';
    } on LegacyRecoveryCapacityException catch (error) {
      actionMessage = switch (error.reason) {
        LegacyRecoveryCapacityFailure.unknown =>
          'Available storage could not be verified. Choose a location with '
              'measurable free space; keep the original records.',
        LegacyRecoveryCapacityFailure.insufficient =>
          'Not enough storage remains for the recovery copy and safety reserve. '
              'Choose another private location or free unrelated space. '
              'Keep the original records and unfinished copies.',
        LegacyRecoveryCapacityFailure.outputLimit =>
          'This recovery copy exceeds the configured size limit. Use a '
              'file-backed export with sufficient capacity. Keep the originals.',
      };
    } catch (_) {
      if (inspectionFailure) {
        // Raw exceptions can include a whole source payload. Keep diagnostics
        // controlled and never infer a missing/empty destination from an error.
        report = LegacyRecoveryReport(
          phase: LegacyRecoveryPhase.interrupted,
          transactionId: report?.transactionId,
          issues: const [
            LegacyRecoveryIssue(
              LegacyRecoveryIssueKind.storage,
              'The retained migration records could not be verified. '
              'The operation may have been interrupted.',
            ),
          ],
        );
      } else {
        actionMessage =
            'Recovery copy could not be saved. Keep the original '
            'records, check available storage, and try saving again.';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

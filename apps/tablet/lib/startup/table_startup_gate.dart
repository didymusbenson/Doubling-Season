import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../migration/legacy_migration_recovery.dart';
import '../storage/table_repository.dart';

/// Every domain is mandatory, even when empty. A platform adapter must inventory
/// all original stores/preferences/media and all destination/retention stores
/// without invoking Hive bootstrap, repair, recovery, or initialization.
/// No production adapter exists yet. These are NOT live-snapshot guarantees.
enum TableStartupDomain {
  original,
  migration,
  current,
  previous,
  recovery,
  media,
  other,
}

/// Candidates are diagnostic routes only, NEVER permission to open a repository.
/// An atomic, leased inspect-and-activate boundary is still required.
enum TableStartupRoute { freshCandidate, existingCandidate, recovery }

enum TableStartupReason {
  emptyInventory,
  existingGeneration,
  originalEvidence,
  migrationEvidence,
  retainedEvidence,
  unknownEvidence,
  invalidGeneration,
  inspectionFailed,
}

class TableStartupReport {
  final TableStartupRoute route;
  final TableStartupReason reason;
  const TableStartupReport._(this.route, this.reason);

  // No state, reusable authorization token, or activation callback escapes.
  // Even a successful inventory cannot authorize a subsequent unleased write.
  bool get canActivate => false;
}

/// Read-only inventory policy. Deliberately accepts only the simplest existing
/// authority. Backups, recovery records, media, receipts and old formats require
/// review, rather than selecting, repairing or replacing any generation.
class TableStartupInspector {
  final Map<TableStartupDomain, LegacyRecoveryRecordSource> _sources;

  TableStartupInspector(
    Map<TableStartupDomain, LegacyRecoveryRecordSource> sources,
  ) : _sources = Map.unmodifiable(sources);

  static const _failed = TableStartupReport._(
    TableStartupRoute.recovery,
    TableStartupReason.inspectionFailed,
  );

  Future<TableStartupReport> inspect() async {
    try {
      if (_sources.length != TableStartupDomain.values.length ||
          !TableStartupDomain.values.every(_sources.containsKey) ||
          _sources.values.toSet().length != _sources.length ||
          _sources.values.any((source) => source.name.isEmpty) ||
          _sources.values.map((source) => source.name).toSet().length !=
              _sources.length) {
        return _failed;
      }
      final first = await _capture();
      // Recheck the WHOLE inventory after all first-pass reads, not each store
      // independently. This detects observed changes but cannot exclude ABA or
      // an uncooperative writer. Never advertise it as a production snapshot.
      final second = await _capture();
      for (final domain in TableStartupDomain.values) {
        if (!mapEquals(first[domain], second[domain])) return _failed;
      }
      return _classify(first);
    } catch (_) {
      // Do not expose raw errors, paths, or saved content to a startup surface.
      return _failed;
    }
  }

  Future<Map<TableStartupDomain, Map<String, String>>> _capture() async {
    final result = <TableStartupDomain, Map<String, String>>{};
    for (final domain in TableStartupDomain.values) {
      final source = _sources[domain]!;
      final keys = await source.keys();
      if (keys.toSet().length != keys.length ||
          keys.any((key) => key.isEmpty)) {
        throw const FormatException('Ambiguous inventory.');
      }
      final records = <String, String>{};
      for (final key in keys) {
        final value = await source.read(key);
        if (value == null) throw const FormatException('Incomplete inventory.');
        records[key] = value;
      }
      result[domain] = records;
    }
    return result;
  }

  TableStartupReport _classify(
    Map<TableStartupDomain, Map<String, String>> records,
  ) {
    TableStartupReport blocked(TableStartupReason reason) =>
        TableStartupReport._(TableStartupRoute.recovery, reason);
    if (records[TableStartupDomain.original]!.isNotEmpty) {
      return blocked(TableStartupReason.originalEvidence);
    }
    if (records[TableStartupDomain.migration]!.isNotEmpty) {
      return blocked(TableStartupReason.migrationEvidence);
    }
    if (records[TableStartupDomain.other]!.isNotEmpty) {
      return blocked(TableStartupReason.unknownEvidence);
    }
    if ([
      TableStartupDomain.previous,
      TableStartupDomain.recovery,
      TableStartupDomain.media,
    ].any((domain) => records[domain]!.isNotEmpty)) {
      return blocked(TableStartupReason.retainedEvidence);
    }
    final current = records[TableStartupDomain.current]!;
    if (current.isEmpty) {
      return const TableStartupReport._(
        TableStartupRoute.freshCandidate,
        TableStartupReason.emptyInventory,
      );
    }
    if (current.length != 1 || !current.containsKey('current')) {
      return blocked(TableStartupReason.unknownEvidence);
    }
    try {
      final encoded = current['current']!;
      final state = TableRepository.decodeGeneration(encoded);
      final envelope = jsonDecode(encoded) as Map;
      // The existing repository may upgrade old generations on open. This gate
      // must never silently endorse that write, or a missing local artwork file.
      if (envelope['version'] != TableRepository.envelopeVersion ||
          envelope['sequence'] is! int ||
          (envelope['sequence'] as int) < 1 ||
          state.library.containsKey('legacyPromotionReceipt') ||
          _hasLocalReference(state.toJson())) {
        return blocked(TableStartupReason.retainedEvidence);
      }
      return const TableStartupReport._(
        TableStartupRoute.existingCandidate,
        TableStartupReason.existingGeneration,
      );
    } catch (_) {
      return blocked(TableStartupReason.invalidGeneration);
    }
  }

  // Intentionally conservative, including extension metadata: local references
  // require a platform/media validator before existing gameplay can be opened.
  bool _hasLocalReference(dynamic value) {
    if (value is String) {
      return value.startsWith('tablet-art:') ||
          value.startsWith('file:') ||
          value.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
    }
    if (value is Map) return value.values.any(_hasLocalReference);
    if (value is List) return value.any(_hasLocalReference);
    return false;
  }
}

/// Dormant routing controller. Repeated checks coalesce; a later retry always
/// inventories again. Disposal discards late results and rejects new checks.
/// There is intentionally no migrate, fresh-install, legacy-startup or open API.
class TableStartupGate extends ChangeNotifier {
  final TableStartupInspector inspector;
  TableStartupReport? _report;
  Future<void>? _pending;
  bool _disposed = false;

  TableStartupGate(this.inspector);

  TableStartupReport? get report => _report;
  bool get busy => _pending != null;

  Future<void> check() {
    if (_disposed) return Future<void>.value();
    if (_pending case final pending?) return pending;
    final done = Completer<void>();
    // Set pending before notifying: listener-triggered checks also coalesce.
    _pending = done.future;
    _report = null;
    notifyListeners();
    unawaited(_check(done));
    return done.future;
  }

  Future<void> _check(Completer<void> done) async {
    try {
      if (_disposed) return;
      final result = await inspector.inspect();
      if (!_disposed) _report = result;
    } finally {
      _pending = null;
      if (!_disposed) notifyListeners();
      done.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _report = null;
    super.dispose();
  }
}

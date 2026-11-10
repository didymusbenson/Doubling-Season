import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/startup/table_startup_gate.dart';
import 'package:tripling_table/storage/table_repository.dart';

class _Records implements LegacyRecoveryRecordSource {
  @override
  final String name;
  final records = <String, String>{};
  int reads = 0;
  int inventories = 0;
  Future<void> Function()? beforeKeys;
  Future<String?> Function(String)? readOverride;
  List<String>? keyOverride;
  _Records(this.name);
  @override
  Future<List<String>> keys() async {
    inventories++;
    await beforeKeys?.call();
    return keyOverride ?? records.keys.toList();
  }

  @override
  Future<String?> read(String key) async {
    reads++;
    if (readOverride != null) return readOverride!(key);
    return records[key];
  }
}

void main() {
  late Map<TableStartupDomain, _Records> sources;
  late TableStartupInspector inspector;
  late String generation;

  setUp(() {
    sources = {for (final d in TableStartupDomain.values) d: _Records(d.name)};
    inspector = TableStartupInspector(sources);
    generation = TableRepository.encodeGeneration(
      TabletState.initial(),
      sequence: 1,
    );
  });

  Future<TableStartupReport> inspectUnchanged() async {
    final before = jsonEncode({
      for (final e in sources.entries) e.key.name: e.value.records,
    });
    final report = await inspector.inspect();
    expect(report.canActivate, isFalse);
    expect(
      jsonEncode({
        for (final e in sources.entries) e.key.name: e.value.records,
      }),
      before,
    );
    return report;
  }

  test('empty complete inventory is only a non-activating candidate', () async {
    expect((await inspectUnchanged()).route, TableStartupRoute.freshCandidate);
    expect(sources.values.every((s) => s.inventories == 2), isTrue);
  });

  test(
    'valid current is a candidate without opening or returning its state',
    () async {
      sources[TableStartupDomain.current]!.records['current'] = generation;
      expect(
        (await inspectUnchanged()).route,
        TableStartupRoute.existingCandidate,
      );
    },
  );

  for (final domain in TableStartupDomain.values) {
    test(
      'opaque evidence in ${domain.name} never permits fresh initialization',
      () async {
        sources[domain]!.records['opaque'] =
            'corrupt or incomplete retained bytes';
        expect((await inspectUnchanged()).route, TableStartupRoute.recovery);
      },
    );
    test(
      'missing ${domain.name} domain blocks, never assumes absence',
      () async {
        sources.remove(domain);
        inspector = TableStartupInspector(sources);
        expect(
          (await inspector.inspect()).reason,
          TableStartupReason.inspectionFailed,
        );
      },
    );
    test(
      '${domain.name} inventory exception blocks without exposing details',
      () async {
        sources[domain]!.beforeKeys = () async =>
            throw StateError('private path');
        expect(
          (await inspector.inspect()).reason,
          TableStartupReason.inspectionFailed,
        );
      },
    );
  }

  test(
    'source or migration evidence blocks even a progressed current',
    () async {
      final state = TabletState.initial()..session.revision = 4;
      state.session.players.first.life = 23;
      sources[TableStartupDomain.current]!.records['current'] =
          TableRepository.encodeGeneration(state, sequence: 7);
      for (final domain in [
        TableStartupDomain.original,
        TableStartupDomain.migration,
      ]) {
        sources[domain]!.records['retained'] = 'evidence';
        expect((await inspectUnchanged()).route, TableStartupRoute.recovery);
        sources[domain]!.records.clear();
      }
      expect(
        (await inspectUnchanged()).route,
        TableStartupRoute.existingCandidate,
      );
    },
  );

  test('receipt alone and unresolved local artwork require review', () async {
    for (final value in [
      'tablet-art:missing',
      'file:///missing',
      '/missing',
      r'C:\missing',
    ]) {
      final state = TabletState.initial();
      state.library['custom'] = value;
      sources[TableStartupDomain.current]!.records['current'] =
          TableRepository.encodeGeneration(state, sequence: 1);
      expect((await inspectUnchanged()).route, TableStartupRoute.recovery);
    }
    final state = TabletState.initial();
    state.library['legacyPromotionReceipt'] = {'transactionId': 'old'};
    sources[TableStartupDomain.current]!.records['current'] =
        TableRepository.encodeGeneration(state, sequence: 1);
    expect((await inspectUnchanged()).route, TableStartupRoute.recovery);
  });

  test(
    'corrupt, unknown and incomplete current generations block unchanged',
    () async {
      for (final value in [
        'not json',
        '{}',
        '{"version":999}',
        generation.replaceFirst('sha256', 'unknown'),
      ]) {
        sources[TableStartupDomain.current]!.records['current'] = value;
        expect(
          (await inspectUnchanged()).reason,
          TableStartupReason.invalidGeneration,
        );
      }
    },
  );

  test('valid old format is not permission to run upgrading open', () async {
    final payload = jsonEncode(
      TabletState.initial().toJson()..['schemaVersion'] = 1,
    );
    sources[TableStartupDomain.current]!.records['current'] = jsonEncode({
      'format': 'tripling-season-tablet',
      'version': 1,
      'sequence': 1,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    });
    expect(
      (await inspectUnchanged()).reason,
      TableStartupReason.retainedEvidence,
    );
  });

  test('missing or zero sequence cannot endorse an existing save', () async {
    for (final sequence in [null, 0]) {
      final envelope = jsonDecode(generation) as Map<String, dynamic>;
      if (sequence == null) {
        envelope.remove('sequence');
      } else {
        envelope['sequence'] = sequence;
      }
      sources[TableStartupDomain.current]!.records['current'] = jsonEncode(
        envelope,
      );
      expect((await inspectUnchanged()).route, TableStartupRoute.recovery);
    }
  });

  test(
    'retry clears a prior candidate while a new inspection is pending',
    () async {
      final gate = TableStartupGate(inspector);
      addTearDown(gate.dispose);
      await gate.check();
      expect(gate.report!.route, TableStartupRoute.freshCandidate);
      final pause = Completer<void>();
      sources[TableStartupDomain.original]!.beforeKeys = () => pause.future;
      final pending = gate.check();
      expect(gate.report, isNull);
      expect(gate.busy, isTrue);
      pause.complete();
      await pending;
      expect(gate.busy, isFalse);
    },
  );

  test('duplicate, missing, unreadable and changing records block', () async {
    final source = sources[TableStartupDomain.original]!;
    source.keyOverride = ['a', 'a'];
    expect(
      (await inspector.inspect()).reason,
      TableStartupReason.inspectionFailed,
    );
    source.keyOverride = ['a'];
    expect(
      (await inspector.inspect()).reason,
      TableStartupReason.inspectionFailed,
    );
    source.readOverride = (_) async => throw StateError('read failed');
    expect(
      (await inspector.inspect()).reason,
      TableStartupReason.inspectionFailed,
    );
    source.readOverride = (_) async => '${source.reads}';
    expect(
      (await inspector.inspect()).reason,
      TableStartupReason.inspectionFailed,
    );
  });

  test(
    'whole inventory recheck catches an earlier domain changing during later reads',
    () async {
      sources[TableStartupDomain.other]!.beforeKeys = () async {
        sources[TableStartupDomain.original]!.records['late'] = 'source';
      };
      expect(
        (await inspector.inspect()).reason,
        TableStartupReason.inspectionFailed,
      );
    },
  );

  test(
    'aliased domain adapters and duplicate names are not coverage',
    () async {
      sources[TableStartupDomain.other] = sources[TableStartupDomain.original]!;
      expect(
        (await TableStartupInspector(sources).inspect()).reason,
        TableStartupReason.inspectionFailed,
      );
      sources[TableStartupDomain.other] = _Records('original');
      expect(
        (await TableStartupInspector(sources).inspect()).reason,
        TableStartupReason.inspectionFailed,
      );
    },
  );

  test(
    'overlapping and reentrant checks share one inventory; later retry rereads',
    () async {
      final pause = Completer<void>();
      sources[TableStartupDomain.original]!.beforeKeys = () => pause.future;
      final gate = TableStartupGate(inspector);
      addTearDown(gate.dispose);
      Future<void>? reentrant;
      gate.addListener(() {
        if (gate.busy) reentrant = gate.check();
      });
      final first = gate.check();
      expect(identical(first, gate.check()), isTrue);
      expect(identical(first, reentrant), isTrue);
      pause.complete();
      await first;
      expect(sources[TableStartupDomain.original]!.inventories, 2);
      sources[TableStartupDomain.original]!.records['new'] = 'original source';
      await gate.check();
      expect(gate.report!.reason, TableStartupReason.originalEvidence);
      expect(sources[TableStartupDomain.original]!.inventories, 4);
    },
  );

  test(
    'retry after ambiguous inspection rechecks retained destination, never resets',
    () async {
      final source = sources[TableStartupDomain.current]!;
      source.beforeKeys = () async {
        source.records['current'] = generation;
        throw StateError('lost acknowledgement');
      };
      final gate = TableStartupGate(inspector);
      addTearDown(gate.dispose);
      await gate.check();
      expect(gate.report!.reason, TableStartupReason.inspectionFailed);
      source.beforeKeys = null;
      await gate.check();
      expect(gate.report!.route, TableStartupRoute.existingCandidate);
      expect(source.records['current'], generation);
    },
  );

  test('disposal suppresses stale completion and future inspection', () async {
    final pause = Completer<void>();
    sources[TableStartupDomain.original]!.beforeKeys = () => pause.future;
    final gate = TableStartupGate(inspector);
    var notifications = 0;
    gate.addListener(() => notifications++);
    final pending = gate.check();
    gate.dispose();
    pause.complete();
    await pending;
    expect(gate.report, isNull);
    expect(notifications, 1);
    final count = sources[TableStartupDomain.original]!.inventories;
    await gate.check();
    expect(sources[TableStartupDomain.original]!.inventories, count);
  });
}

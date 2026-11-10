import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/ui/legacy_migration_recovery_view.dart';

class _Source implements LegacyRecoveryRecordSource {
  @override
  final String name;
  final Map<String, String> records;
  final Set<String> failures = {};
  bool failInventory = false;
  void Function(String key)? beforeRead;
  _Source(this.name, this.records);
  @override
  Future<List<String>> keys() async {
    if (failInventory) throw StateError('unreadable inventory');
    return records.keys.toList();
  }

  @override
  Future<String?> read(String key) async {
    beforeRead?.call(key);
    if (failures.contains(key)) throw StateError('unreadable record');
    return records[key];
  }
}

LegacyRecoveryReport _ready() => LegacyRecoveryReport(
  phase: LegacyRecoveryPhase.ready,
  transactionId: 'transaction-123',
  canRetry: true,
);

class _Actions implements LegacyRecoveryActions {
  int inspections = 0;
  int retries = 0;
  int backups = 0;
  LegacyRecoveryReport next = _ready();
  Completer<LegacyRecoveryReport>? pending;
  bool fail = false;
  Completer<LegacyRecoveryBackup>? pendingBackup;
  _Source source = _Source('journal', {'source': 'exact original'});
  @override
  Future<LegacyRecoveryReport> inspect() async {
    inspections++;
    if (fail) throw StateError('PRIVATE PAYLOAD');
    return pending?.future ?? next;
  }

  @override
  Future<LegacyRecoveryReport> retry() async {
    retries++;
    if (fail) throw StateError('PRIVATE PAYLOAD');
    return pending?.future ?? next;
  }

  @override
  Future<LegacyRecoveryBackup> createBackup() async {
    backups++;
    if (fail) throw StateError('PRIVATE PAYLOAD');
    return pendingBackup?.future ?? LegacyRecoveryBackup.capture([source]);
  }
}

Map<String, dynamic> _payload(LegacyRecoveryBackup backup) {
  final envelope =
      jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
  expect(envelope['format'], LegacyRecoveryBackup.format);
  expect(envelope['version'], 1);
  expect(
    envelope['sha256'],
    sha256.convert(utf8.encode(envelope['payload'] as String)).toString(),
  );
  return jsonDecode(envelope['payload'] as String) as Map<String, dynamic>;
}

void main() {
  group('copy-only recovery export', () {
    test(
      'retains exact corrupt, future and opaque records with a checksum',
      () async {
        final original = <String, String>{
          'source': '{invalid \u0000\n  ',
          'media_a': '{"futureFormat":700,"bytes":"AAA="}',
          'unknown/private/key': 'opaque record Ω',
        };
        final source = _Source('journal', {...original});
        final backup = await LegacyRecoveryBackup.capture([
          source,
        ], capturedAt: DateTime.utc(2026, 11, 10));
        expect(backup.complete, isTrue);
        expect(backup.problems, isEmpty);
        final payload = _payload(backup);
        expect(payload['sources']['journal']['records'], original);
        expect(payload['scope'], contains('not a backup of the original'));
        expect(source.records, original);
        expect(
          backup.fileName,
          matches(r'^tripling-recovery-[0-9]+-[a-f0-9]{12}\.json$'),
        );
        final exposed = backup.bytes;
        exposed[0] = 0;
        expect(backup.bytes[0], isNot(0));
      },
    );
    test('preserves readable records when some cannot be read', () async {
      final source = _Source('journal', {'source': 'keep', 'candidate': 'bad'})
        ..failures.add('candidate');
      final backup = await LegacyRecoveryBackup.capture([source]);
      expect(backup.complete, isFalse);
      final payload = _payload(backup);
      expect(payload['sources']['journal']['records'], {'source': 'keep'});
      expect(payload['sources']['journal']['unavailableKeys'], ['candidate']);
      expect(source.records, {'source': 'keep', 'candidate': 'bad'});
    });
    test(
      'inventory failure is partial rather than an empty successful backup',
      () async {
        final source = _Source('journal', {'source': 'original'})
          ..failInventory = true;
        final good = _Source('media', {'hash': 'exact bytes'});
        final backup = await LegacyRecoveryBackup.capture([source, good]);
        expect(backup.complete, isFalse);
        expect(_payload(backup)['sources']['media']['records'], good.records);
        expect(
          _payload(backup)['sources']['journal']['inventoryReadable'],
          isFalse,
        );
      },
    );
    test(
      'changed values keep first bytes and mark the copy incomplete',
      () async {
        final source = _Source('journal', {'source': 'first'});
        var count = 0;
        source.beforeRead = (key) {
          if (++count == 2) source.records[key] = 'newer';
        };
        final backup = await LegacyRecoveryBackup.capture([source]);
        expect(backup.complete, isFalse);
        final copied = _payload(backup)['sources']['journal'];
        expect(copied['records'], {'source': 'first'});
        expect(copied['stableDuringRead'], isFalse);
        expect(source.records['source'], 'newer');
      },
    );
    test('added records during capture prevent a complete claim', () async {
      final source = _Source('journal', {'source': 'first'});
      source.beforeRead = (_) => source.records['new-record'] = 'later';
      final backup = await LegacyRecoveryBackup.capture([source]);
      expect(backup.complete, isFalse);
      expect(_payload(backup)['sources']['journal']['records'], {
        'source': 'first',
      });
    });
    test(
      'empty stores valid but no duplicate or unnamed sources rejected',
      () async {
        final source = _Source('journal', {});
        expect((await LegacyRecoveryBackup.capture([source])).complete, isTrue);
        await expectLater(
          LegacyRecoveryBackup.capture([]),
          throwsArgumentError,
        );
        await expectLater(
          LegacyRecoveryBackup.capture([source, source]),
          throwsArgumentError,
        );
        await expectLater(
          LegacyRecoveryBackup.capture([_Source('', {})]),
          throwsArgumentError,
        );
      },
    );
  });

  group('non-destructive recovery orchestration', () {
    test(
      'blocked completed and unresolved reports cannot enable retry',
      () async {
        final actions = _Actions();
        final controller = LegacyRecoveryController(actions);
        addTearDown(controller.dispose);
        for (final phase in [
          LegacyRecoveryPhase.blocked,
          LegacyRecoveryPhase.completed,
        ]) {
          actions.next = LegacyRecoveryReport(phase: phase, canRetry: true);
          await controller.inspect();
          await controller.retry();
        }
        actions.next = LegacyRecoveryReport(
          phase: LegacyRecoveryPhase.ready,
          canRetry: true,
          issues: const [
            LegacyRecoveryIssue(
              LegacyRecoveryIssueKind.integrity,
              'bad checksum',
            ),
          ],
        );
        await controller.inspect();
        await controller.retry();
        expect(actions.retries, 0);
      },
    );
    test('repeated clicks and backup cannot overlap a retry', () async {
      final actions = _Actions();
      final controller = LegacyRecoveryController(actions);
      addTearDown(controller.dispose);
      await controller.inspect();
      actions.pending = Completer();
      final first = controller.retry();
      await controller.retry();
      await controller.inspect();
      await controller.saveBackup((_) async => true);
      expect(controller.busy, isTrue);
      expect(actions.retries, 1);
      expect(actions.inspections, 1);
      expect(actions.backups, 0);
      actions.pending!.complete(
        LegacyRecoveryReport(phase: LegacyRecoveryPhase.completed),
      );
      await first;
      expect(controller.busy, isFalse);
      expect(controller.report!.phase, LegacyRecoveryPhase.completed);
      expect(controller.report!.canRetry, isFalse);
    });
    test(
      'unknown retry outcome requires inspection and never leaks payload',
      () async {
        final actions = _Actions();
        final controller = LegacyRecoveryController(actions);
        addTearDown(controller.dispose);
        await controller.inspect();
        actions.fail = true;
        await controller.retry();
        expect(controller.report!.phase, LegacyRecoveryPhase.interrupted);
        expect(controller.report!.canRetry, isFalse);
        expect(controller.report!.transactionId, 'transaction-123');
        expect(
          controller.report!.diagnostics,
          isNot(contains('PRIVATE PAYLOAD')),
        );
        await controller.retry();
        expect(actions.retries, 1);
        actions.fail = false;
        await controller.inspect();
        expect(controller.report!.canRetry, isTrue);
      },
    );
    test(
      'cancelled save does not claim success or change the report',
      () async {
        final actions = _Actions();
        final controller = LegacyRecoveryController(actions);
        addTearDown(controller.dispose);
        await controller.inspect();
        final report = controller.report;
        await controller.saveBackup((_) async => false);
        expect(controller.actionMessage, contains('not saved'));
        expect(controller.report, same(report));
        expect(actions.source.records, {'source': 'exact original'});
      },
    );
    test(
      'failed save stays retryable without changing retained data',
      () async {
        final actions = _Actions();
        final controller = LegacyRecoveryController(actions);
        addTearDown(controller.dispose);
        await controller.inspect();
        await controller.saveBackup((_) async => throw StateError('disk full'));
        expect(controller.actionMessage, contains('could not be saved'));
        expect(controller.report!.canRetry, isTrue);
        await controller.saveBackup((_) async => true);
        expect(controller.actionMessage, contains('copy saved'));
        expect(actions.source.records, {'source': 'exact original'});
      },
    );
    test('partial backup says incomplete not fully backed up', () async {
      final actions = _Actions()..source.failures.add('source');
      final controller = LegacyRecoveryController(actions);
      addTearDown(controller.dispose);
      await controller.saveBackup((backup) async {
        expect(backup.complete, isFalse);
        return true;
      });
      expect(controller.actionMessage, contains('Partial recovery copy saved'));
      expect(controller.actionMessage, contains('incomplete'));
    });
    test(
      'disposal during an operation never notifies after dismissal',
      () async {
        final actions = _Actions()..pending = Completer();
        final controller = LegacyRecoveryController(actions);
        var notifications = 0;
        controller.addListener(() => notifications++);
        final checking = controller.inspect();
        controller.dispose();
        actions.pending!.complete(_ready());
        await checking;
        await controller.retry();
        expect(notifications, 1);
        expect(actions.retries, 0);
      },
    );
    test(
      'dismissal while collecting backup never opens the save flow',
      () async {
        final actions = _Actions()..pendingBackup = Completer();
        final controller = LegacyRecoveryController(actions);
        var saves = 0;
        final pending = controller.saveBackup((_) async {
          saves++;
          return true;
        });
        controller.dispose();
        actions.pendingBackup!.complete(
          await LegacyRecoveryBackup.capture([actions.source]),
        );
        await pending;
        expect(saves, 0);
        expect(actions.source.records, {'source': 'exact original'});
      },
    );

    test('reports have immutable issues warnings and concrete next steps', () {
      final issues = [
        const LegacyRecoveryIssue(
          LegacyRecoveryIssueKind.destinationConflict,
          'Later game exists',
        ),
      ];
      final warnings = ['Missing metadata'];
      final report = LegacyRecoveryReport(
        phase: LegacyRecoveryPhase.blocked,
        issues: issues,
        warnings: warnings,
      );
      issues.clear();
      warnings.clear();
      expect(report.issues, hasLength(1));
      expect(report.warnings, hasLength(1));
      expect(report.diagnostics, contains('separate rehearsal destination'));
      for (final kind in LegacyRecoveryIssueKind.values) {
        expect(LegacyRecoveryIssue(kind, 'problem').nextStep, isNotEmpty);
      }
    });
  });

  Future<void> mount(
    WidgetTester tester,
    LegacyRecoveryController controller, {
    Future<bool> Function(LegacyRecoveryBackup)? save,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LegacyMigrationRecoveryView(
          controller: controller,
          onSaveBackup: save ?? (_) async => true,
        ),
      ),
    ),
  );

  testWidgets('blocked screen shows diagnostics without reset skip or retry', (
    tester,
  ) async {
    final actions = _Actions()
      ..next = LegacyRecoveryReport(
        phase: LegacyRecoveryPhase.blocked,
        transactionId: 'blocked-transaction',
        canRetry: true,
        issues: const [
          LegacyRecoveryIssue(
            LegacyRecoveryIssueKind.unsupported,
            'Unsupported custom utility',
          ),
        ],
      );
    final controller = LegacyRecoveryController(actions);
    addTearDown(controller.dispose);
    await controller.inspect();
    await mount(tester, controller);
    expect(find.text('Migration needs attention'), findsOneWidget);
    expect(find.text('Unsupported custom utility'), findsOneWidget);
    expect(find.text('Retry safely'), findsNothing);
    expect(find.text('Save recovery copy'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Transaction: blocked-transaction'),
      findsOneWidget,
    );
  });
  testWidgets('retry disables all storage actions and finishes honestly', (
    tester,
  ) async {
    final actions = _Actions();
    final controller = LegacyRecoveryController(actions);
    addTearDown(controller.dispose);
    await controller.inspect();
    await mount(tester, controller);
    actions.pending = Completer();
    await tester.tap(find.text('Retry safely'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Retry safely'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Check again'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Save recovery copy'),
          )
          .onPressed,
      isNull,
    );
    actions.pending!.complete(
      LegacyRecoveryReport(phase: LegacyRecoveryPhase.completed),
    );
    await tester.pumpAndSettle();
    expect(find.text('Migration rehearsal verified'), findsOneWidget);
    expect(find.textContaining('does not certify an original'), findsOneWidget);
    expect(find.text('Retry safely'), findsNothing);
  });
  testWidgets('narrow large-text layout scrolls to save and copy diagnostics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final actions = _Actions()
      ..next = LegacyRecoveryReport(
        phase: LegacyRecoveryPhase.blocked,
        issues: [
          for (final kind in LegacyRecoveryIssueKind.values)
            LegacyRecoveryIssue(kind, '${kind.name} needs attention'),
        ],
      );
    final controller = LegacyRecoveryController(actions);
    addTearDown(controller.dispose);
    await controller.inspect();
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: LegacyMigrationRecoveryView(
            controller: controller,
            onSaveBackup: (_) async {
              saved++;
              return false;
            },
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Save recovery copy'), 200);
    await tester.tap(find.text('Save recovery copy'));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Technical details'), 200);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Copy diagnostics'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Copy diagnostics'));
    await tester.pumpAndSettle();
    expect(copied, contains('Tripling Table migration recovery'));
    expect(copied, isNot(contains('exact original')));
    expect(tester.takeException(), isNull);
  });
}

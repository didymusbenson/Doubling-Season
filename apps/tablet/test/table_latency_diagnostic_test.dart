import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

// Opt-in development measurement, not an iPad performance assertion:
// flutter test test/table_latency_diagnostic_test.dart \
//   --dart-define=TABLE_LATENCY_DIAGNOSTICS=true
// This measures command work and the fixture's validation/serialization only.
// It deliberately does NOT claim Hive flush, gesture or rendered-frame latency.
class _TimedMemoryRepository extends MemoryTableRepository {
  _TimedMemoryRepository(super.state);
  int lastSaveMicroseconds = 0;

  @override
  Future<void> save(TabletState state) async {
    final watch = Stopwatch()..start();
    await super.save(state);
    lastSaveMicroseconds = watch.elapsedMicroseconds;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('TABLE_LATENCY_DIAGNOSTICS');
  for (final historyEntries in [0, 150]) {
    for (final input in ['life', 'token_quantity']) {
      test(
        '$input command phase sample after $historyEntries history entries',
        () async {
          final repository = _TimedMemoryRepository(
            stateWithTokens([sampleToken()]),
          );
          final controller = TableController(repository: repository);
          final catalog = TabletCatalog(controller);
          final board = BoardService(controller, catalog);
          addTearDown(catalog.dispose);
          addTearDown(controller.dispose);
          await controller.initialize();
          final playerId = controller.session.players.first.id;
          for (var i = 0; i < historyEntries; i++) {
            controller.settleHistoryGroup();
            expect(
              await controller.adjustLife(playerId, i.isEven ? 1 : -1),
              isTrue,
            );
          }
          final total = <int>[];
          final save = <int>[];
          for (var i = 0; i < 20; i++) {
            controller.settleHistoryGroup();
            final watch = Stopwatch()..start();
            if (input == 'life') {
              expect(
                await controller.adjustLife(playerId, i.isEven ? 1 : -1),
                isTrue,
              );
            } else {
              await board.changeQuantity(playerId, 'source', i.isEven ? 1 : -1);
            }
            total.add(watch.elapsedMicroseconds);
            save.add(repository.lastSaveMicroseconds);
          }
          total.sort();
          save.sort();
          // Machine-readable sample; no threshold and no device extrapolation.
          // ignore: avoid_print
          print(
            jsonEncode({
              'kind': 'memory_command_diagnostic',
              'input': input,
              'initialHistoryEntries': historyEntries,
              'samples': total.length,
              'totalMedianUs': total[total.length ~/ 2],
              'totalMaxUs': total.last,
              'fixtureSaveMedianUs': save[save.length ~/ 2],
              'fixtureSaveMaxUs': save.last,
              'serializedBytes': utf8.encode(repository.encoded).length,
              'excludes': [
                'Hive I/O',
                'pointer dispatch',
                'rendered frames',
                'iPad timing',
              ],
            }),
          );
        },
        skip: !enabled,
      );
    }
  }
}

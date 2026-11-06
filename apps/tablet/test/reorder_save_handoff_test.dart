import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

class _DelayedRepository extends MemoryTableRepository {
  _DelayedRepository(super.state);
  Completer<void>? gate;
  bool saving = false;

  @override
  Future<void> save(TabletState state) async {
    saving = true;
    await gate?.future;
    await super.save(state);
    saving = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reorder-save-');
    Hive.init(directory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final scenario in [
    (seat: 0, phone: false),
    (seat: 1, phone: false),
    (seat: 0, phone: true),
  ]) {
    final seat = scenario.seat;
    testWidgets(
      'seat $seat phone ${scenario.phone} drop holds its new position while save is pending',
      (tester) async {
        tester.view.physicalSize = scenario.phone
            ? const Size(390, 844)
            : const Size(1133, 744);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = TabletState.initial();
        final player = state.session.players[seat];
        player.tokens = [
          for (var i = 0; i < 3; i++)
            sampleToken(
              id: 'token-$i',
              name: 'Token $i',
              type: '',
              abilities: '',
            ),
        ];
        final repository = _DelayedRepository(state);
        final controller = TableController(repository: repository);
        await controller.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: tableTheme(Brightness.dark),
            home: TableScreen(
              controller: controller,
              enablePhonePresentation: scenario.phone,
              compactPlayerOne: scenario.phone,
            ),
          ),
        );
        await tester.pumpAndSettle();
        addTearDown(() async {
          repository.gate?.complete();
          repository.gate = null;
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        });
        final original = controller
            .player(player.id)
            .tokens
            .map((t) => t.id)
            .toList();
        final gate = repository.gate = Completer<void>();
        final first = find.text('Token 0');
        final second = find.text('Token 1');
        final sign = seat == 1 ? -1.0 : 1.0;
        final start = tester.getCenter(first);
        final destination = Offset(
          start.dx,
          tester.getCenter(second).dy + sign * 20,
        );
        final drag = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 600));
        for (var step = 1; step <= 30; step++) {
          await drag.moveTo(Offset.lerp(start, destination, step / 30)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await drag.up();
        for (var frame = 0; frame < 35; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (!repository.saving) continue;
          expect(
            controller.player(player.id).tokens.map((t) => t.id),
            original,
            reason:
                'Canonical state stays unchanged until storage acknowledges.',
          );
          final separation =
              (tester.getCenter(first).dy - tester.getCenter(second).dy) * sign;
          expect(
            separation,
            greaterThan(0),
            reason:
                'After drop handoff, every frame must retain the requested order (frame $frame).',
          );
        }
        expect(repository.saving, isTrue);
        gate.complete();
        repository.gate = null;
        await tester.pumpAndSettle();
        expect(controller.player(player.id).tokens.map((t) => t.id), [
          'token-1',
          'token-0',
          'token-2',
        ]);
        expect(
          (tester.getCenter(first).dy - tester.getCenter(second).dy) * sign,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final utility in [false, true]) {
    testWidgets(
      '${utility ? 'Utility' : 'Token'} pending order survives tablet-phone-tablet switches',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = TabletState.initial();
        final player = state.session.players.first;
        if (utility) {
          player.utilities = [
            for (var i = 0; i < 2; i++)
              UtilityState(id: 'u$i', name: 'Tool $i', value: i),
          ];
        } else {
          player.tokens = [
            for (var i = 0; i < 2; i++)
              sampleToken(id: 't$i', name: 'Token $i', type: '', abilities: ''),
          ];
        }
        final repository = _DelayedRepository(state);
        final controller = TableController(repository: repository);
        await controller.initialize();
        Future<void> show(bool phone) async {
          tester.view.physicalSize = phone
              ? const Size(390, 844)
              : const Size(1133, 744);
          await tester.pumpWidget(
            MaterialApp(
              theme: tableTheme(Brightness.dark),
              home: TableScreen(
                controller: controller,
                enablePhonePresentation: true,
                compactPlayerOne: phone,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        addTearDown(() async {
          repository.gate?.complete();
          repository.gate = null;
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        });
        await show(false);
        final gate = repository.gate = Completer<void>();
        final lane = find.byKey(
          ValueKey(
            '${player.id}-${utility ? 'utility-section' : 'token-lane'}',
          ),
        );
        tester
            .widget<ReorderableListView>(
              find.descendant(
                of: lane,
                matching: find.byType(ReorderableListView),
              ),
            )
            .onReorder(0, 2);
        await tester.pumpAndSettle();
        double separation() =>
            tester.getCenter(find.text('${utility ? 'Tool' : 'Token'} 0')).dy -
            tester.getCenter(find.text('${utility ? 'Tool' : 'Token'} 1')).dy;
        expect(separation(), greaterThan(0));
        await show(true);
        expect(separation(), greaterThan(0));
        final lists = find.byType(SliverReorderableList);
        tester
            .widget<SliverReorderableList>(utility ? lists.first : lists.last)
            .onReorder(0, 2);
        await tester.pumpAndSettle();
        expect(separation(), lessThan(0));
        await show(false);
        expect(separation(), lessThan(0));
        expect(repository.saving, isTrue);
        expect(controller.session.history, isEmpty);
        gate.complete();
        repository.gate = null;
        await tester.pumpAndSettle();
        expect(separation(), lessThan(0));
        expect(controller.session.history, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

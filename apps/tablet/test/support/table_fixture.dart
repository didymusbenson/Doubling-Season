import 'dart:convert';

import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/storage/table_repository.dart';

/// Exercise aggregate serialization and acknowledged writes without opening any
/// Hive box or touching the person's active game on this machine.
class MemoryTableRepository extends TableRepository {
  String encoded;
  bool failSave = false;

  MemoryTableRepository(TabletState state)
    : encoded = jsonEncode(state.toJson());

  @override
  Future<TableLoadResult> open() async =>
      TableLoadResult(TabletState.fromJson(jsonMap(jsonDecode(encoded))));

  @override
  Future<void> save(TabletState state) async {
    if (failSave) throw StateError('Simulated storage failure');
    validateTabletState(state);
    encoded = jsonEncode(state.toJson());
  }

  @override
  Future<void> flush() async {}
}

class TableFixture {
  final MemoryTableRepository repository;
  late final TableController controller = TableController(
    repository: repository,
  );
  late final TabletCatalog catalog = TabletCatalog(controller);
  late final BoardService board = BoardService(controller, catalog);

  TableFixture([TabletState? state])
    : repository = MemoryTableRepository(state ?? TabletState.initial());

  Future<void> initialize() => controller.initialize();
  String get playerId => controller.session.players.first.id;
  PlayerState get player => controller.player(playerId);
  TokenState token(String id) => player.tokens.firstWhere((t) => t.id == id);

  void dispose() {
    catalog.dispose();
    controller.dispose();
  }
}

TokenState sampleToken({
  String id = 'source',
  String name = 'Saproling',
  String pt = '1/1',
  String type = 'Creature — Saproling',
  String abilities = '',
  String colors = 'G',
  int amount = 3,
  int tapped = 1,
  int sick = 1,
  int plusOne = 0,
  int minusOne = 0,
  Map<String, int>? counters,
  String? artworkUrl,
}) => TokenState(
  id: id,
  definitionId: '$name|$pt|$colors|$type|$abilities',
  name: name,
  pt: pt,
  colors: colors,
  type: type,
  abilities: abilities,
  amount: amount,
  tapped: tapped,
  summoningSick: sick,
  plusOneCounters: plusOne,
  minusOneCounters: minusOne,
  counters: counters,
  artworkUrl: artworkUrl,
  artworkSet: artworkUrl == null ? null : 'TEST',
  artworkOptions: artworkUrl == null
      ? []
      : [
          {'url': artworkUrl, 'set': 'TEST', 'artist': 'Test artist'},
        ],
);

TabletState stateWithTokens(
  List<TokenState> tokens, {
  bool sickness = true,
  List<String> modifiers = const [],
}) {
  final state = TabletState.initial();
  final player = state.session.players.first;
  player.tokens = tokens;
  player.summoningSicknessEnabled = sickness;
  player.rules = [
    for (final definition in modifiers)
      ModifierSource(
        id: 'rule-$definition',
        ownerPlayerId: player.id,
        definitionId: definition,
        name: definition,
        enabled: true,
        count: 1,
      ),
  ];
  return state;
}

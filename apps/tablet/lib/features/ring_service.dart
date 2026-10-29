import '../domain/table_controller.dart';
import '../domain/table_state.dart';
import 'board_service.dart';

/// Manual, seat-scoped Ring progress. Creature and combat rules stay at the table.
class RingService {
  static const kind = 'the_ring';
  static const bearerKey = 'ringBearer';
  static const maxTemptations = 1000000000;
  static const artworkUrl =
      'https://cards.scryfall.io/large/front/7/2/7215460e-8c06-47d0-94e5-d1832d0218af.jpg';
  static const reminders = [
    'Legendary; cannot be blocked by creatures with greater power.',
    'When your bearer attacks, draw a card, then discard a card.',
    'Each creature blocking your bearer is sacrificed at end of combat.',
    'Bearer combat damage to a player: each opponent loses 3 life.',
  ];

  final TableController controller;
  RingService(this.controller);

  static bool isRingDefinition(String name, String type) =>
      type.toLowerCase().contains('emblem') &&
      name == 'The Ring // The Ring Tempts You';
  static int stage(UtilityState utility) => utility.value.clamp(0, 4);
  static String bearer(UtilityState utility) =>
      utility.configuration[bearerKey] as String? ?? '';
  static Map<String, dynamic> freshConfiguration(Map<String, dynamic> config) =>
      Map<String, dynamic>.from(config)..remove(bearerKey);

  Future<void> tempt(
    String playerId,
    String utilityId, {
    String? bearer,
    bool noCreatures = false,
    BoardScope? captured,
  }) => _change(playerId, utilityId, 'The Ring tempts you', (utility) {
    if (utility.value >= maxTemptations) {
      throw const FormatException(
        'Correct the temptation count before continuing.',
      );
    }
    utility.value = utility.value.clamp(0, maxTemptations) + 1;
    // The actual bearer may be a physical creature that is not represented in
    // this app. Its optional label must never gate temptation progress. An
    // omitted label preserves existing notes; an explicit blank clears them.
    if (noCreatures || bearer != null) {
      utility.configuration[bearerKey] = noCreatures ? '' : bearer!.trim();
    }
  }, captured: captured);

  Future<void> clearBearer(
    String playerId,
    String utilityId, {
    BoardScope? captured,
  }) => _change(
    playerId,
    utilityId,
    'Clear Ring-bearer',
    (utility) => utility.configuration[bearerKey] = '',
    captured: captured,
  );

  Future<void> correct(
    String playerId,
    String utilityId, {
    required int temptations,
    String? bearer,
    BoardScope? captured,
  }) => _change(playerId, utilityId, 'Correct The Ring', (utility) {
    if (temptations < 0 || temptations > maxTemptations) {
      throw const FormatException('Use a nonnegative temptation count.');
    }
    utility.value = temptations;
    if (bearer != null) utility.configuration[bearerKey] = bearer.trim();
  }, captured: captured);

  Future<void> _change(
    String playerId,
    String utilityId,
    String label,
    void Function(UtilityState) mutate, {
    BoardScope? captured,
  }) async {
    final player = controller.player(playerId);
    final scope =
        captured ??
        BoardScope(
          controller.session.id,
          playerId,
          controller.session.generation,
          player.generation,
        );
    final ok = await controller.commit(
      label,
      playerId: playerId,
      expectedSessionId: scope.sessionId,
      expectedGeneration: scope.generation,
      expectedPlayerGeneration: scope.playerGeneration,
      mutate: (session) {
        if (scope.playerId != playerId) {
          throw StateError('Reopen The Ring for this seat.');
        }
        final utility = session
            .player(playerId)
            .utilities
            .firstWhere(
              (u) => u.id == utilityId && u.kind == kind,
              orElse: () =>
                  throw StateError('This Ring utility is no longer available.'),
            );
        mutate(utility);
      },
    );
    if (!ok) {
      throw StateError(controller.error ?? 'The Ring could not be saved.');
    }
  }
}

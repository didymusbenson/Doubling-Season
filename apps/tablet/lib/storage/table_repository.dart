import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/table_state.dart';

class TableLoadResult {
  final TabletState state;
  final String? recoveryMessage;
  const TableLoadResult(this.state, {this.recoveryMessage});
}

class UnsupportedTableFormat implements Exception {
  final String message;
  const UnsupportedTableFormat(this.message);
  @override
  String toString() => message;
}

/// A single aggregate is the transaction boundary for gameplay, undo and archives.
/// The previous validated generation is flushed before promoting its successor.
class TableRepository {
  static const boxName = 'tripling_season_tablet_aggregate_v1';
  Box<String>? _box;
  String? _lastGood;

  Future<TableLoadResult> open() async {
    await Hive.initFlutter('tripling_season_tablet');
    _box = await Hive.openBox<String>(boxName);
    final current = _box!.get('current');
    final previous = _box!.get('previous');
    if (current == null && previous == null) {
      final state = TabletState.initial();
      await save(state);
      return TableLoadResult(state);
    }
    Object? currentError;
    if (current != null) {
      try {
        final state = _decode(current);
        _lastGood = current;
        return TableLoadResult(state);
      } catch (error) {
        if (error is UnsupportedTableFormat) rethrow;
        currentError = error;
      }
    }
    if (previous != null) {
      try {
        final state = _decode(previous);
        // Preserve the original damaged/newer-format input for explicit recovery.
        if (current != null) {
          await _box!.put(
            'quarantine_${DateTime.now().microsecondsSinceEpoch}',
            current,
          );
          await _box!.flush();
        }
        _lastGood = previous;
        return TableLoadResult(
          state,
          recoveryMessage:
              'The latest save could not be read. The preceding complete save was '
              'recovered; the original data has been preserved.',
        );
      } catch (error) {
        throw StateError(
          'Neither saved generation could be read. Your data has '
          'been preserved. Latest: $currentError; previous: $error',
        );
      }
    }
    throw StateError(
      'The saved game could not be read and has been preserved. '
      '$currentError',
    );
  }

  Future<void> save(TabletState state) async {
    final box = _box;
    if (box == null) throw StateError('Storage is not open.');
    validateTabletState(state);
    final payload = jsonEncode(state.toJson());
    final encoded = jsonEncode({
      'format': 'tripling-season-tablet',
      'version': 1,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    });
    final old = _lastGood;
    if (old != null) {
      await box.put('previous', old);
      await box.flush();
    }
    try {
      await box.put('current', encoded);
      await box.flush();
      _lastGood = encoded;
    } catch (error) {
      // A failed acknowledgement never deliberately replaces the prior game.
      // If rollback itself cannot write, open() still has the preceding generation.
      try {
        if (old != null) {
          await box.put('current', old);
        } else {
          await box.delete('current');
        }
        await box.flush();
      } catch (_) {
        // Keep the original write error; both generation records remain available.
      }
      rethrow;
    }
  }

  TabletState _decode(String encoded) {
    final envelope = jsonMap(jsonDecode(encoded));
    if (envelope['format'] != 'tripling-season-tablet' ||
        envelope['version'] != 1) {
      throw const UnsupportedTableFormat(
        'This save uses an unsupported tablet format. Open it with the matching '
        'or newer app version; the stored game has not been changed.',
      );
    }
    final payload = envelope['payload'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('Saved data integrity check failed.');
    }
    final json = jsonMap(jsonDecode(payload));
    if (json['schemaVersion'] != TabletState.currentSchemaVersion) {
      throw const UnsupportedTableFormat(
        'This save requires a different app version. The stored game has not been changed.',
      );
    }
    final state = TabletState.fromJson(json);
    validateTabletState(state);
    return state;
  }

  Future<void> flush() async => _box?.flush();
}

void validateTabletState(TabletState state) {
  void require(bool condition, String reason) {
    if (!condition) throw FormatException(reason);
  }

  void unique(Iterable<String> values, String label) {
    final list = values.toList();
    require(
      list.every((value) => value.isNotEmpty),
      '$label has an empty identity.',
    );
    require(
      list.toSet().length == list.length,
      '$label has duplicate identities.',
    );
  }

  void bounded(int value, String label, {bool signed = false}) {
    require(
      value >= (signed ? -999999999999 : 0) && value <= 999999999999,
      '$label is outside supported integer bounds.',
    );
  }

  require(
    state.schemaVersion == TabletState.currentSchemaVersion,
    'Unsupported tablet schema.',
  );
  require(
    state.profiles.length >= 4,
    'The persistent seat roster is incomplete.',
  );
  unique(state.profiles.map((value) => value.id), 'Seats');
  require(state.archives.length <= 10, 'More than ten archived games.');
  unique(state.archives.map((value) => value.id), 'Archives');
  final seats = state.profiles.map((value) => value.id).toSet();

  void session(GameSession game) {
    require(game.id.isNotEmpty, 'Game identity is missing.');
    require(
      game.players.length >= 2 && game.players.length <= 4,
      'A game must have two to four players.',
    );
    require(
      game.generation > 0 && game.revision >= 0,
      'Invalid game revision.',
    );
    bounded(game.startingLife, 'Starting life');
    unique(game.players.map((value) => value.id), 'Players');
    unique(
      game.players.map((value) => value.seatId),
      'Player seat memberships',
    );
    final ids = game.players.map((value) => value.id).toSet();
    require(
      game.players.map((value) => value.slot).toSet().length ==
          game.players.length,
      'More than one player occupies a slot.',
    );
    require(
      game.players.every((value) => value.slot >= 0 && value.slot < 4),
      'Invalid player slot.',
    );
    require(
      game.players.every((value) => seats.contains(value.seatId)),
      'An active player references an unknown persistent seat.',
    );
    require(
      game.monarchPlayerId == null || ids.contains(game.monarchPlayerId),
      'Monarch references an unknown player.',
    );
    require(
      ['neither', 'day', 'night'].contains(game.dayNight),
      'Invalid day/night designation.',
    );
    unique(game.commanders.map((value) => value.id), 'Commander sources');
    final sources = game.commanders.map((value) => value.id).toSet();
    require(
      game.commanders.every((value) => ids.contains(value.ownerPlayerId)),
      'Commander source references an unknown owner.',
    );
    final entityIds = <String>[];
    final ruleIds = <String>[];
    for (final player in game.players) {
      require(player.generation > 0, 'Invalid player generation.');
      bounded(player.life, 'Life', signed: true);
      for (final value in player.counters.values) {
        bounded(value, 'Player counter');
      }
      require(
        player.commanderDamage.keys.every(sources.contains),
        'Damage references an unknown commander source.',
      );
      for (final value in player.commanderDamage.values) {
        bounded(value, 'Commander damage');
      }
      require(
        player.mana.keys.toSet().containsAll(PlayerState.manaColors) &&
            player.mana.keys.every(PlayerState.manaColors.contains),
        'Invalid mana colors.',
      );
      require(
        player.manaLocks.every(PlayerState.manaColors.contains),
        'Invalid mana lock.',
      );
      for (final value in player.mana.values) {
        bounded(value, 'Mana');
      }
      for (final token in player.tokens) {
        entityIds.add(token.id);
        bounded(token.amount, 'Token amount');
        require(
          token.tapped >= 0 && token.tapped <= token.amount,
          'Tapped tokens exceed stack quantity.',
        );
        require(
          token.summoningSick >= 0 && token.summoningSick <= token.amount,
          'Summoning-sick tokens exceed stack quantity.',
        );
        bounded(token.plusOneCounters, '+1/+1 counters');
        bounded(token.minusOneCounters, '-1/-1 counters');
        for (final value in token.counters.values) {
          bounded(value, 'Token counter');
        }
      }
      final singletonUtilities = <String>{};
      for (final utility in player.utilities) {
        entityIds.add(utility.id);
        bounded(utility.value, 'Utility value', signed: true);
        if (utility.kind == 'mana_pool' || utility.kind == 'storm_count') {
          require(
            singletonUtilities.add(utility.kind),
            'Duplicate ${utility.kind} utility.',
          );
        }
      }
      for (final rule in player.rules) {
        ruleIds.add(rule.id);
        require(
          rule.ownerPlayerId == player.id,
          'A modifier source has the wrong owner.',
        );
        bounded(rule.count, 'Modifier count');
        require(rule.revision >= 0, 'Invalid modifier revision.');
      }
    }
    unique(entityIds, 'Board entities');
    unique(ruleIds, 'Modifier sources');
    unique(game.history.map((value) => value.id), 'History entries');
    for (final entry in game.history) {
      require(
        entry.playerId == null || ids.contains(entry.playerId),
        'History attribution references an unknown player.',
      );
      require(
        entry.affectedPlayerIds.every(ids.contains),
        'History scope references an unknown player.',
      );
      require(entry.commands.isNotEmpty, 'History entry has no commands.');
      for (final command in entry.commands) {
        require(
          command.revision > 0 && command.revision <= game.revision,
          'History command revision is invalid.',
        );
        for (final change in command.changes) {
          require(
            change.path.isNotEmpty &&
                change.path.every((part) => part is String || part is int),
            'History inverse has an invalid field path.',
          );
          require(
            change.path.first == 'session' || change.path.first == 'profiles',
            'History inverse may only restore game state and explicit seat appearance.',
          );
        }
      }
    }
  }

  session(state.session);
  for (final archive in state.archives) {
    session(archive.session);
  }
  // Also proves all extension payloads are JSON-safe before any persistent write.
  jsonEncode(state.toJson());
}

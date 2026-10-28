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
  Box<String>? _backup;
  String? _lastGood;
  int _sequence = 0;

  Future<TableLoadResult> open() async {
    await Hive.initFlutter('tripling_season_tablet');
    final boxes = <String, Box<String>>{};
    final openErrors = <String, Object>{};
    for (final name in [
      boxName,
      '${boxName}_previous',
      '${boxName}_recovery',
    ]) {
      try {
        boxes[name] = await Hive.openBox<String>(name);
      } catch (error) {
        // Never delete/recreate an unreadable Hive container to obtain a clean boot.
        openErrors[name] = error;
      }
    }
    _backup = boxes['${boxName}_previous'];
    final main = boxes[boxName];
    final recovery = boxes['${boxName}_recovery'];
    final current = <({String encoded, Box<String> box})>[
      if (main?.get('current') case final String value)
        (encoded: value, box: main!),
      if (recovery?.get('current') case final String value)
        (encoded: value, box: recovery!),
    ];
    final previous = <({String encoded, Box<String>? box})>[
      if (_backup?.get('current') case final String value)
        (encoded: value, box: _backup),
      // Read the original same-container backup for first-pass v1 compatibility.
      if (main?.get('previous') case final String value)
        (encoded: value, box: main),
      if (recovery?.get('previous') case final String value)
        (encoded: value, box: recovery),
    ];
    current.sort(
      (a, b) =>
          _encodedSequence(b.encoded).compareTo(_encodedSequence(a.encoded)),
    );
    previous.sort(
      (a, b) =>
          _encodedSequence(b.encoded).compareTo(_encodedSequence(a.encoded)),
    );
    if (current.isEmpty && previous.isEmpty && openErrors.isEmpty) {
      _box = main;
      final state = TabletState.initial();
      await save(state);
      return TableLoadResult(state);
    }
    final failures = <String>[];
    var recovered = openErrors.isNotEmpty;
    for (final candidate in current) {
      try {
        final state = _decode(candidate.encoded);
        _box = candidate.box;
        _lastGood = candidate.encoded;
        _sequence = _encodedSequence(candidate.encoded);
        return TableLoadResult(
          state,
          recoveryMessage: recovered
              ? 'The latest storage generation could not be read. A complete saved '
                    'generation was recovered; the original data has been preserved.'
              : null,
        );
      } catch (error) {
        if (error is UnsupportedTableFormat) rethrow;
        failures.add(error.toString());
        recovered = true;
        await _quarantine(candidate.box, candidate.encoded);
      }
    }
    for (final candidate in previous) {
      try {
        final state = _decode(candidate.encoded);
        _box = main ?? recovery;
        if (_box == null) {
          throw StateError(
            'The backup is intact but writable storage is unavailable.',
          );
        }
        _lastGood = candidate.encoded;
        _sequence = _encodedSequence(candidate.encoded);
        return TableLoadResult(
          state,
          recoveryMessage:
              'The latest save could not be read. The preceding complete save was '
              'recovered; the original data has been preserved.',
        );
      } catch (error) {
        if (error is UnsupportedTableFormat) rethrow;
        failures.add(error.toString());
      }
    }
    throw StateError(
      'No complete saved generation could be opened. All original '
      'data has been preserved. ${[...openErrors.values, ...failures].join('; ')}',
    );
  }

  int _encodedSequence(String encoded) {
    try {
      return jsonMap(jsonDecode(encoded))['sequence'] as int? ?? 0;
    } catch (_) {
      // Unknown/damaged envelopes must be inspected before a valid older backup.
      return 0x1fffffffffffff;
    }
  }

  Future<void> _quarantine(Box<String> box, String encoded) async {
    try {
      await box.put(
        'quarantine_${DateTime.now().microsecondsSinceEpoch}',
        encoded,
      );
      await box.flush();
    } catch (_) {
      // The original unreadable record remains in place if storage cannot write.
    }
  }

  Future<void> save(TabletState state) async {
    final box = _box;
    if (box == null) throw StateError('Storage is not open.');
    validateTabletState(state);
    final payload = jsonEncode(state.toJson());
    final encoded = jsonEncode({
      'format': 'tripling-season-tablet',
      'version': 1,
      'sequence': _sequence + 1,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    });
    final old = _lastGood;
    if (old != null) {
      final backup = _backup;
      if (backup != null) {
        await backup.put('current', old);
        await backup.flush();
      } else {
        await box.put('previous', old);
        await box.flush();
      }
    }
    try {
      await box.put('current', encoded);
      await box.flush();
      _lastGood = encoded;
      _sequence++;
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
    require(
      game.profileUndoProtectedThroughRevision >= 0 &&
          game.profileUndoProtectedThroughRevision <= game.revision,
      'Invalid historical appearance boundary.',
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
        // Hidden legacy views retain their settings while Add creates a fresh
        // board view. Only the visible views need to remain singletons.
        if (utility.visible &&
            (utility.kind == 'mana_pool' || utility.kind == 'storm_count')) {
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

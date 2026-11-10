import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/table_state.dart';
import 'storage_namespace.dart';

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

class _DecodedTable {
  final TabletState state;
  final bool needsUpgrade;
  const _DecodedTable(this.state, {required this.needsUpgrade});
}

/// A single aggregate is the transaction boundary for gameplay, undo and archives.
/// The previous validated generation is flushed before promoting its successor.
class TableRepository {
  // Keep physical names: changing this key would hide existing games.
  static const boxName = TableStorageKeys.aggregate;
  static const envelopeVersion = 2;
  final Future<void> Function() _initializeStorage;
  final Future<Box<String>> Function(String) _openBox;
  Box<String>? _box;
  Box<String>? _backup;
  String? _lastGood;
  int _sequence = 0;

  TableRepository()
    : _initializeStorage = (() => Hive.initFlutter('tripling_season_tablet')),
      _openBox = ((name) => Hive.openBox<String>(name));

  /// Exercises the real repository with isolated storage and injected failures.
  TableRepository.forTesting({
    required Future<Box<String>> Function(String) openBox,
  }) : _initializeStorage = (() async {}),
       _openBox = openBox;

  Future<TableLoadResult> open() async {
    // A failed retry must not leave a previously opened writer available.
    _box = null;
    _backup = null;
    _lastGood = null;
    _sequence = 0;
    try {
      return await _open();
    } catch (_) {
      _box = null;
      _lastGood = null;
      rethrow;
    }
  }

  Future<TableLoadResult> _open() async {
    await _initializeStorage();
    final boxes = <String, Box<String>>{};
    final openErrors = <String, Object>{};
    for (final name in [
      boxName,
      '${boxName}_previous',
      '${boxName}_recovery',
    ]) {
      try {
        boxes[name] = await _openBox(name);
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
    final previous = <({String encoded, Box<String> box})>[
      if (_backup?.get('current') case final String value)
        (encoded: value, box: _backup!),
      // Read original same-container backups without renaming or clearing them.
      if (main?.get('previous') case final String value)
        (encoded: value, box: main!),
      if (recovery?.get('previous') case final String value)
        (encoded: value, box: recovery!),
    ];
    // Inspect every live generation before writing anything. In particular, an
    // unsupported backup must not be overwritten by a seemingly usable current.
    for (final candidate in [...current, ...previous]) {
      try {
        _decode(candidate.encoded);
      } on UnsupportedTableFormat {
        rethrow;
      } catch (_) {
        // Ordinary corruption can recover after its exact bytes are retained.
      }
    }
    current.sort(
      (a, b) =>
          _encodedSequence(b.encoded).compareTo(_encodedSequence(a.encoded)),
    );
    previous.sort(
      (a, b) =>
          _encodedSequence(b.encoded).compareTo(_encodedSequence(a.encoded)),
    );
    if (current.isEmpty &&
        previous.isEmpty &&
        openErrors.isEmpty &&
        boxes.values.every((box) => box.isEmpty)) {
      _box = main;
      final state = TabletState.initial();
      await save(state);
      return TableLoadResult(state);
    }
    final failures = <String>[];
    var recovered = openErrors.isNotEmpty;
    for (final candidate in [...current, ...previous]) {
      final _DecodedTable decoded;
      try {
        decoded = _decode(candidate.encoded);
      } on UnsupportedTableFormat {
        rethrow;
      } catch (error) {
        failures.add(error.toString());
        recovered = true;
        // Do not overwrite a damaged generation if its preservation fails.
        await _retain(candidate.box, candidate.encoded, 'quarantine');
        continue;
      }
      final isPrevious = previous.contains(candidate);
      _box = isPrevious ? main ?? recovery : candidate.box;
      if (_box == null) {
        throw StateError(
          'The backup is intact but writable storage is unavailable.',
        );
      }
      _lastGood = candidate.encoded;
      _sequence = _encodedSequence(candidate.encoded);
      if (decoded.needsUpgrade) {
        // Unlike the rolling previous generation, this immutable checkpoint is
        // never an automatic fallback and is never rotated by normal gameplay.
        await _retain(_backup ?? _box!, candidate.encoded, 'before_format_2');
        // Promotion must finish before gameplay can start. IO failure is not
        // corruption: propagate it rather than trying a different/older game.
        await save(decoded.state);
      }
      return TableLoadResult(
        decoded.state,
        recoveryMessage: recovered || isPrevious
            ? 'The latest save could not be read. A complete saved generation '
                  'was recovered; the original data has been preserved.'
            : null,
      );
    }
    throw StateError(
      'No complete saved generation could be opened. All original '
      'data has been preserved. ${[...openErrors.values, ...failures].join('; ')}',
    );
  }

  static int _encodedSequence(String encoded) {
    try {
      final sequence = jsonMap(jsonDecode(encoded))['sequence'] as int? ?? 0;
      if (sequence < 0 || sequence >= 0x1fffffffffffff) {
        throw const FormatException('Invalid save sequence.');
      }
      return sequence;
    } catch (_) {
      // Damaged envelopes must be inspected before a valid older backup.
      return 0x1fffffffffffff;
    }
  }

  Future<void> _retain(Box<String> box, String encoded, String reason) async {
    final key = '${reason}_${sha256.convert(utf8.encode(encoded))}';
    final existing = box.get(key);
    if (existing != null && existing != encoded) {
      throw StateError('The recovery checkpoint could not be verified.');
    }
    if (existing == null) await box.put(key, encoded);
    await box.flush();
    if (box.get(key) != encoded) {
      throw StateError('The recovery checkpoint could not be verified.');
    }
  }

  Future<void> save(TabletState state) async {
    final box = _box;
    if (box == null) throw StateError('Storage is not open.');
    final encoded = encodeGeneration(state, sequence: _sequence + 1);
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

  /// Shared on-disk codec for guarded migration rehearsals. No storage writes.
  static String encodeGeneration(TabletState state, {required int sequence}) {
    if (sequence < 1 || sequence >= 0x1fffffffffffff) {
      throw const FormatException('Invalid save sequence.');
    }
    validateTabletState(state);
    final payload = jsonEncode(state.toJson());
    return jsonEncode({
      'format': 'tripling-season-tablet',
      'version': envelopeVersion,
      'sequence': sequence,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    });
  }

  /// Strict validation, without fallback, repair, initialization or promotion.
  static TabletState decodeGeneration(String encoded) => _decode(encoded).state;

  static _DecodedTable _decode(String encoded) {
    final envelope = jsonMap(jsonDecode(encoded));
    final version = envelope['version'];
    if (envelope['format'] != 'tripling-season-tablet' ||
        (version != 1 && version != envelopeVersion) ||
        envelope.keys.any(
          (key) => !{
            'format',
            'version',
            'sequence',
            'sha256',
            'payload',
          }.contains(key),
        )) {
      throw const UnsupportedTableFormat(
        'This save uses an unsupported tablet format. Open it with the matching '
        'or newer app version; the stored game has not been changed.',
      );
    }
    if (_encodedSequence(encoded) == 0x1fffffffffffff) {
      throw const FormatException('Invalid save sequence.');
    }
    final payload = envelope['payload'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('Saved data integrity check failed.');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonMap(jsonDecode(payload));
    } catch (_) {
      throw const UnsupportedTableFormat(
        'This integrity-checked save cannot be interpreted by this app. '
        'The stored game has not been changed.',
      );
    }
    final schema = json['schemaVersion'];
    if ((version == 1 && schema != 1) ||
        (version == envelopeVersion &&
            schema != TabletState.currentSchemaVersion)) {
      throw const UnsupportedTableFormat(
        'This save requires a different app version. The stored game has not been changed.',
      );
    }
    final TabletState state;
    try {
      state = TabletState.fromJson(json);
    } catch (_) {
      // Integrity succeeded, but this reader cannot interpret the payload.
      // Treat a changed field shape like an unsupported version, not permission
      // to replace it with an older game.
      throw const UnsupportedTableFormat(
        'This save contains data this app cannot interpret. '
        'The stored game has not been changed.',
      );
    }
    // A future writer that accidentally reused a schema must not lose fields or
    // extra players through fallback. Extension maps remain fully supported.
    _requireKnownFields(json, state.toJson());
    if ([
      state.session,
      ...state.archives.map((archive) => archive.session),
    ].any((game) => game.players.length > TabletState.maximumPlayers)) {
      throw const UnsupportedTableFormat(
        'This save needs support for more players. The stored game has not been changed.',
      );
    }
    state.schemaVersion = TabletState.currentSchemaVersion;
    try {
      validateTabletState(state);
    } catch (_) {
      // A valid checksum plus unsupported semantics (for example a new enum or
      // changed bound) is not evidence of storage corruption. Do not repeat the
      // original six-player mistake through a different validator constraint.
      throw const UnsupportedTableFormat(
        'This integrity-checked save needs a compatible app version. '
        'The stored game has not been changed.',
      );
    }
    return _DecodedTable(state, needsUpgrade: version == 1);
  }

  static void _requireKnownFields(dynamic original, dynamic parsed) {
    if (original is Map && parsed is Map) {
      for (final key in original.keys) {
        if (!parsed.containsKey(key)) {
          throw const UnsupportedTableFormat(
            'This save contains fields from a different app version. '
            'The stored game has not been changed.',
          );
        }
        _requireKnownFields(original[key], parsed[key]);
      }
    } else if (original is List && parsed is List) {
      if (original.length != parsed.length) {
        throw const UnsupportedTableFormat(
          'This save contains data this app cannot preserve. '
          'The stored game has not been changed.',
        );
      }
      for (var i = 0; i < original.length; i++) {
        _requireKnownFields(original[i], parsed[i]);
      }
    }
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
      game.players.length >= 2 &&
          game.players.length <= TabletState.maximumPlayers,
      'A game must have two to six players.',
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
      game.players.every(
        (value) =>
            value.slot >= 0 &&
            value.slot < (game.players.length <= 4 ? 4 : game.players.length),
      ),
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

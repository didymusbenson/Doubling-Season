import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../domain/table_state.dart';
import '../storage/table_repository.dart';

/// The only writer for the tablet aggregate. Commands mutate detached drafts;
/// observers see a new state only after its complete save is acknowledged.
class TableController extends ChangeNotifier {
  final TableRepository _repository;
  TabletState _state = TabletState.initial();
  Future<void> _tail = Future<void>.value();
  Future<void>? _initializing;
  int _pending = 0;
  bool _ready = false;
  bool _disposed = false;
  String? _openGroupId;
  String? error;
  String? recoveryMessage;
  static const groupingWindow = Duration(milliseconds: 1500);

  TableController({TableRepository? repository})
    : _repository = repository ?? TableRepository();
  TabletState get state => _state;
  GameSession get session => _state.session;
  bool get busy => _pending > 0;
  bool get ready => _ready;
  bool get canUndo => session.history.any((value) => !value.undone);
  PlayerState player(String id) => session.player(id);
  SeatProfile profile(String seatId) => _state.profiles.firstWhere(
    (value) => value.id == seatId,
    orElse: () => throw StateError('That seat does not exist.'),
  );

  Future<void> initialize() {
    if (_ready) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    _pending++;
    _notify();
    try {
      final loaded = await _repository.open();
      _state = loaded.state;
      recoveryMessage = loaded.recoveryMessage;
      error = null;
      _ready = true;
    } catch (failure) {
      error =
          'The table could not be opened. Your stored data is preserved. '
          '${_message(failure)}';
    } finally {
      _pending--;
      _notify();
    }
  }

  Future<bool> _enqueue(Future<void> Function() action) {
    final result = Completer<bool>();
    _pending++;
    _notify();
    _tail = _tail.then((_) async {
      try {
        if (!_ready) {
          throw StateError('Open the saved table before making changes.');
        }
        await action();
        error = null;
        result.complete(true);
      } catch (failure) {
        _openGroupId = null;
        error = _message(failure);
        result.complete(false);
      } finally {
        _pending--;
        _notify();
      }
    });
    return result.future;
  }

  static String _message(Object failure) => failure
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('FormatException: ', '');
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    error = null;
    _notify();
  }

  void settleHistoryGroup() {
    _openGroupId = null;
  }

  Future<bool> commit(
    String label, {
    String? playerId,
    String? groupKey,
    String? commandId,
    String? expectedSessionId,
    int? expectedGeneration,
    int? expectedPlayerGeneration,
    List<String>? affectedPlayerIds,
    int? delta,
    int Function(GameSession before, GameSession after)? effectiveDelta,
    String Function(int delta)? describeDelta,
    required void Function(GameSession) mutate,
  }) {
    final scopeId = expectedSessionId ?? session.id;
    final scopeGeneration = expectedGeneration ?? session.generation;
    final id = commandId ?? newEntityId();
    return _enqueue(() async {
      _guard(scopeId, scopeGeneration, playerId, expectedPlayerGeneration);
      if (session.completedCommandIds.contains(id)) return;
      final draft = _state.copy();
      mutate(draft.session);
      _validateCommandScope(draft, playerId, affectedPlayerIds);
      // Calculate clamped/rules-adjusted changes inside the serialized command.
      // Reading the current value before enqueueing would race rapid actions.
      final recordedDelta =
          effectiveDelta?.call(session, draft.session) ?? delta;
      final recordedLabel = recordedDelta != null && describeDelta != null
          ? describeDelta(recordedDelta)
          : label;
      final entryId = _record(
        _state,
        draft,
        recordedLabel,
        playerId: playerId,
        affectedPlayerIds: affectedPlayerIds,
        groupKey: groupKey,
        commandId: id,
        delta: recordedDelta,
      );
      if (entryId == null) {
        // Acknowledged no-ops are also idempotent if a caller retries later.
        draft.session.completedCommandIds.add(id);
        draft.session.revision = session.revision + 1;
        await _publish(draft);
        _openGroupId = null;
        return;
      }
      await _publish(draft);
      _openGroupId = entryId;
    });
  }

  /// Non-game library/profile/settings updates share the same durable writer.
  /// recordHistory is used by seat preset loads that also apply life artwork.
  Future<bool> updateState(
    String label,
    void Function(TabletState) mutate, {
    bool recordHistory = false,
    String? playerId,
    List<String>? affectedPlayerIds,
    String? expectedSessionId,
    int? expectedGeneration,
    int? expectedPlayerGeneration,
  }) {
    final scopeId = expectedSessionId ?? session.id;
    final scopeGeneration = expectedGeneration ?? session.generation;
    return _enqueue(() async {
      _guard(scopeId, scopeGeneration, playerId, expectedPlayerGeneration);
      final draft = _state.copy();
      mutate(draft);
      _validateCommandScope(draft, playerId, affectedPlayerIds);
      final changesGame = !_equal(
        _historyProjection(_state, includeProfiles: true),
        _historyProjection(draft, includeProfiles: true),
      );
      if (recordHistory) {
        _record(
          _state,
          draft,
          label,
          playerId: playerId,
          affectedPlayerIds: affectedPlayerIds,
          includeProfiles: true,
          commandId: newEntityId(),
        );
      }
      await _publish(draft);
      if (recordHistory || changesGame) _openGroupId = null;
    });
  }

  Future<bool> modifyLibrary(void Function(TabletState) mutate) =>
      updateState('Update library', mutate);

  void _guard(
    String id,
    int generation,
    String? playerId,
    int? playerGeneration,
  ) {
    if (session.id != id || session.generation != generation) {
      throw StateError(
        'The game changed while this action was open. Reopen it to continue.',
      );
    }
    if (playerId != null) {
      final target = session.player(playerId);
      if (playerGeneration != null && target.generation != playerGeneration) {
        throw StateError(
          'This player’s board changed. Reopen the action to continue.',
        );
      }
    }
  }

  void _validateCommandScope(
    TabletState draft,
    String? playerId,
    List<String>? affectedPlayerIds,
  ) {
    if (draft.session.id != session.id ||
        draft.session.generation != session.generation ||
        !const ListEquality<String>().equals(
          session.players.map((value) => value.id).toList(),
          draft.session.players.map((value) => value.id).toList(),
        )) {
      throw StateError(
        'Game membership changes require a full game transition.',
      );
    }
    if (playerId == null) return;
    final allowed = (affectedPlayerIds ?? [playerId]).toSet();
    for (final target in draft.session.players) {
      if (!allowed.contains(target.id) &&
          !_equal(session.player(target.id).toJson(), target.toJson())) {
        throw StateError(
          'This action changed a player outside its declared scope.',
        );
      }
    }
  }

  Future<void> _publish(TabletState draft) async {
    validateTabletState(draft);
    await _repository.save(draft);
    _state = draft;
  }

  String? _record(
    TabletState before,
    TabletState draft,
    String label, {
    String? playerId,
    String? groupKey,
    List<String>? affectedPlayerIds,
    required String commandId,
    int? delta,
    bool includeProfiles = false,
  }) {
    final beforeJson = _historyProjection(
      before,
      includeProfiles: includeProfiles,
    );
    final afterJson = _historyProjection(
      draft,
      includeProfiles: includeProfiles,
    );
    final changes = <HistoryChange>[];
    _diff(beforeJson, afterJson, [], changes);
    if (changes.isEmpty) return null;
    draft.session.revision = before.session.revision + 1;
    draft.session.completedCommandIds.add(commandId);
    final now = DateTime.now().toUtc();
    final affected = affectedPlayerIds ?? _affectedPlayers(before, draft);
    final command = HistoryCommand(
      id: commandId,
      label: label,
      at: now,
      revision: draft.session.revision,
      delta: delta,
      changes: changes,
      tokenChanges: _tokenQuantityChanges(before.session, draft.session),
    );
    final last = draft.session.history.lastOrNull;
    final canGroup =
        groupKey != null &&
        last != null &&
        !last.undone &&
        last.id == _openGroupId &&
        last.groupKey == groupKey &&
        last.playerId == playerId &&
        const ListEquality<String>().equals(last.affectedPlayerIds, affected) &&
        now.difference(last.updatedAt) <= groupingWindow;
    if (canGroup) {
      last.commands.add(command);
      last.updatedAt = now;
      return last.id;
    }
    final entry = HistoryEntry(
      id: newEntityId(),
      label: label,
      playerId: playerId,
      playerLabel: playerId == null
          ? null
          : before.profiles
                .firstWhere(
                  (value) => value.id == before.session.player(playerId).seatId,
                )
                .name,
      groupKey: groupKey,
      createdAt: now,
      updatedAt: now,
      affectedPlayerIds: affected,
      commands: [command],
    );
    draft.session.history.add(entry);
    return entry.id;
  }

  List<String> _affectedPlayers(TabletState before, TabletState after) {
    final result = <String>[];
    for (final player in after.session.players) {
      final previous = before.session.players.firstWhereOrNull(
        (value) => value.id == player.id,
      );
      if (previous == null || !_equal(previous.toJson(), player.toJson())) {
        result.add(player.id);
      }
    }
    if (before.session.monarchPlayerId != after.session.monarchPlayerId) {
      for (final id in [
        before.session.monarchPlayerId,
        after.session.monarchPlayerId,
      ]) {
        if (id != null && !result.contains(id)) result.add(id);
      }
    }
    if (before.session.dayNight != after.session.dayNight) {
      for (final player in after.session.players) {
        if (!result.contains(player.id)) result.add(player.id);
      }
    }
    result.sort();
    return result;
  }

  List<TokenQuantityChange> _tokenQuantityChanges(
    GameSession before,
    GameSession after,
  ) {
    final result = <TokenQuantityChange>[];
    for (final player in after.players) {
      final prior = before.player(player.id);
      final oldTokens = {for (final token in prior.tokens) token.id: token};
      final newTokens = {for (final token in player.tokens) token.id: token};
      for (final id in {...oldTokens.keys, ...newTokens.keys}) {
        final oldToken = oldTokens[id];
        final newToken = newTokens[id];
        final delta = (newToken?.amount ?? 0) - (oldToken?.amount ?? 0);
        if (delta == 0) continue;
        final token = newToken ?? oldToken!;
        result.add(
          TokenQuantityChange(
            playerId: player.id,
            entityId: token.id,
            definitionId: token.definitionId,
            name: token.name,
            delta: delta,
          ),
        );
      }
    }
    return result;
  }

  Map<String, dynamic> _historyProjection(
    TabletState state, {
    bool includeProfiles = false,
  }) {
    final game = cloneJson(state.session.toJson(includeHistory: false))
      ..remove('revision')
      ..remove('generation')
      ..remove('profileUndoProtectedThroughRevision')
      ..remove('completedCommandIds');
    // Epochs invalidate delayed work and must never rewind with gameplay undo.
    for (final player in game['players'] as List) {
      (player as Map).remove('generation');
    }
    return {
      'session': game,
      if (includeProfiles)
        'profiles': state.profiles.map((value) => value.toJson()).toList(),
    };
  }

  Future<bool> undo() => _enqueue(() async {
    final entry = session.history.lastWhereOrNull((value) => !value.undone);
    if (entry == null) {
      throw StateError('There are no actions to undo in this game.');
    }
    final json = cloneJson(_state.toJson());
    var preservedAppearance = false;
    for (final command in entry.commands.reversed) {
      for (final change in command.changes.reversed) {
        if (change.path.first == 'profiles') {
          // Permanent customization is independent of archived game state.
          // A later profile choice wins over historical preset appearance.
          if (command.revision <= session.profileUndoProtectedThroughRevision) {
            preservedAppearance = true;
            continue;
          }
          try {
            _applyInverse(json, change);
          } on StateError {
            preservedAppearance = true;
          }
          continue;
        }
        _applyInverse(json, change);
      }
    }
    final draft = TabletState.fromJson(json);
    for (final player in draft.session.players) {
      final current = session.player(player.id);
      if (!_equal(player.toJson(), current.toJson())) {
        player.generation = math.max(player.generation, current.generation) + 1;
      }
    }
    draft.session.history.firstWhere((value) => value.id == entry.id)
      ..undone = true
      ..undoNote = preservedAppearance
          ? 'Game action undone. Current saved player appearance was kept.'
          : null;
    draft.session.revision = session.revision + 1;
    await _publish(draft);
    _openGroupId = null;
  });

  Future<bool> adjustLife(String playerId, int delta) => commit(
    'Life ${delta >= 0 ? '+' : ''}$delta',
    playerId: playerId,
    groupKey: 'life:$playerId',
    delta: delta,
    mutate: (game) => game.player(playerId).life += delta,
  );
  Future<bool> setLife(String playerId, int value) => commit(
    'Set life to $value',
    playerId: playerId,
    mutate: (game) => game.player(playerId).life = value,
  );
  Future<bool> adjustPlayerCounter(String playerId, String key, int delta) =>
      commit(
        '$key ${delta >= 0 ? '+' : ''}$delta',
        playerId: playerId,
        groupKey: 'player-counter:$playerId:$key:${delta.sign}',
        delta: delta,
        effectiveDelta: (before, after) =>
            (after.player(playerId).counters[key] ?? 0) -
            (before.player(playerId).counters[key] ?? 0),
        describeDelta: (actual) => '$key ${actual >= 0 ? '+' : ''}$actual',
        mutate: (game) {
          final counters = game.player(playerId).counters;
          counters[key] = math.max(0, (counters[key] ?? 0) + delta);
        },
      );
  Future<bool> setPlayerCounter(String playerId, String key, int value) =>
      commit(
        'Set $key to $value',
        playerId: playerId,
        mutate: (game) => game.player(playerId).counters[key] = value,
      );
  Future<bool> setCitysBlessing(String playerId, bool value) => commit(
    value ? 'Gain city’s blessing' : 'Clear city’s blessing',
    playerId: playerId,
    mutate: (game) => game.player(playerId).citysBlessing = value,
  );
  Future<bool> setMonarch(String? playerId) => commit(
    playerId == null ? 'Clear monarch' : 'Claim monarch',
    playerId: playerId,
    mutate: (game) => game.monarchPlayerId = playerId,
  );
  Future<bool> setDayNight(String value) =>
      commit('Set day/night: $value', mutate: (game) => game.dayNight = value);
  Future<bool> addCommander(String playerId, String name) => commit(
    'Add commander source: $name',
    playerId: playerId,
    mutate: (game) {
      if (name.trim().isEmpty) {
        throw StateError('Enter a commander source name.');
      }
      game.commanders.add(
        CommanderSource(
          id: newEntityId(),
          ownerPlayerId: playerId,
          name: name.trim(),
        ),
      );
    },
  );
  Future<bool> renameCommander(String sourceId, String name) => commit(
    'Rename commander source',
    mutate: (game) {
      if (name.trim().isEmpty) {
        throw StateError('Enter a commander source name.');
      }
      game.commanders.firstWhere((value) => value.id == sourceId).name = name
          .trim();
    },
  );
  Future<bool> removeCommander(String sourceId) => commit(
    'Remove commander source',
    mutate: (game) {
      if (game.players.any(
        (value) => (value.commanderDamage[sourceId] ?? 0) != 0,
      )) {
        throw StateError(
          'Correct this source’s damage to zero before removing it. '
          'Renaming keeps recorded damage intact.',
        );
      }
      game.commanders.removeWhere((value) => value.id == sourceId);
      for (final player in game.players) {
        player.commanderDamage.remove(sourceId);
      }
    },
  );
  Future<bool> adjustCommanderDamage(
    String recipientId,
    String sourceId,
    int delta, {
    bool adjustLife = true,
  }) => commit(
    adjustLife
        ? '${_commanderName(sourceId)} damage ${delta >= 0 ? '+' : ''}$delta'
        : 'Correct ${_commanderName(sourceId)} damage ${delta >= 0 ? '+' : ''}$delta',
    playerId: recipientId,
    groupKey: 'commander:$recipientId:$sourceId:$adjustLife:${delta.sign}',
    delta: delta,
    effectiveDelta: (before, after) =>
        (after.player(recipientId).commanderDamage[sourceId] ?? 0) -
        (before.player(recipientId).commanderDamage[sourceId] ?? 0),
    describeDelta: (actual) =>
        '${adjustLife ? '' : 'Correct '}${_commanderName(sourceId)} damage '
        '${actual >= 0 ? '+' : ''}$actual',
    mutate: (game) {
      if (!game.commanders.any((value) => value.id == sourceId)) {
        final projected = game.commanderTrackingSources.firstWhereOrNull(
          (s) => s.id == sourceId,
        );
        if (projected == null)
          throw StateError('This commander source no longer exists.');
        if (delta <= 0) return;
        game.commanders.add(projected.copy());
      }
      final recipient = game.player(recipientId);
      final before = recipient.commanderDamage[sourceId] ?? 0;
      final after = math.max(0, before + delta);
      if (before == after) return;
      recipient.commanderDamage[sourceId] = after;
      if (adjustLife) recipient.life -= after - before;
    },
  );
  Future<bool> setCommanderDamage(
    String recipientId,
    String sourceId,
    int value,
  ) => commit(
    'Correct ${_commanderName(sourceId)} damage to $value',
    playerId: recipientId,
    mutate: (game) {
      if (value < 0) throw ArgumentError('Damage cannot be negative.');
      if (!game.commanders.any((s) => s.id == sourceId)) {
        final projected = game.commanderTrackingSources.firstWhereOrNull(
          (s) => s.id == sourceId,
        );
        if (projected == null)
          throw StateError('This commander source no longer exists.');
        if (value == 0) return;
        game.commanders.add(projected.copy());
      }
      final recipient = game.player(recipientId);
      if ((recipient.commanderDamage[sourceId] ?? 0) == value) return;
      recipient.commanderDamage[sourceId] = value;
    },
  );

  String _commanderName(String sourceId) {
    final sources = session.commanderTrackingSources;
    final source = sources.firstWhereOrNull((s) => s.id == sourceId);
    if (source == null) return 'Commander';
    final siblings = sources
        .where((s) => s.ownerPlayerId == source.ownerPlayerId)
        .toList();
    final owner = profile(session.player(source.ownerPlayerId).seatId).name;
    final ordinal = siblings.length > 1
        ? ' #${siblings.indexWhere((s) => s.id == sourceId) + 1}'
        : '';
    return '$owner: ${source.name}$ordinal';
  }

  Future<bool> adjustMana(String playerId, String color, int delta) => commit(
    '$color mana ${delta >= 0 ? '+' : ''}$delta',
    playerId: playerId,
    groupKey: 'mana:$playerId:$color:${delta.sign}',
    delta: delta,
    effectiveDelta: (before, after) =>
        after.player(playerId).mana[color]! -
        before.player(playerId).mana[color]!,
    describeDelta: (actual) => '$color mana ${actual >= 0 ? '+' : ''}$actual',
    mutate: (game) {
      _manaColor(color);
      final mana = game.player(playerId).mana;
      mana[color] = math.max(0, mana[color]! + delta);
    },
  );
  Future<bool> toggleManaLock(String playerId, String color) => commit(
    'Change $color mana empty protection',
    playerId: playerId,
    mutate: (game) {
      _manaColor(color);
      final locks = game.player(playerId).manaLocks;
      if (!locks.remove(color)) locks.add(color);
    },
  );
  Future<bool> emptyMana(String playerId) => commit(
    'Empty unlocked mana',
    playerId: playerId,
    mutate: (game) {
      final player = game.player(playerId);
      for (final color in PlayerState.manaColors) {
        if (!player.manaLocks.contains(color)) player.mana[color] = 0;
      }
    },
  );
  Future<bool> convertMana(String playerId, String color) => commit(
    'Convert all mana to $color',
    playerId: playerId,
    mutate: (game) {
      _manaColor(color);
      final mana = game.player(playerId).mana;
      final total = mana.values.fold(0, (sum, value) => sum + value);
      for (final key in PlayerState.manaColors) {
        mana[key] = key == color ? total : 0;
      }
    },
  );
  void _manaColor(String color) {
    if (!PlayerState.manaColors.contains(color)) {
      throw StateError('Unknown mana color.');
    }
  }

  Future<bool> resetGame({
    required bool keepBoard,
    int? playerCount,
    int? startingLife,
    int? emptySlot,
  }) => _enqueue(() async {
    final count = playerCount ?? session.players.length;
    final life = startingLife ?? session.startingLife;
    if (count < 2 || count > 4) {
      throw StateError('Choose two, three or four players.');
    }
    if (life < 1) throw StateError('Starting life must be positive.');
    if (emptySlot != null && (emptySlot < 0 || emptySlot > 3)) {
      throw StateError('Choose one of the four empty-slot positions.');
    }
    final draft = _state.copy();
    _archiveCurrent(
      draft,
      keepBoard ? 'Before reset with board' : 'Before complete reset',
    );
    // Roster identity does not depend on visual slots; hidden seats survive.
    final selectedProfiles = draft.profiles.take(count).toList();
    final savedDefinitions = jsonMap(
      draft.library['seatRuleDefinitions'] ?? {},
    );
    for (final previous in draft.session.players) {
      savedDefinitions[previous.seatId] = previous.rules
          .map(
            (rule) => rule.copy()
              ..enabled = false
              ..count = rule.definitionId == 'custom' ? rule.count : 0,
          )
          .map((rule) => rule.toJson())
          .toList();
    }
    draft.library['seatRuleDefinitions'] = savedDefinitions;
    final slots = count == 2
        ? [0, 2]
        : [
            for (var slot = 0; slot < 4; slot++)
              if (count == 4 || slot != (emptySlot ?? 1)) slot,
          ];
    final players = <PlayerState>[];
    final oldToNew = <String, String>{};
    for (var index = 0; index < count; index++) {
      final seat = selectedProfiles[index];
      final prior = draft.session.players.firstWhereOrNull(
        (value) => value.seatId == seat.id,
      );
      final id = newEntityId();
      if (prior != null) oldToNew[prior.id] = id;
      final next = PlayerState(
        id: id,
        seatId: seat.id,
        slot: slots[index],
        life: life,
        generation: (prior?.generation ?? 0) + 1,
        summoningSicknessEnabled: prior?.summoningSicknessEnabled ?? true,
      );
      if (keepBoard && prior != null) {
        next.tokens = prior.tokens
            .map(
              (value) => value.copy()
                ..amount = 0
                ..tapped = 0
                ..summoningSick = 0
                ..plusOneCounters = 0
                ..minusOneCounters = 0
                ..counters.clear(),
            )
            .toList();
        next.utilities = prior.utilities
            .map(
              (value) => value.copy()
                ..value = value.defaultValue
                ..isActive = false,
            )
            .toList();
        next.artPreferences = Map.from(prior.artPreferences);
      } else {
        // Complete reset and newly active seats start with the default tools,
        // never a previous game's custom utility selection or runtime values.
        next.utilities = defaultUtilities();
      }
      // Reusable definitions survive; activation never carries into a new game.
      final definitions =
          prior?.rules ??
          (savedDefinitions[seat.id] as List? ?? [])
              .map((value) => ModifierSource.fromJson(jsonMap(value)))
              .toList();
      if (definitions.isNotEmpty) {
        next.rules = definitions
            .map(
              (value) => value.copy()
                ..ownerPlayerId = id
                ..enabled = false
                ..count = value.definitionId == 'custom' ? value.count : 0
                ..revision = value.revision + 1,
            )
            .toList();
      }
      players.add(next);
    }
    final sources = <CommanderSource>[];
    for (final source in draft.session.commanders) {
      final owner = oldToNew[source.ownerPlayerId];
      if (owner != null) {
        sources.add(
          CommanderSource(
            id: newEntityId(),
            ownerPlayerId: owner,
            name: source.name,
          ),
        );
      }
    }
    draft.session = GameSession(
      id: newEntityId(),
      generation: session.generation + 1,
      startingLife: life,
      players: players,
      commanders: sources,
    );
    await _publish(draft);
    _openGroupId = null;
  });

  Future<bool> restoreArchive(String archiveId) => _enqueue(() async {
    final selected = _state.archives.firstWhereOrNull(
      (value) => value.id == archiveId,
    );
    if (selected == null) {
      throw StateError('That archived game is no longer available.');
    }
    // Capture before adding the outgoing game: the selected oldest item can be evicted.
    final restored = selected.session.copy();
    final draft = _state.copy();
    _archiveCurrent(draft, 'Before restoring ${selected.label}');
    restored.generation = math.max(session.generation, restored.generation) + 1;
    restored.profileUndoProtectedThroughRevision = restored.revision;
    draft.session = restored;
    await _publish(draft);
    _openGroupId = null;
  });

  void _archiveCurrent(TabletState draft, String label) {
    draft.archives.add(
      GameArchive(
        id: newEntityId(),
        label: label,
        savedAt: DateTime.now().toUtc(),
        session: draft.session.copy(),
        playerLabels: {
          for (final player in draft.session.players)
            player.id: draft.profiles
                .firstWhere((value) => value.id == player.seatId)
                .name,
        },
      ),
    );
    if (draft.archives.length > 10) {
      draft.archives.removeRange(0, draft.archives.length - 10);
    }
  }

  Future<void> flush() async {
    settleHistoryGroup();
    await _tail;
    await _repository.flush();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _equal(dynamic a, dynamic b) =>
    const DeepCollectionEquality().equals(a, b);

void _diff(
  dynamic before,
  dynamic after,
  List<dynamic> path,
  List<HistoryChange> result,
) {
  if (_equal(before, after)) return;
  if (before is Map && after is Map) {
    for (final key in {...before.keys, ...after.keys}) {
      if (!before.containsKey(key) || !after.containsKey(key)) {
        result.add(
          HistoryChange(
            path: [...path, key],
            before: before[key],
            after: after[key],
            beforeExists: before.containsKey(key),
            afterExists: after.containsKey(key),
          ),
        );
      } else {
        _diff(before[key], after[key], [...path, key], result);
      }
    }
    return;
  }
  if (before is List && after is List && before.length == after.length) {
    final keyed =
        before.every((item) => item is Map && item['id'] is String) &&
        after.every((item) => item is Map && item['id'] is String);
    if (keyed) {
      final beforeIds = before.map((item) => (item as Map)['id']).toList();
      final afterIds = after.map((item) => (item as Map)['id']).toList();
      if (!_equal(beforeIds, afterIds)) {
        result.add(HistoryChange(path: path, before: before, after: after));
        return;
      }
      for (var index = 0; index < before.length; index++) {
        _diff(before[index], after[index], [
          ...path,
          '@id:${beforeIds[index]}',
        ], result);
      }
      return;
    }
    for (var index = 0; index < before.length; index++) {
      _diff(before[index], after[index], [...path, index], result);
    }
    return;
  }
  result.add(HistoryChange(path: path, before: before, after: after));
}

void _applyInverse(Map<String, dynamic> json, HistoryChange change) {
  dynamic parent = json;
  for (final key in change.path.take(change.path.length - 1)) {
    if (parent is Map && parent.containsKey(key)) {
      parent = parent[key];
    } else if (parent is List && _listIndex(parent, key) != null) {
      parent = parent[_listIndex(parent, key)!];
    } else {
      throw StateError(
        'Undo cannot safely find the original field. No changes were made.',
      );
    }
  }
  final key = change.path.last;
  final index = parent is List ? _listIndex(parent, key) : null;
  final exists = parent is Map ? parent.containsKey(key) : index != null;
  final current = exists ? parent[parent is List ? index : key] : null;
  if (exists != change.afterExists ||
      (exists && !_equal(current, change.after))) {
    throw StateError(
      'A field changed after this action. Undo was stopped to preserve newer data.',
    );
  }
  if (parent is Map) {
    if (change.beforeExists) {
      parent[key] = _jsonValueCopy(change.before);
    } else {
      parent.remove(key);
    }
  } else if (parent is List && index != null && change.beforeExists) {
    parent[index] = _jsonValueCopy(change.before);
  } else {
    throw StateError('This history entry cannot be restored safely.');
  }
}

int? _listIndex(List<dynamic> list, dynamic key) {
  if (key is int) return key >= 0 && key < list.length ? key : null;
  if (key is String && key.startsWith('@id:')) {
    final index = list.indexWhere(
      (value) => value is Map && value['id'] == key.substring(4),
    );
    return index < 0 ? null : index;
  }
  return null;
}

dynamic _jsonValueCopy(dynamic value) =>
    value == null ? null : jsonDecode(jsonEncode(value));

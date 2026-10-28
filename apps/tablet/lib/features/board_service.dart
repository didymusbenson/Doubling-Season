import 'dart:math';
import 'package:doubling_season/database/widget_database.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/models/widget_definition.dart';
import 'package:doubling_season/providers/rules_provider.dart'
    show TokenCreationResult;
import 'package:doubling_season/utils/constants.dart';
import '../domain/table_controller.dart';
import '../domain/table_state.dart';
import '../services/scoped_rules_calculator.dart';
import '../services/tablet_catalog.dart';

/// Captured when an editor opens, before any asynchronous picker or preview.
class BoardScope {
  final String sessionId, playerId;
  final int generation, playerGeneration;
  const BoardScope(
    this.sessionId,
    this.playerId,
    this.generation,
    this.playerGeneration,
  );
}

class BoardService {
  final TableController controller;
  final TabletCatalog catalog;
  BoardService(this.controller, this.catalog);
  static const modifierDefinitions = <String, String>{
    'token_doubler': 'Token doubler',
    'doubling_season': 'Doubling Season',
    'primal_vigor': 'Primal Vigor',
    'ojer_taq': 'Ojer Taq',
    'academy_manufactor': 'Academy Manufactor',
    'chatterfang': 'Chatterfang',
    'plus_one_doubler': '+1/+1 counter doubler',
    'plus_one_extra': 'Extra +1/+1 counter',
    'all_counter_doubler': 'All counter doubler',
  };
  BoardScope scope(String playerId) {
    final s = controller.session;
    final p = _player(s, playerId);
    return BoardScope(s.id, playerId, s.generation, p.generation);
  }

  PlayerState _player(GameSession s, String id) => s.players.firstWhere(
    (p) => p.id == id,
    orElse: () => throw StateError('This seat is no longer in this game'),
  );
  TokenState _token(PlayerState p, String id) => p.tokens.firstWhere(
    (t) => t.id == id,
    orElse: () => throw StateError('This token is no longer on this board'),
  );
  UtilityState _utility(PlayerState p, String id) => p.utilities.firstWhere(
    (u) => u.id == id,
    orElse: () => throw StateError('This utility is no longer on this board'),
  );
  Future<void> _commit(
    String playerId,
    String label,
    void Function(GameSession, PlayerState) mutate, {
    BoardScope? captured,
    String? groupKey,
    int? delta,
    int? expectedRevision,
    bool gameOrigin = false,
    List<String>? affectedPlayerIds,
    int Function(GameSession before, GameSession after)? effectiveDelta,
    String Function(int delta)? describeDelta,
  }) async {
    final c = captured ?? scope(playerId);
    final ok = await controller.commit(
      label,
      playerId: gameOrigin ? null : playerId,
      affectedPlayerIds: affectedPlayerIds ?? (gameOrigin ? [playerId] : null),
      groupKey: groupKey,
      delta: delta,
      effectiveDelta: effectiveDelta,
      describeDelta: describeDelta,
      expectedSessionId: c.sessionId,
      expectedGeneration: c.generation,
      expectedPlayerGeneration: c.playerGeneration,
      mutate: (s) {
        if (expectedRevision != null && s.revision != expectedRevision) {
          throw StateError(
            'The board or rules changed. Review the updated preview before continuing.',
          );
        }
        final target = _player(s, playerId);
        if (target.generation != c.playerGeneration) {
          throw StateError(
            'This player’s board changed. Reopen the action to continue.',
          );
        }
        mutate(s, target);
      },
    );
    if (!ok) {
      throw StateError(controller.error ?? 'The change could not be saved');
    }
  }

  List<ModifierSource> _sources(GameSession s, String playerId) => [
    for (final owner in s.players)
      for (final source in owner.rules)
        if (source.ownerPlayerId == playerId || source.global) source,
  ];
  List<ModifierSource> effectiveSources(String playerId) =>
      _sources(controller.session, playerId);
  ScopedRulesCalculator _rules(GameSession s, String id) =>
      ScopedRulesCalculator(_sources(s, id));
  List<TokenCreationResult> preview(
    String playerId,
    TokenDefinition def,
    int quantity, {
    int forceAcademyManufactorCount = 0,
  }) {
    _quantity(quantity);
    return _rules(controller.session, playerId).evaluateRules(
      def.name,
      def.pt,
      def.colors,
      def.type,
      def.abilities,
      quantity,
      forceAcademyManufactorCount: forceAcademyManufactorCount,
    );
  }

  void _quantity(int n) {
    if (n < 0 || n > GameConstants.maxTokenQuantity) {
      throw RangeError(
        'Use a quantity from 0 to ${GameConstants.maxTokenQuantity}',
      );
    }
  }

  bool _creature(TokenState t) => t.pt.trim().isNotEmpty;
  bool _emblem(TokenState t) => t.isEmblem;
  bool _hasCreatureSubtype(TokenState t, String subtype) {
    if (RegExp(
      r'\b' + RegExp.escape(subtype) + r'\b',
      caseSensitive: false,
    ).hasMatch(t.type)) {
      return true;
    }
    // Catalog keyword abilities may be flattened ("Changeling Deathtouch").
    // Recognize an actual keyword-only ability, never a rules-text mention such
    // as "Creatures with changeling get ..." or "Changeling creatures ...".
    final abilities = t.abilities.replaceAll(RegExp(r'\([^)]*\)'), '');
    final keywords = RegExp(
      r'^(?:(?:changeling|deathtouch|defender|double strike|first strike|flying|haste|hexproof|indestructible|lifelink|menace|reach|trample|vigilance)\s*)+$',
      caseSensitive: false,
    );
    return abilities.split(RegExp(r'[\n,;.]')).any((part) {
      final ability = part.trim();
      return keywords.hasMatch(ability) &&
          RegExp(r'\bchangeling\b', caseSensitive: false).hasMatch(ability);
    });
  }

  bool _clean(TokenState t) =>
      t.plusOneCounters == 0 &&
      t.minusOneCounters == 0 &&
      t.counters.values.every((n) => n == 0);
  bool _compatible(TokenState a, TokenState b) =>
      a.name == b.name &&
      a.pt == b.pt &&
      a.colors == b.colors &&
      a.type == b.type &&
      a.abilities == b.abilities &&
      a.artworkUrl == b.artworkUrl &&
      _clean(a) &&
      _clean(b);
  TokenDefinition definition(TokenState t) => TokenDefinition(
    name: t.name,
    pt: t.pt,
    abilities: t.abilities,
    colors: t.colors,
    type: t.type,
    popularity: 0,
    artwork: t.artworkOptions.map(ArtworkVariant.fromJson).toList(),
  );
  TokenDefinition _definitionId(String id) {
    final found = catalog.byId(id);
    if (found != null) return found;
    final parts = id.split('|');
    if (parts.length != 5) {
      throw const FormatException('Invalid token identity');
    }
    return TokenDefinition(
      name: parts[0],
      pt: parts[1],
      colors: parts[2],
      type: parts[3],
      abilities: parts[4],
      popularity: 0,
    );
  }

  TokenState _fromDefinition(
    TokenDefinition d,
    int quantity, {
    String? artworkUrl,
    String? artworkSet,
    bool tapped = false,
    bool sickness = true,
  }) {
    final art =
        artworkUrl ?? (d.artwork.isNotEmpty ? d.artwork.first.url : null);
    String? selectedSet = artworkSet;
    if (selectedSet == null && art != null) {
      for (final variant in d.artwork) {
        if (variant.url == art) {
          selectedSet = variant.set;
          break;
        }
      }
    }
    return TokenState(
      id: newEntityId(),
      definitionId: d.id,
      name: d.name,
      pt: d.pt,
      colors: d.colors,
      type: d.type,
      abilities: d.abilities,
      amount: quantity,
      tapped: tapped ? quantity : 0,
      summoningSick:
          sickness &&
              d.pt.trim().isNotEmpty &&
              !d.abilities.toLowerCase().contains('haste')
          ? quantity
          : 0,
      artworkUrl: art,
      artworkSet: selectedSet,
      artworkOptions: d.artwork.map((a) => a.toJson()).toList(),
    );
  }

  void _entered(PlayerState p, TokenState token, int quantity) {
    if (!_creature(token) || quantity <= 0) return;
    for (final u in p.utilities.where((u) => u.kind == 'cathars_crusade')) {
      u.value = min(GameConstants.maxTokenQuantity, u.value + quantity);
    }
  }

  void _addResults(
    GameSession session,
    PlayerState p,
    List<TokenCreationResult> results, {
    TokenState? source,
    bool tapped = false,
    bool merge = true,
    int? insertionIndex,
    String? selectedArtwork,
    TokenDefinition? selectedDefinition,
  }) {
    var next = insertionIndex ?? p.tokens.length;
    for (final result in results) {
      if (result.quantity <= 0) continue;
      // Results already carry the full identity. Do not split a composite ID:
      // raw inline abilities/name may themselves contain the separator.
      final d =
          catalog.byId(result.compositeId) ??
          TokenDefinition(
            name: result.name,
            pt: result.pt,
            colors: result.colors,
            type: result.type,
            abilities: result.abilities,
            popularity: 0,
          );
      final sameSource =
          source != null &&
          source.name == result.name &&
          source.pt == result.pt &&
          source.colors == result.colors &&
          source.type == result.type &&
          source.abilities == result.abilities;
      final art = sameSource
          ? source.artworkUrl
          : (selectedDefinition?.id == result.compositeId
                ? selectedArtwork
                : p.artPreferences[result.compositeId]);
      final t = _fromDefinition(
        d,
        result.quantity,
        artworkUrl: art,
        artworkSet: sameSource ? source.artworkSet : null,
        tapped: tapped,
        sickness: p.summoningSicknessEnabled,
      );
      if (sameSource) {
        t.artworkUrl = source.artworkUrl;
        t.artworkSet = source.artworkSet;
        if (source.extra.containsKey('artworkDisplayStyle')) {
          t.extra['artworkDisplayStyle'] = source.extra['artworkDisplayStyle'];
        }
        t.artworkOptions = source.artworkOptions
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
      }
      TokenState? existing;
      if (merge) {
        for (final candidate in p.tokens) {
          if (_compatible(candidate, t)) {
            existing = candidate;
            break;
          }
        }
      }
      if (existing != null) {
        _quantity(existing.amount + t.amount);
        existing.amount += t.amount;
        existing.tapped += t.tapped;
        existing.summoningSick += t.summoningSick;
      } else {
        p.tokens.insert(next.clamp(0, p.tokens.length), t);
        next++;
      }
      (existing ?? t).extra['lastCreation'] = {
        'eventId': newEntityId(),
        'quantity': result.quantity,
        'sources': _sources(session, p.id)
            .where((r) => r.enabled && r.count > 0)
            .map((r) => r.toJson())
            .toList(),
      };
      _entered(p, t, result.quantity);
    }
  }

  Future<void> createToken(
    String playerId,
    TokenDefinition def, {
    int quantity = 1,
    bool tapped = false,
    String? artworkUrl,
    int? expectedRevision,
    BoardScope? captured,
  }) async {
    // New Ring selections represent the player's emblem utility. Existing saved
    // Ring token objects and templates remain untouched and undoable.
    if (def.name == 'The Ring // The Ring Tempts You' &&
        def.type.toLowerCase().contains('emblem')) {
      await addUtility(
        playerId,
        'the_ring',
        captured: captured,
        expectedRevision: expectedRevision,
      );
      return;
    }
    _quantity(quantity);
    await _commit(
      playerId,
      '${def.name} +$quantity',
      (s, p) {
        final result = _rules(s, playerId).evaluateRules(
          def.name,
          def.pt,
          def.colors,
          def.type,
          def.abilities,
          quantity,
        );
        if (artworkUrl != null) p.artPreferences[def.id] = artworkUrl;
        if (quantity == 0) {
          p.tokens.add(
            _fromDefinition(def, 0, artworkUrl: artworkUrl, sickness: false),
          );
        } else {
          // Explicit Create keeps its primary as a distinct object. Only
          // rule companions use compatible clean-stack merging (as in the
          // original search and custom-token creation paths).
          _addResults(
            s,
            p,
            result.take(1).toList(),
            tapped: tapped,
            merge: false,
            selectedArtwork: artworkUrl,
            selectedDefinition: def,
          );
          _addResults(s, p, result.skip(1).toList());
        }
      },
      captured: captured,
      expectedRevision: expectedRevision,
      groupKey: 'token-add:${def.id}',
      delta: quantity,
    );
    await catalog.recordRecent(def.id);
  }

  Future<void> changeQuantity(
    String playerId,
    String tokenId,
    int delta,
  ) => _commit(
    playerId,
    delta >= 0 ? 'Add tokens' : 'Remove tokens',
    (s, p) {
      final t = _token(p, tokenId);
      if (delta > 0) {
        // Emblems are not token-creation events; the original object adds the
        // requested amount directly without token multiplication or companions.
        if (_emblem(t)) {
          _quantity(t.amount + delta);
          t.amount += delta;
          return;
        }
        final r = _rules(
          s,
          playerId,
        ).evaluateRules(t.name, t.pt, t.colors, t.type, t.abilities, delta);
        // Plus grows the selected stack, including its existing counters. Only
        // identity-changing replacement results need a separate stack.
        final first = r.first;
        final unchanged =
            first.name == t.name &&
            first.pt == t.pt &&
            first.colors == t.colors &&
            first.type == t.type &&
            first.abilities == t.abilities;
        if (unchanged) {
          _quantity(t.amount + first.quantity);
          t.amount += first.quantity;
          if (p.summoningSicknessEnabled &&
              _creature(t) &&
              !t.abilities.toLowerCase().contains('haste')) {
            t.summoningSick += first.quantity;
          }
          t.extra['lastCreation'] = {
            'eventId': newEntityId(),
            'quantity': first.quantity,
            'sources': _sources(s, p.id)
                .where((r) => r.enabled && r.count > 0)
                .map((r) => r.toJson())
                .toList(),
          };
          _entered(p, t, first.quantity);
          _addResults(
            s,
            p,
            r.skip(1).toList(),
            insertionIndex: p.tokens.indexOf(t) + 1,
          );
        } else {
          _addResults(
            s,
            p,
            r,
            source: t,
            insertionIndex: p.tokens.indexOf(t) + 1,
          );
        }
      } else {
        t.amount = max(0, t.amount + delta);
        t.tapped = min(t.tapped, t.amount);
        t.summoningSick = min(t.summoningSick, t.amount);
      }
    },
    groupKey: 'token-${delta >= 0 ? 'add' : 'remove'}:$tokenId',
    delta: delta,
    effectiveDelta: (before, after) =>
        _player(after, playerId).tokens.fold(0, (n, t) => n + t.amount) -
        _player(before, playerId).tokens.fold(0, (n, t) => n + t.amount),
    describeDelta: (actual) =>
        '${actual >= 0 ? 'Add tokens' : 'Remove tokens'} ${actual >= 0 ? '+' : ''}$actual',
  );

  /// Positive values tap; negative values untap. Each count is bounded by the
  /// current stack, so tap-one and hold-all share exactly the same operation.
  Future<void> tapTokens(String playerId, String tokenId, int delta) =>
      _commit(playerId, delta >= 0 ? 'Tap tokens' : 'Untap tokens', (s, p) {
        final t = _token(p, tokenId);
        if (_emblem(t)) throw StateError('Emblems do not tap.');
        t.tapped = (t.tapped + delta).clamp(0, t.amount);
      });

  Future<void> toggleAllTapped(String playerId, String tokenId) =>
      _commit(playerId, 'Toggle tapped tokens', (s, p) {
        final token = _token(p, tokenId);
        if (_emblem(token)) throw StateError('Emblems do not tap.');
        token.tapped = token.tapped == token.amount ? 0 : token.amount;
      });
  Future<void> deleteToken(
    String playerId,
    String tokenId, {
    BoardScope? captured,
  }) => _commit(playerId, 'Remove token stack', (s, p) {
    _token(p, tokenId);
    p.tokens.removeWhere((t) => t.id == tokenId);
  }, captured: captured);
  Future<void> editToken(
    String playerId,
    String tokenId, {
    String? name,
    String? pt,
    String? abilities,
    String? colors,
    String? type,
    int? amount,
    int? tapped,
    int? summoningSick,
    BoardScope? captured,
  }) => _commit(playerId, 'Edit token', (s, p) {
    final t = _token(p, tokenId);
    // Inline editing preserves the original raw text, including empty fields.
    if (name != null) t.name = name;
    if (pt != null) t.pt = pt;
    if (abilities != null) t.abilities = abilities;
    if (colors != null) t.colors = colors;
    if (type != null) t.type = type;
    if (amount != null) {
      _quantity(amount);
      final added = amount - t.amount;
      if (added > 0 &&
          p.summoningSicknessEnabled &&
          _creature(t) &&
          !t.hasHaste &&
          !_emblem(t)) {
        t.summoningSick += added;
      }
      t.amount = amount;
    }
    if (tapped != null) {
      _quantity(tapped);
      t.tapped = tapped;
    }
    if (summoningSick != null) {
      _quantity(summoningSick);
      t.summoningSick = summoningSick;
    }
    t.tapped = t.tapped.clamp(0, t.amount);
    t.summoningSick = t.summoningSick.clamp(0, t.amount);
    t.definitionId = '${t.name}|${t.pt}|${t.colors}|${t.type}|${t.abilities}';
  }, captured: captured);
  Future<void> counter(
    String playerId,
    String tokenId,
    String counterName,
    int delta,
  ) => _commit(
    playerId,
    '$counterName ${delta >= 0 ? '+' : ''}$delta',
    (s, p) {
      final t = _token(p, tokenId);
      if (counterName.trim().isEmpty) {
        throw const FormatException('Name the counter');
      }
      _applyCounter(
        t,
        counterName,
        delta > 0
            ? _rules(
                s,
                playerId,
              ).calculateCounterAmount(delta, isPlusOne: counterName == '+1/+1')
            : delta,
      );
    },
    groupKey: 'counter:$tokenId:$counterName:${delta.sign}',
    delta: delta,
    effectiveDelta: (before, after) =>
        _counterBalance(
          _token(_player(after, playerId), tokenId),
          counterName,
        ) -
        _counterBalance(
          _token(_player(before, playerId), tokenId),
          counterName,
        ),
    describeDelta: (actual) => '$counterName ${actual >= 0 ? '+' : ''}$actual',
  );

  int _counterBalance(TokenState token, String name) => switch (name) {
    '+1/+1' => token.plusOneCounters - token.minusOneCounters,
    '-1/-1' => token.minusOneCounters - token.plusOneCounters,
    _ => token.counters[name] ?? 0,
  };

  /// An absolute correction is not a counter-placement event: no modifiers.
  Future<void> setCounter(
    String playerId,
    String tokenId,
    String name,
    int value, {
    BoardScope? captured,
  }) => _commit(playerId, 'Set $name counters to $value', (s, p) {
    _quantity(value);
    if (name.trim().isEmpty) throw const FormatException('Name the counter');
    final t = _token(p, tokenId);
    switch (name) {
      case '+1/+1':
        t.plusOneCounters = value;
        break;
      case '-1/-1':
        t.minusOneCounters = value;
        break;
      default:
        if (value == 0) {
          t.counters.remove(name);
        } else {
          t.counters[name] = value;
        }
    }
    final cancelled = min(t.plusOneCounters, t.minusOneCounters);
    t.plusOneCounters -= cancelled;
    t.minusOneCounters -= cancelled;
  }, captured: captured);

  /// Counter-search quantities are explicit placement counts in the original
  /// app. Unlike the quick/management increment buttons, they are applied raw.
  Future<void> addSelectedCounter(
    String playerId,
    String tokenId,
    String name,
    int quantity, {
    BoardScope? captured,
  }) => _commit(playerId, 'Add $quantity $name counters to stack', (s, p) {
    _quantity(quantity);
    if (name.trim().isEmpty) throw const FormatException('Name the counter');
    _applyCounter(_token(p, tokenId), name, quantity);
  }, captured: captured);

  /// Counter search's “Split & Add to One” is distinct from normal Split:
  /// append an untapped, nonsick token with inherited counters/art, retain the
  /// source's bounded status, and apply exactly the entered counter quantity.
  /// The entire operation is one scoped transaction and one undo entry.
  Future<void> splitAndAddCounter(
    String playerId,
    String tokenId,
    String name,
    int quantity, {
    BoardScope? captured,
  }) => _commit(playerId, 'Split and add $quantity $name to one token', (s, p) {
    _quantity(quantity);
    if (name.trim().isEmpty) throw const FormatException('Name the counter');
    final source = _token(p, tokenId);
    if (_emblem(source)) throw StateError('Emblems do not split.');
    if (source.amount < 2) {
      throw StateError('At least two tokens are needed to split');
    }
    final copy = source.copy();
    copy.id = newEntityId();
    copy.amount = 1;
    copy.tapped = 0;
    copy.summoningSick = 0;
    _applyCounter(copy, name, quantity);
    source.amount--;
    source.tapped = min(source.tapped, source.amount);
    source.summoningSick = min(source.summoningSick, source.amount);
    p.tokens.add(copy);
  }, captured: captured);

  void _applyCounter(TokenState t, String name, int amount) {
    if (name == '+1/+1') {
      t.plusOneCounters = max(0, t.plusOneCounters + amount);
    } else if (name == '-1/-1') {
      t.minusOneCounters = max(0, t.minusOneCounters + amount);
    } else {
      final value = max(0, (t.counters[name] ?? 0) + amount);
      if (value == 0) {
        t.counters.remove(name);
      } else {
        _quantity(value);
        t.counters[name] = value;
      }
    }
    final cancelled = min(t.plusOneCounters, t.minusOneCounters);
    t.plusOneCounters -= cancelled;
    t.minusOneCounters -= cancelled;
  }

  Future<void> copyToken(
    String playerId,
    String tokenId,
  ) => _commit(playerId, 'Copy token', (s, p) {
    final t = _token(p, tokenId);
    if (_emblem(t)) throw StateError('Emblems do not copy.');
    // Phone Copy creates one fresh untapped stack, without counters or multipliers.
    final copy = _fromDefinition(
      definition(t),
      1,
      artworkUrl: t.artworkUrl,
      artworkSet: t.artworkSet,
      sickness: p.summoningSicknessEnabled,
    );
    copy.artworkUrl = t.artworkUrl;
    copy.artworkSet = t.artworkSet;
    if (t.extra.containsKey('artworkDisplayStyle')) {
      copy.extra['artworkDisplayStyle'] = t.extra['artworkDisplayStyle'];
    }
    p.tokens.insert(p.tokens.indexOf(t) + 1, copy);
    _entered(p, copy, 1);
  });
  Future<void> splitToken(
    String playerId,
    String tokenId,
    int quantity, {
    bool tappedFirst = false,
    BoardScope? captured,
  }) => _commit(playerId, 'Split token stack', (s, p) {
    final t = _token(p, tokenId);
    if (_emblem(t)) throw StateError('Emblems do not split.');
    _splitOne(p, t, quantity, tappedFirst: tappedFirst);
  }, captured: captured);

  TokenState _splitOne(
    PlayerState p,
    TokenState t,
    int quantity, {
    required bool tappedFirst,
  }) {
    if (quantity <= 0 || quantity >= t.amount) {
      throw RangeError('Split quantity must leave tokens in both stacks');
    }
    final copy = t.copy();
    copy.id = newEntityId();
    copy.amount = quantity;
    copy.tapped = tappedFirst
        ? min(t.tapped, quantity)
        : quantity - min(quantity, t.amount - t.tapped);
    copy.summoningSick = 0;
    t.amount -= quantity;
    t.tapped -= copy.tapped;
    t.summoningSick = 0;
    p.tokens.insert(p.tokens.indexOf(t) + 1, copy);
    return copy;
  }

  /// The original Scute action counts every live Scute stack on this seat,
  /// evaluates rules once, and commits the primary and companions together.
  Future<void> scuteSwarm(String playerId, String tokenId) =>
      _commit(playerId, 'Scute Swarm token creation', (s, p) {
        final source = _token(p, tokenId);
        if (!source.name.toLowerCase().contains(GameConstants.scuteSwarmName)) {
          throw StateError('This action needs a Scute Swarm');
        }
        final count = p.tokens
            .where(
              (t) =>
                  t.name.toLowerCase().contains(GameConstants.scuteSwarmName),
            )
            .fold(0, (total, t) => total + t.amount);
        if (count == 0) return;
        final results = _rules(s, playerId).evaluateRules(
          source.name,
          source.pt,
          source.colors,
          source.type,
          source.abilities,
          count,
        );
        final quantity = results.first.quantity;
        var next = p.tokens.indexOf(source) + 1;
        if (quantity > 0) {
          // Original Scute uses the evaluated primary quantity, then its
          // dedicated Scute creation policy. It does not turn the source into
          // a replacement-rule identity. A compatible clean source identity
          // merges; a new stack uses the catalog Scute and source artwork.
          TokenState? existing;
          for (final candidate in p.tokens) {
            if (_clean(candidate) &&
                candidate.name == source.name &&
                candidate.pt == source.pt &&
                candidate.colors == source.colors &&
                candidate.type == source.type &&
                candidate.abilities == source.abilities &&
                candidate.artworkUrl == source.artworkUrl) {
              existing = candidate;
              break;
            }
          }
          late final TokenState result;
          if (existing != null) {
            _quantity(existing.amount + quantity);
            existing.amount += quantity;
            if (p.summoningSicknessEnabled &&
                existing.hasPowerToughness &&
                !existing.hasHaste) {
              existing.summoningSick += quantity;
            }
            result = existing;
          } else {
            final scute =
                catalog.tokens
                    .where(
                      (t) => t.name.toLowerCase().contains(
                        GameConstants.scuteSwarmName,
                      ),
                    )
                    .firstOrNull ??
                definition(source);
            result = _fromDefinition(
              scute,
              quantity,
              artworkUrl: source.artworkUrl,
              artworkSet: source.artworkSet,
              sickness: p.summoningSicknessEnabled,
            );
            result.artworkUrl = source.artworkUrl;
            result.artworkSet = source.artworkSet;
            if (source.artworkOptions.isNotEmpty) {
              result.artworkOptions = source.artworkOptions
                  .map((a) => Map<String, dynamic>.from(a))
                  .toList();
            }
            if (source.extra.containsKey('artworkDisplayStyle')) {
              result.extra['artworkDisplayStyle'] =
                  source.extra['artworkDisplayStyle'];
            }
            p.tokens.insert(next++, result);
          }
          result.extra['lastCreation'] = {
            'eventId': newEntityId(),
            'quantity': quantity,
            'sources': _sources(s, p.id)
                .where((r) => r.enabled && r.count > 0)
                .map((r) => r.toJson())
                .toList(),
          };
          _entered(p, result, quantity);
        }
        _addResults(s, p, results.skip(1).toList(), insertionIndex: next);
      });

  Future<void> mergeTokens(String playerId, String sourceId, String targetId) =>
      _commit(playerId, 'Merge token stacks', (s, p) {
        if (sourceId == targetId) throw StateError('Choose a different stack');
        final a = _token(p, sourceId), b = _token(p, targetId);
        if (!_compatible(a, b)) {
          throw StateError(
            'Stacks must have matching identity and artwork, with no counters',
          );
        }
        _quantity(a.amount + b.amount);
        b.amount += a.amount;
        b.tapped += a.tapped;
        b.summoningSick += a.summoningSick;
        p.tokens.remove(a);
      });
  void _validateArtwork(String? url) {
    if (url == null) return;
    if (url.startsWith('tablet-art:') || url.startsWith('data:image/')) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Enter a complete http or https image URL, or upload an image.',
      );
    }
  }

  Future<void> setArtwork(
    String playerId,
    String tokenId,
    String? url, {
    String? set,
    String? artist,
    BoardScope? captured,
  }) => _commit(playerId, 'Change token artwork', (s, p) {
    final t = _token(p, tokenId);
    _validateArtwork(url);
    t.artworkUrl = url;
    t.artworkSet = set;
    if (url == null) {
      p.artPreferences.remove(t.definitionId);
    } else {
      p.artPreferences[t.definitionId] = url;
      if (!t.artworkOptions.any((a) => a['url'] == url)) {
        t.artworkOptions.add({
          'url': url,
          'set': set ?? 'Custom',
          'artist':
              artist ??
              ((url.startsWith('tablet-art:') || url.startsWith('data:image/'))
                  ? 'user uploaded'
                  : ''),
        });
      }
    }
  }, captured: captured);
  Future<void> setArtworkStyle(
    String playerId,
    String tokenId,
    String style, {
    BoardScope? captured,
  }) => _commit(playerId, 'Change token artwork display', (s, p) {
    if (!{'full', 'fadeout'}.contains(style)) {
      throw const FormatException('Choose full or fadeout artwork');
    }
    _token(p, tokenId).extra['artworkDisplayStyle'] = style;
  }, captured: captured);

  /// One seat's turn boundary is one atomic, undoable operation.
  Future<void> startTurn(String playerId) =>
      _commit(playerId, 'Start turn', (s, p) {
        for (final token in p.tokens) {
          token.tapped = 0;
          token.summoningSick = 0;
        }
      });

  /// Wipe the active table as one durable command and one chronological Undo.
  /// The persistent seat roster and archived games are not active boards.
  Future<void> wipeEveryone(String action) async {
    if (action != 'wipe_all' && action != 'wipe_creatures') {
      throw ArgumentError.value(action, 'action', 'Choose a board wipe');
    }
    final before = controller.session;
    final generations = {
      for (final player in before.players) player.id: player.generation,
    };
    final ok = await controller.commit(
      action == 'wipe_all'
          ? 'Everyone: wipe all tokens'
          : 'Everyone: wipe creature tokens',
      expectedSessionId: before.id,
      expectedGeneration: before.generation,
      mutate: (session) {
        // Check every scope before editing any draft board. A queued reset or
        // wipe must not silently apply this action to a replacement board.
        for (final player in session.players) {
          if (generations[player.id] != player.generation) {
            throw StateError(
              'A player’s board changed. Reopen the action to continue.',
            );
          }
        }
        for (final player in session.players) {
          final oldCount = player.tokens.length;
          if (action == 'wipe_all') {
            player.tokens.clear();
          } else {
            // Keep the existing single-seat P/T-based creature definition.
            player.tokens.removeWhere(_creature);
          }
          if (player.tokens.length != oldCount) player.generation++;
        }
      },
    );
    if (!ok) {
      throw StateError(controller.error ?? 'The wipe could not be saved');
    }
  }

  Future<void> bulk(
    String playerId,
    String action, {
    bool gameOrigin = false,
  }) => _commit(
    playerId,
    const {
          'wipe_all': 'Wipe all tokens',
          'wipe_creatures': 'Wipe creature tokens',
          'untap': 'Untap all tokens',
          'clear_sickness': 'Clear summoning sickness',
          'plus_one': 'Add +1/+1 to all creatures',
          'minus_one': 'Add -1/-1 to all creatures',
        }[action] ??
        action,
    (s, p) {
      if (action == 'wipe_all') {
        p.tokens.clear();
        p.generation++;
        return;
      }
      if (action == 'wipe_creatures') {
        p.tokens.removeWhere(_creature);
        p.generation++;
        return;
      }
      for (final t in p.tokens) {
        switch (action) {
          case 'untap':
            t.tapped = 0;
            break;
          case 'clear_sickness':
            t.summoningSick = 0;
            break;
          case 'plus_one':
            if (_creature(t)) {
              _applyCounter(
                t,
                '+1/+1',
                _rules(s, playerId).calculateCounterAmount(1),
              );
            }
            break;
          case 'minus_one':
            if (_creature(t)) {
              _applyCounter(
                t,
                '-1/-1',
                _rules(s, playerId).calculateCounterAmount(1, isPlusOne: false),
              );
            }
            break;
          default:
            throw ArgumentError('Unknown board action');
        }
      }
    },
    gameOrigin: gameOrigin,
  );
  Future<void> reorder(
    String playerId,
    String lane,
    int oldIndex,
    int newIndex,
  ) => _commit(playerId, 'Reorder $lane', (s, p) {
    final List<dynamic> items = lane == 'tokens' ? p.tokens : p.utilities;
    if (newIndex > oldIndex) newIndex--;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
  });
  // Presentation only: legacy payloads and their bound command handlers remain
  // intact so saved history can still resolve exact values and entity IDs.
  static const _builtInUtilityKinds = {
    'life_total',
    'poison_counters',
    'energy_counters',
    'experience_counters',
    'radiation_counters',
    'citys_blessing',
    'monarch',
    'day_night',
    'initiative',
    'the_initiative',
  };
  bool isStandaloneUtilityKind(String kind) =>
      !_builtInUtilityKinds.contains(kind);
  bool isUtilityVisible(UtilityState utility) =>
      utility.visible && isStandaloneUtilityKind(utility.kind);

  List<WidgetDefinition> get utilityDefinitions {
    final db = WidgetDatabase();
    final list = db.filteredWidgets
        .where((d) => isStandaloneUtilityKind(d.id) && d.id != 'commander_tax')
        .toList();
    db.dispose();
    return [
      WidgetDefinition(
        id: 'the_ring',
        type: WidgetType.special,
        name: 'The Ring',
        description:
            'Track temptations and up to four abilities, with an optional bearer label.',
        colorIdentity: '',
        defaultValue: 0,
        actionOnly: true,
        artwork: [
          ArtworkVariant(
            set: 'LTR',
            artist: 'Viko Menezes',
            url:
                'https://cards.scryfall.io/large/front/7/2/7215460e-8c06-47d0-94e5-d1832d0218af.jpg',
          ),
        ],
      ),
      WidgetDefinition(
        id: 'mana_pool',
        type: WidgetType.special,
        name: 'Mana pool',
        description:
            'Manual mana. Empty preserves locked colors; conversion moves every color.',
        colorIdentity: '',
        defaultValue: 0,
      ),
      WidgetDefinition(
        id: 'the_unbeatable_squirrel_girl',
        type: WidgetType.special,
        name: 'The Unbeatable Squirrel Girl',
        description: 'Nontoken Squirrels you control (including Squirrel Girl)',
        colorIdentity: 'G',
        defaultValue: 1,
        hasAction: true,
        actionButtonText: 'Make Squirrels · 1GGG',
        actionType: 'the_unbeatable_squirrel_girl',
        artwork: [
          ArtworkVariant(
            set: 'MSH',
            artist: 'Kim Dingwall',
            url:
                'https://cards.scryfall.io/large/front/d/8/d8b94ebb-0b3a-4e68-8c0c-3a61ac32f3ef.jpg?1783902911',
          ),
          ArtworkVariant(
            set: 'MSH',
            artist: 'Swayart',
            url:
                'https://cards.scryfall.io/large/front/e/f/ef518e5b-7942-4e66-aee0-a1c2aa1f9754.jpg?1783902847',
          ),
        ],
      ),
      ...list,
    ];
  }

  /// Initiative is a built-in status stored in the existing utility payload.
  /// Visibility only controls the legacy utility lane, not who holds a status.
  /// No read-time migration rewrites old IDs, art, values or settings.
  static bool isInitiativeKind(String kind) =>
      kind == 'initiative' || kind == 'the_initiative';

  bool hasInitiative(String playerId) => _player(controller.session, playerId)
      .utilities
      .any((utility) => isInitiativeKind(utility.kind) && utility.isActive);

  List<String>? _initiativeAffectedPlayers(String playerId, String id) {
    final owner = controller.session.players
        .where((player) => player.id == playerId)
        .firstOrNull;
    final utility = owner?.utilities
        .where((utility) => utility.id == id)
        .firstOrNull;
    return utility != null && isInitiativeKind(utility.kind)
        ? controller.session.players.map((player) => player.id).toList()
        : null;
  }

  static void _setInitiative(
    GameSession session,
    String? playerId, {
    String? preferredUtilityId,
  }) {
    final target = playerId == null ? null : session.player(playerId);
    UtilityState? selected;
    if (target != null) {
      final existing = target.utilities
          .where((utility) => isInitiativeKind(utility.kind))
          .toList();
      for (final utility in existing) {
        if (utility.id == preferredUtilityId) selected = utility;
      }
      // Preserve the current identity when historical saves have duplicates.
      selected ??= existing.where((utility) => utility.isActive).firstOrNull;
      selected ??= existing.firstOrNull;
      if (selected == null) {
        selected = UtilityState(
          id: newEntityId(),
          kind: 'initiative',
          name: 'The Initiative',
          description: 'You have the Initiative.',
          configuration: {
            'type': 'toggle',
            'offDescription': 'You do not have the Initiative.',
          },
        );
        target.utilities.add(selected);
      }
    }
    for (final player in session.players) {
      for (final utility in player.utilities) {
        if (isInitiativeKind(utility.kind)) {
          utility.isActive = identical(utility, selected);
        }
      }
    }
  }

  /// Claim, transfer or clear in one durable, undoable command. A claim only
  /// affects active players in this session; saved setups/archives stay intact.
  Future<void> setInitiative(String? playerId) async {
    final session = controller.session;
    final target = playerId == null ? null : _player(session, playerId);
    final saved = await controller.commit(
      playerId == null ? 'Clear initiative' : 'Claim initiative',
      playerId: playerId,
      affectedPlayerIds: session.players.map((player) => player.id).toList(),
      expectedSessionId: session.id,
      expectedGeneration: session.generation,
      expectedPlayerGeneration: target?.generation,
      mutate: (game) => _setInitiative(game, playerId),
    );
    if (!saved) {
      throw StateError(controller.error ?? 'The change could not be saved');
    }
  }

  int utilityValue(String playerId, String utilityId) {
    final p = _player(controller.session, playerId),
        u = _utility(_player(controller.session, playerId), utilityId);
    if (u.kind == 'life_total') return p.life;
    final key = _boundCounter(u.kind);
    if (key != null) return p.counters[key] ?? 0;
    return u.value;
  }

  bool utilityActive(String playerId, String utilityId) {
    final p = _player(controller.session, playerId),
        u = _utility(_player(controller.session, playerId), utilityId);
    if (u.kind == 'citys_blessing') return p.citysBlessing;
    if (u.kind == 'monarch') {
      return controller.session.monarchPlayerId == playerId;
    }
    if (u.kind == 'day_night') return controller.session.dayNight == 'day';
    return u.isActive;
  }

  String? _boundCounter(String kind) => const {
    'poison_counters': 'poison',
    'energy_counters': 'energy',
    'experience_counters': 'experience',
    'radiation_counters': 'radiation',
  }[kind];
  Future<void> addUtility(
    String playerId,
    String definitionId, {
    BoardScope? captured,
    int? expectedRevision,
  }) => _commit(
    playerId,
    'Add utility',
    (s, p) {
      final d = utilityDefinitions.firstWhere(
        (d) => d.id == definitionId,
        orElse: () => throw StateError('Unsupported utility'),
      );
      if ({
        'the_ring',
        'mana_pool',
        'storm_count',
        'life_total',
        'poison_counters',
        'energy_counters',
        'experience_counters',
        'radiation_counters',
        'citys_blessing',
      }.contains(definitionId)) {
        for (final u in p.utilities) {
          if (u.kind == definitionId && u.visible) return;
        }
      }
      p.utilities.add(
        UtilityState(
          id: newEntityId(),
          kind: d.id,
          name: d.name,
          description: d.description,
          colors: d.colorIdentity,
          value: d.defaultValue ?? 0,
          defaultValue: d.defaultValue ?? 0,
          artworkUrl: d.artwork.isEmpty ? null : d.artwork.first.url,
          configuration: {
            'type': d.type == WidgetType.toggle ? 'toggle' : 'tracker',
            'tapIncrement': d.tapIncrement,
            'longPressIncrement': d.longPressIncrement,
            'hasAction': d.hasAction,
            'actionType': d.actionType,
            'actionOnly': d.actionOnly,
            'actionButtonText': d.actionButtonText,
            'offDescription': d.offDescription,
            'artworkOptions': d.artwork.map((a) => a.toJson()).toList(),
          },
        ),
      );
    },
    captured: captured,
    expectedRevision: expectedRevision,
  );

  /// Removing a board instance is reversible through the normal history.
  /// Legacy hidden instances and player-owned game state stay untouched.
  Future<void> removeUtility(
    String playerId,
    String id, {
    BoardScope? captured,
  }) => _commit(playerId, 'Remove utility', (s, p) {
    final utility = _utility(p, id);
    if (!isUtilityVisible(utility)) {
      throw StateError('This utility is not on the board');
    }
    p.utilities.removeWhere((candidate) => candidate.id == id);
  }, captured: captured);

  Future<void> setUtility(
    String playerId,
    String id, {
    int? value,
    bool? isActive,
    bool? visible,
    String? name,
    String? description,
    String? artworkUrl,
    bool clearArtwork = false,
    BoardScope? captured,
    Map<String, dynamic>? configuration,
  }) => _commit(
    playerId,
    visible == null
        ? 'Update utility'
        : visible
        ? 'Show utility'
        : 'Hide utility',
    (s, p) {
      final u = _utility(p, id);
      if (name != null) {
        if (name.trim().isEmpty) {
          throw const FormatException('A utility needs a name');
        }
        u.name = name.trim();
      }
      if (description != null) u.description = description;
      if (clearArtwork) {
        u.artworkUrl = null;
      } else if (artworkUrl != null) {
        _validateArtwork(artworkUrl);
        u.artworkUrl = artworkUrl;
        final options = List<Map<String, dynamic>>.from(
          (u.configuration['artworkOptions'] as List? ?? []).map(
            (a) => Map<String, dynamic>.from(a as Map),
          ),
        );
        if (!options.any((a) => a['url'] == artworkUrl)) {
          options.add({
            'url': artworkUrl,
            'set': 'Custom',
            'artist':
                artworkUrl.startsWith('tablet-art:') ||
                    artworkUrl.startsWith('data:image/')
                ? 'user uploaded'
                : '',
          });
          u.configuration['artworkOptions'] = options;
        }
      }
      if (visible != null) u.visible = visible;
      if (configuration != null) u.configuration.addAll(configuration);
      if (value != null) {
        if (u.kind == 'life_total') {
          p.life = value;
        } else {
          _quantity(value);
          final bound = _boundCounter(u.kind);
          if (bound != null) {
            p.counters[bound] = value;
          } else {
            u.value = value;
          }
        }
      }
      if (isActive != null) {
        if (u.kind == 'citys_blessing') {
          p.citysBlessing = isActive;
        } else if (u.kind == 'monarch') {
          if (isActive) {
            s.monarchPlayerId = playerId;
          } else if (s.monarchPlayerId == playerId) {
            s.monarchPlayerId = null;
          }
        } else if (u.kind == 'day_night') {
          s.dayNight = isActive ? 'day' : 'night';
        } else if (isInitiativeKind(u.kind)) {
          // Turning an already-inactive legacy entry off must not clear
          // another player's status. Explicit on/owner-off still resolves
          // old duplicate entries in one atomic command.
          if (isActive ||
              p.utilities.any(
                (utility) => isInitiativeKind(utility.kind) && utility.isActive,
              )) {
            _setInitiative(
              s,
              isActive ? playerId : null,
              preferredUtilityId: u.id,
            );
          }
        } else {
          u.isActive = isActive;
        }
      }
    },
    groupKey: value == null ? null : 'utility:$id',
    captured: captured,
    affectedPlayerIds: isActive == null
        ? null
        : _initiativeAffectedPlayers(playerId, id),
  );

  /// Relative gestures resolve values inside the serialized writer, so a burst
  /// of taps cannot repeatedly overwrite the same rendered absolute value.
  Future<void> adjustUtility(String playerId, String id, int delta) => _commit(
    playerId,
    'Adjust utility ${delta >= 0 ? '+' : ''}$delta',
    (s, p) {
      final u = _utility(p, id);
      if (u.kind == 'life_total') {
        p.life += delta;
      } else {
        final key = _boundCounter(u.kind);
        if (key != null) {
          final next = max(0, (p.counters[key] ?? 0) + delta);
          _quantity(next);
          p.counters[key] = next;
        } else {
          final next = max(0, u.value + delta);
          _quantity(next);
          u.value = next;
        }
      }
    },
    groupKey: 'utility:$id:${delta.sign}',
    delta: delta,
  );
  Future<void> toggleUtility(String playerId, String id) => _commit(
    playerId,
    'Toggle utility',
    (s, p) {
      final u = _utility(p, id);
      if (u.kind == 'citys_blessing') {
        p.citysBlessing = !p.citysBlessing;
      } else if (u.kind == 'monarch') {
        s.monarchPlayerId = s.monarchPlayerId == playerId ? null : playerId;
      } else if (u.kind == 'day_night') {
        s.dayNight = s.dayNight == 'day' ? 'night' : 'day';
      } else if (isInitiativeKind(u.kind)) {
        _setInitiative(
          s,
          u.isActive ? null : playerId,
          preferredUtilityId: u.id,
        );
      } else {
        u.isActive = !u.isActive;
      }
    },
    affectedPlayerIds: _initiativeAffectedPlayers(playerId, id),
  );
  Future<void> reorderVisibleUtilities(String playerId, List<String> ids) =>
      _commit(playerId, 'Reorder utilities', (s, p) {
        final visible = p.utilities.where(isUtilityVisible).toList();
        if (ids.length != visible.length ||
            ids.toSet().length != ids.length ||
            !visible.every((u) => ids.contains(u.id))) {
          throw StateError('Utilities changed while dragging. Try again.');
        }
        final byId = {for (final u in visible) u.id: u};
        var i = 0;
        p.utilities = [
          for (final u in p.utilities)
            isUtilityVisible(u) ? byId[ids[i++]]! : u,
        ];
      });

  Future<void> createCustomUtility(
    String playerId, {
    required String name,
    String description = '',
    bool toggle = false,
    int defaultValue = 0,
    int step = 1,
  }) => _commit(playerId, 'Create utility', (s, p) {
    if (name.trim().isEmpty) {
      throw const FormatException('A utility needs a name');
    }
    _quantity(defaultValue);
    p.utilities.add(
      UtilityState(
        id: newEntityId(),
        kind: toggle ? 'custom_toggle' : 'custom_tracker',
        name: name.trim(),
        description: description,
        value: defaultValue,
        defaultValue: defaultValue,
        configuration: {
          'type': toggle ? 'toggle' : 'tracker',
          'tapIncrement': max(1, step),
          'isCustom': true,
        },
      ),
    );
  });
  List<TokenCreationResult> utilityPreview(String playerId, String id) {
    final s = controller.session,
        p = _player(s, playerId),
        u = _utility(_player(s, playerId), id);
    if (u.kind == 'rhys_the_redeemed') {
      return [
        for (final token in p.tokens.where(
          (t) => !_emblem(t) && _creature(t) && t.amount > 0,
        ))
          ..._rules(s, playerId).evaluateRules(
            token.name,
            token.type.toLowerCase().contains('creature') ? token.pt : '',
            token.colors,
            token.type,
            token.abilities,
            token.amount,
          ),
      ];
    }
    return _utilityResults(s, p, u);
  }

  List<TokenCreationResult> _utilityResults(
    GameSession s,
    PlayerState p,
    UtilityState u,
  ) {
    TokenDefinition? d;
    int quantity = 0, forced = 0;
    switch (u.kind) {
      case 'krenko_mob_boss':
        quantity =
            u.value +
            p.tokens
                .where((t) => _hasCreatureSubtype(t, 'Goblin'))
                .fold<int>(0, (n, t) => n + t.amount);
        d = _definitionId('Goblin|1/1|R|Creature — Goblin|');
        break;
      case 'krenko_tin_street':
        quantity = u.value;
        d = _definitionId('Goblin|1/1|R|Creature — Goblin|');
        break;
      case 'hare_apparent':
        quantity = max(0, u.value - 1);
        d = _definitionId('Rabbit|1/1|W|Creature — Rabbit|');
        break;
      case 'the_unbeatable_squirrel_girl':
        // Count at resolution, then create fresh tokens once. This is the
        // activated 1GGG ability, not the separate enters/attacks trigger.
        quantity =
            u.value +
            p.tokens
                .where((t) => _hasCreatureSubtype(t, 'Squirrel'))
                .fold<int>(0, (n, t) => n + t.amount);
        d = _definitionId(GameConstants.squirrelCompositeId);
        break;
      case 'academy_manufactor':
        if (u.value > 0) {
          quantity = 1;
          forced = u.value;
          d = _definitionId(GameConstants.foodCompositeId);
        }
        break;
      case 'brudiclad_telchor_engineer':
        quantity = 1;
        d = _definitionId(GameConstants.phyrexianMyrCompositeId);
        break;
      default:
        return [];
    }
    if (quantity == 0 || d == null) return [];
    return _rules(s, p.id).evaluateRules(
      d.name,
      d.pt,
      d.colors,
      d.type,
      d.abilities,
      quantity,
      forceAcademyManufactorCount: forced,
    );
  }

  Future<void> utilityAction(
    String playerId,
    String id, {
    String? targetTokenId,
    bool skip = false,
    bool quick = false,
    int? expectedRevision,
    BoardScope? captured,
  }) => _commit(
    playerId,
    'Utility action',
    (s, p) {
      final u = _utility(p, id);
      if (u.kind == 'cathars_crusade') {
        final n = quick ? 1 : u.value;
        if (n <= 0) return;
        final amount = _rules(s, playerId).calculateCounterAmount(n);
        for (final t in p.tokens.where(_creature)) {
          _applyCounter(t, '+1/+1', amount);
        }
        if (!quick) u.value = 0;
        return;
      }
      if (u.kind == 'rhys_the_redeemed') {
        final sources = p.tokens
            .where((t) => !_emblem(t) && _creature(t) && t.amount > 0)
            .map((t) => t.copy())
            .toList();
        for (final source in sources) {
          final basePt = source.type.toLowerCase().contains('creature')
              ? source.pt
              : '';
          final results = _rules(s, playerId).evaluateRules(
            source.name,
            basePt,
            source.colors,
            source.type,
            source.abilities,
            source.amount,
          );
          final index = p.tokens.indexWhere((t) => t.id == source.id);
          _addResults(s, p, results, source: source, insertionIndex: index + 1);
        }
        return;
      }
      final results = _utilityResults(s, p, u);
      if (u.kind == 'brudiclad_telchor_engineer') {
        // Newly created Myr (or replacement/companion) is a valid transform choice.
        TokenState? chosen;
        if (targetTokenId != null) {
          for (final t in p.tokens) {
            if (t.id == targetTokenId) chosen = t.copy();
          }
          if (chosen == null) {
            final d = _definitionId(targetTokenId);
            chosen = _fromDefinition(d, 1);
            if (!results.any((r) => r.compositeId == d.id)) {
              throw StateError('This transform choice is no longer available');
            }
          }
        }
        if (!skip && chosen == null) {
          throw StateError('Choose a token to copy or Skip transformation');
        }
        if (!skip && (chosen!.amount <= 0 || _emblem(chosen))) {
          throw StateError(
            'Choose a nonempty token stack; emblems cannot be copied by Brudiclad.',
          );
        }
        _addResults(s, p, results);
        if (!skip) {
          final target = chosen!;
          final copiedPt = target.type.toLowerCase().contains('creature')
              ? target.pt
              : '';
          TokenState? anchor;
          for (final t in [...p.tokens]) {
            if (_emblem(t) || t.amount == 0) continue;
            t.name = target.name;
            t.pt = copiedPt;
            t.type = target.type;
            t.colors = target.colors;
            t.abilities = target.abilities;
            t.definitionId =
                '${t.name}|${t.pt}|${t.colors}|${t.type}|${t.abilities}';
            t.artworkUrl = target.artworkUrl;
            t.artworkSet = target.artworkSet;
            t.artworkOptions = target.artworkOptions
                .map((a) => Map<String, dynamic>.from(a))
                .toList();
            if (_clean(t)) {
              if (anchor == null) {
                anchor = t;
              } else {
                _quantity(anchor.amount + t.amount);
                anchor.amount += t.amount;
                anchor.tapped += t.tapped;
                p.tokens.remove(t);
              }
            }
          }
        }
        for (final t in p.tokens) {
          t.summoningSick = 0;
        }
        return;
      }
      if (results.isEmpty) {
        throw StateError(
          'No tokens would be created. Adjust this utility’s count first.',
        );
      }
      _addResults(s, p, results);
    },
    captured: captured,
    expectedRevision: expectedRevision,
  );
  Future<void> setModifier(
    String playerId,
    String definitionId,
    int count, {
    bool? global,
  }) => _commit(playerId, 'Change modifier source', (s, p) {
    if (!modifierDefinitions.containsKey(definitionId)) {
      throw ArgumentError('Unknown modifier');
    }
    if (count < 0 || count > 20) {
      throw RangeError('Modifier count must be between 0 and 20');
    }
    ModifierSource? source;
    for (final r in p.rules) {
      if (r.definitionId == definitionId) {
        source = r;
        break;
      }
    }
    if (source == null) {
      source = ModifierSource(
        id: newEntityId(),
        ownerPlayerId: p.id,
        definitionId: definitionId,
        name: modifierDefinitions[definitionId]!,
        global: global ?? definitionId == 'primal_vigor',
      );
      p.rules.add(source);
    }
    source.count = count;
    source.enabled = count > 0;
    source.revision++;
    if (global != null) source.global = global;
  });
  Future<void> setSource(
    String playerId,
    String sourceId, {
    bool? enabled,
    int? count,
    bool? global,
  }) => _commit(playerId, 'Change modifier source', (s, p) {
    final source = p.rules.firstWhere(
      (r) => r.id == sourceId,
      orElse: () =>
          throw StateError('Only the source seat can edit this modifier'),
    );
    if (source.ownerPlayerId != playerId) {
      throw StateError('Only the source seat can edit this modifier');
    }
    if (count != null) {
      if (count < 0 || count > 20) {
        throw RangeError('Modifier count must be from 0 to 20');
      }
      source.count = count;
    }
    if (enabled != null) source.enabled = enabled;
    if (global != null) source.global = global;
    source.revision++;
  });
  Future<void> saveCustomRule(String playerId, Map<String, dynamic> rule) =>
      _commit(playerId, 'Save custom rule', (s, p) {
        final name = rule['name']?.toString().trim() ?? '';
        if (name.isEmpty) throw const FormatException('Give this rule a name');
        final count = (rule['count'] as num?)?.toInt() ?? 1;
        if (count < 0 || count > 20) {
          throw RangeError('Rule count must be from 0 to 20');
        }
        final triggerType = rule['triggerType'] as String? ?? 'any_token';
        if (!{
          'any_token',
          'has_pt',
          'token_type',
          'color',
          'specific_token',
        }.contains(triggerType)) {
          throw const FormatException('Unknown rule trigger');
        }
        if (triggerType == 'specific_token') {
          _definitionId(rule['targetTokenId'] as String? ?? '');
        }
        if (triggerType == 'token_type' &&
            (rule['targetType'] as String? ?? '').trim().isEmpty) {
          throw const FormatException('Choose a token type');
        }
        if (triggerType == 'color' &&
            !{'W', 'U', 'B', 'R', 'G'}.contains(rule['targetColor'])) {
          throw const FormatException('Choose a token color');
        }
        final outcomes = rule['outcomes'];
        if (outcomes is! List || outcomes.isEmpty) {
          throw const FormatException('Choose at least one rule outcome');
        }
        for (final raw in outcomes) {
          final o = Map<String, dynamic>.from(raw as Map);
          if (!{
            'multiply',
            'replace',
            'also_create',
          }.contains(o['outcomeType'])) {
            throw const FormatException('Unknown rule outcome');
          }
          if (o['outcomeType'] == 'multiply' &&
              ((o['multiplier'] as num?)?.toInt() ?? 0) < 1) {
            throw const FormatException('Multiplier must be positive');
          }
          if (o['outcomeType'] != 'multiply') {
            _definitionId(o['targetTokenId'] as String? ?? '');
          }
          if (o['outcomeType'] == 'also_create' &&
              ((o['quantity'] as num?)?.toInt() ?? 0) < 1) {
            throw const FormatException('Companion quantity must be positive');
          }
        }
        final source = ModifierSource(
          id: rule['id'] as String? ?? newEntityId(),
          ownerPlayerId: playerId,
          definitionId: 'custom',
          name: name,
          global: rule['global'] == true,
          enabled: rule['enabled'] != false,
          count: count,
          configuration: Map<String, dynamic>.from(rule),
        );
        final index = p.rules.indexWhere((r) => r.id == source.id);
        if (index < 0) {
          p.rules.add(source);
        } else {
          source.revision = p.rules[index].revision + 1;
          p.rules[index] = source;
        }
      });
  Future<void> moveRule(String playerId, String sourceId, int offset) =>
      _commit(playerId, 'Reorder custom rules', (s, p) {
        final custom = p.rules
            .where((r) => r.definitionId == 'custom')
            .toList();
        final old = custom.indexWhere((r) => r.id == sourceId);
        if (old < 0) throw StateError('This custom rule no longer exists');
        final next = (old + offset).clamp(0, custom.length - 1);
        if (old == next) return;
        final moved = custom.removeAt(old);
        custom.insert(next, moved);
        var i = 0;
        p.rules = [
          for (final r in p.rules) r.definitionId == 'custom' ? custom[i++] : r,
        ];
        for (final r in custom) {
          r.revision++;
        }
      });
  Future<void> removeModifier(String playerId, String id) =>
      _commit(playerId, 'Remove modifier source', (s, p) {
        final r = p.rules.firstWhere(
          (r) => r.id == id,
          orElse: () =>
              throw StateError('Only the source seat can remove this modifier'),
        );
        if (r.ownerPlayerId != playerId) {
          throw StateError('Only the source seat can remove this modifier');
        }
        p.rules.remove(r);
      });
}

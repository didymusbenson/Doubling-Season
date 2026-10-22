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
  }) async {
    final c = captured ?? scope(playerId);
    final ok = await controller.commit(
      label,
      playerId: playerId,
      groupKey: groupKey,
      delta: delta,
      expectedSessionId: c.sessionId,
      expectedGeneration: c.generation,
      expectedPlayerGeneration: c.playerGeneration,
      mutate: (s) {
        if (expectedRevision != null && s.revision != expectedRevision) {
          throw StateError(
            'The board or rules changed. Review the updated preview before continuing.',
          );
        }
        mutate(s, _player(s, playerId));
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
  bool _emblem(TokenState t) =>
      t.name.toLowerCase().contains('emblem') ||
      t.abilities.toLowerCase().contains('emblem');
  bool _clean(TokenState t) =>
      t.plusOneCounters == 0 &&
      t.minusOneCounters == 0 &&
      t.counters.values.every((n) => n == 0);
  bool _compatible(TokenState a, TokenState b) =>
      a.definitionId == b.definitionId &&
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
      artworkSet:
          artworkSet ?? (d.artwork.isNotEmpty ? d.artwork.first.set : null),
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
      final d =
          catalog.byId(result.compositeId) ?? _definitionId(result.compositeId);
      final sameSource =
          source != null &&
          '${source.name}|${source.type.toLowerCase().contains('creature') ? source.pt : ''}|${source.colors}|${source.type}|${source.abilities}' ==
              result.compositeId;
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
          _addResults(
            p,
            result,
            tapped: tapped,
            selectedArtwork: artworkUrl,
            selectedDefinition: def,
          );
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
        final r = _rules(
          s,
          playerId,
        ).evaluateRules(t.name, t.pt, t.colors, t.type, t.abilities, delta);
        // Increments retain the source's counters; companions still use clean merges.
        final first = r.first;
        if (first.compositeId == t.definitionId) {
          _quantity(t.amount + first.quantity);
          t.amount += first.quantity;
          if (p.summoningSicknessEnabled &&
              _creature(t) &&
              !t.abilities.toLowerCase().contains('haste')) {
            t.summoningSick += first.quantity;
          }
          _entered(p, t, first.quantity);
          _addResults(
            p,
            r.skip(1).toList(),
            insertionIndex: p.tokens.indexOf(t) + 1,
          );
        } else {
          _addResults(p, r, source: t, insertionIndex: p.tokens.indexOf(t) + 1);
        }
      } else {
        t.amount = max(0, t.amount + delta);
        t.tapped = min(t.tapped, t.amount);
        t.summoningSick = min(t.summoningSick, t.amount);
      }
    },
    groupKey: 'token-${delta >= 0 ? 'add' : 'remove'}:$tokenId',
    delta: delta,
  );
  Future<void> deleteToken(String playerId, String tokenId) =>
      _commit(playerId, 'Remove token stack', (s, p) {
        _token(p, tokenId);
        p.tokens.removeWhere((t) => t.id == tokenId);
      });
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
    if (name != null) {
      if (name.trim().isEmpty) {
        throw const FormatException('A token needs a name');
      }
      t.name = name.trim();
    }
    if (pt != null) t.pt = pt;
    if (abilities != null) t.abilities = abilities;
    if (colors != null) t.colors = colors;
    if (type != null) t.type = type;
    if (amount != null) {
      _quantity(amount);
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
  );
  void _applyCounter(TokenState t, String name, int amount) {
    if (name == '+1/+1') {
      t.plusOneCounters = max(0, t.plusOneCounters + amount);
    } else if (name == '-1/-1') {
      t.minusOneCounters = max(0, t.minusOneCounters + amount);
    } else {
      t.counters[name] = max(0, (t.counters[name] ?? 0) + amount);
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
    // Phone Copy creates one fresh untapped stack, without counters or multipliers.
    final copy = _fromDefinition(
      definition(t),
      1,
      artworkUrl: t.artworkUrl,
      artworkSet: t.artworkSet,
      sickness: p.summoningSicknessEnabled,
    );
    p.tokens.insert(p.tokens.indexOf(t) + 1, copy);
    _entered(p, copy, 1);
  });
  Future<void> splitToken(String playerId, String tokenId, int quantity) =>
      _commit(playerId, 'Split token stack', (s, p) {
        final t = _token(p, tokenId);
        if (quantity <= 0 || quantity >= t.amount) {
          throw RangeError('Split quantity must leave tokens in both stacks');
        }
        final copy = t.copy();
        copy.id = newEntityId();
        copy.amount = quantity;
        copy.tapped = min(t.tapped, quantity);
        copy.summoningSick = min(t.summoningSick, quantity);
        t.amount -= quantity;
        t.tapped -= copy.tapped;
        t.summoningSick -= copy.summoningSick;
        p.tokens.insert(p.tokens.indexOf(t) + 1, copy);
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
  Future<void> setArtwork(
    String playerId,
    String tokenId,
    String? url, {
    String? set,
    String? artist,
    BoardScope? captured,
  }) => _commit(playerId, 'Change token artwork', (s, p) {
    final t = _token(p, tokenId);
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
          'artist': artist ?? 'user uploaded',
        });
      }
    }
  }, captured: captured);
  Future<void> bulk(String playerId, String action) => _commit(
    playerId,
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
  List<WidgetDefinition> get utilityDefinitions {
    final db = WidgetDatabase();
    final list = db.filteredWidgets
        .where(
          (d) => !{
            'initiative',
            'commander_tax',
            'monarch',
            'day_night',
          }.contains(d.id),
        )
        .toList();
    db.dispose();
    return [
      WidgetDefinition(
        id: 'mana_pool',
        type: WidgetType.special,
        name: 'Mana pool',
        description:
            'Manual mana. Empty preserves locked colors; conversion moves every color.',
        colorIdentity: '',
        defaultValue: 0,
      ),
      ...list,
    ];
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
    if (u.kind == 'monarch')
      return controller.session.monarchPlayerId == playerId;
    if (u.kind == 'day_night') return controller.session.dayNight == 'day';
    return u.isActive;
  }

  String? _boundCounter(String kind) => const {
    'poison_counters': 'poison',
    'energy_counters': 'energy',
    'experience_counters': 'experience',
    'radiation_counters': 'radiation',
  }[kind];
  Future<void> addUtility(String playerId, String definitionId) =>
      _commit(playerId, 'Add utility', (s, p) {
        final d = utilityDefinitions.firstWhere(
          (d) => d.id == definitionId,
          orElse: () => throw StateError('Unsupported utility'),
        );
        if ({
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
            if (u.kind == definitionId) {
              u.visible = true;
              return;
            }
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
      });
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
        u.artworkUrl = artworkUrl;
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
          } else if (s.monarchPlayerId == playerId)
            s.monarchPlayerId = null;
        } else if (u.kind == 'day_night') {
          s.dayNight = isActive ? 'day' : 'night';
        } else {
          u.isActive = isActive;
        }
      }
    },
    groupKey: value == null ? null : 'utility:$id',
    captured: captured,
  );
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
                .where((t) => t.type.toLowerCase().contains('goblin'))
                .fold<int>(0, (n, t) => n + t.amount);
        break;
      case 'krenko_tin_street':
        quantity = u.value;
        break;
      case 'hare_apparent':
        quantity = max(0, u.value - 1);
        d = TokenDefinition(
          name: 'Rabbit',
          pt: '1/1',
          colors: 'W',
          type: 'Creature Token — Rabbit',
          abilities: '',
          popularity: 0,
        );
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
    d ??= TokenDefinition(
      name: 'Goblin',
      pt: '1/1',
      colors: 'R',
      type: 'Creature Token — Goblin',
      abilities: '',
      popularity: 0,
    );
    if (quantity == 0) return [];
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
          _addResults(p, results, source: source, insertionIndex: index + 1);
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
        _addResults(p, results);
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
      _addResults(p, results);
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
        if (count < 1 || count > 20) {
          throw RangeError('Rule count must be from 1 to 20');
        }
        final triggerType = rule['triggerType'] as String? ?? 'any_token';
        if (!{
          'any_token',
          'has_pt',
          'token_type',
          'color',
          'specific_token',
        }.contains(triggerType))
          throw const FormatException('Unknown rule trigger');
        if (triggerType == 'specific_token')
          _definitionId(rule['targetTokenId'] as String? ?? '');
        if (triggerType == 'token_type' &&
            (rule['targetType'] as String? ?? '').trim().isEmpty)
          throw const FormatException('Choose a token type');
        if (triggerType == 'color' &&
            !{'W', 'U', 'B', 'R', 'G', 'C'}.contains(rule['targetColor']))
          throw const FormatException('Choose a token color');
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

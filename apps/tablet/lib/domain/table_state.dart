import 'dart:convert';

import 'package:uuid/uuid.dart';

String newEntityId() => const Uuid().v4();

Map<String, dynamic> jsonMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
Map<String, dynamic> cloneJson(Map<String, dynamic> value) =>
    jsonMap(jsonDecode(jsonEncode(value)));
Map<String, int> _ints(dynamic value) => (value as Map? ?? {}).map(
  (key, value) => MapEntry(key as String, value as int),
);
Map<String, String> _strings(dynamic value) => (value as Map? ?? {}).map(
  (key, value) => MapEntry(key as String, value as String),
);
List<T> _objects<T>(dynamic value, T Function(Map<String, dynamic>) parse) =>
    (value as List? ?? []).map((item) => parse(jsonMap(item))).toList();

/// Independent product state. No phone Hive boxes or persisted adapters are used.
class TabletState {
  static const currentSchemaVersion = 1;
  int schemaVersion;
  List<SeatProfile> profiles;
  GameSession session;
  List<GameArchive> archives;
  List<Map<String, dynamic>> decks;
  Map<String, dynamic> settings;
  Map<String, dynamic> library;

  TabletState({
    this.schemaVersion = currentSchemaVersion,
    required this.profiles,
    required this.session,
    List<GameArchive>? archives,
    List<Map<String, dynamic>>? decks,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? library,
  }) : archives = archives ?? [],
       decks = decks ?? [],
       settings = settings ?? {},
       library = library ?? {};

  factory TabletState.initial() {
    const colors = [0xffd7bd78, 0xff83b7ce, 0xffb498ca, 0xff92bc91];
    final profiles = List.generate(
      4,
      (index) => SeatProfile(
        id: newEntityId(),
        name: 'Player ${index + 1}',
        color: colors[index],
      ),
    );
    return TabletState(
      profiles: profiles,
      session: GameSession(
        id: newEntityId(),
        players: List.generate(
          4,
          (index) => PlayerState(
            id: newEntityId(),
            seatId: profiles[index].id,
            slot: index,
            utilities: defaultUtilities(),
          ),
        ),
      ),
    );
  }

  factory TabletState.fromJson(Map<String, dynamic> json) => TabletState(
    schemaVersion: json['schemaVersion'] as int,
    profiles: _objects(json['profiles'], SeatProfile.fromJson),
    session: GameSession.fromJson(jsonMap(json['session'])),
    archives: _objects(json['archives'], GameArchive.fromJson),
    decks: _objects(json['decks'], (value) => value),
    settings: jsonMap(json['settings'] ?? {}),
    library: jsonMap(json['library'] ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'profiles': profiles.map((value) => value.toJson()).toList(),
    'session': session.toJson(),
    'archives': archives.map((value) => value.toJson()).toList(),
    'decks': decks,
    'settings': settings,
    'library': library,
  };
  TabletState copy() => TabletState.fromJson(cloneJson(toJson()));
}

class SeatProfile {
  String id;
  String name;
  int color;
  String? artworkUrl;
  SeatProfile({
    required this.id,
    required this.name,
    this.color = 0xffd7bd78,
    this.artworkUrl,
  });
  factory SeatProfile.fromJson(Map<String, dynamic> json) => SeatProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int,
    artworkUrl: json['artworkUrl'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'artworkUrl': artworkUrl,
  };
  SeatProfile copy() => SeatProfile.fromJson(toJson());
}

class GameSession {
  String id;
  int generation;
  int revision;
  int startingLife;
  DateTime startedAt;
  List<PlayerState> players;
  List<CommanderSource> commanders;
  String? monarchPlayerId;
  String dayNight;
  List<HistoryEntry> history;
  List<String> completedCommandIds;
  GameSession({
    required this.id,
    this.generation = 1,
    this.revision = 0,
    this.startingLife = 40,
    DateTime? startedAt,
    required this.players,
    List<CommanderSource>? commanders,
    this.monarchPlayerId,
    this.dayNight = 'neither',
    List<HistoryEntry>? history,
    List<String>? completedCommandIds,
  }) : startedAt = startedAt ?? DateTime.now().toUtc(),
       commanders = commanders ?? [],
       history = history ?? [],
       completedCommandIds = completedCommandIds ?? [];
  PlayerState player(String id) => players.firstWhere(
    (value) => value.id == id,
    orElse: () => throw StateError('That player is no longer in this game.'),
  );
  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    id: json['id'] as String,
    generation: json['generation'] as int,
    revision: json['revision'] as int,
    startingLife: json['startingLife'] as int,
    startedAt: DateTime.parse(json['startedAt'] as String),
    players: _objects(json['players'], PlayerState.fromJson),
    commanders: _objects(json['commanders'], CommanderSource.fromJson),
    monarchPlayerId: json['monarchPlayerId'] as String?,
    dayNight: json['dayNight'] as String,
    history: _objects(json['history'], HistoryEntry.fromJson),
    completedCommandIds: (json['completedCommandIds'] as List? ?? [])
        .cast<String>(),
  );
  Map<String, dynamic> toJson({bool includeHistory = true}) => {
    'id': id,
    'generation': generation,
    'revision': revision,
    'startingLife': startingLife,
    'startedAt': startedAt.toIso8601String(),
    'players': players.map((value) => value.toJson()).toList(),
    'commanders': commanders.map((value) => value.toJson()).toList(),
    'monarchPlayerId': monarchPlayerId,
    'dayNight': dayNight,
    if (includeHistory)
      'history': history.map((value) => value.toJson()).toList(),
    'completedCommandIds': completedCommandIds,
  };
  GameSession copy() => GameSession.fromJson(cloneJson(toJson()));
}

class PlayerState {
  String id;
  String seatId;
  int slot;
  int generation;
  int life;
  Map<String, int> counters;
  bool citysBlessing;
  Map<String, int> commanderDamage;
  List<TokenState> tokens;
  List<UtilityState> utilities;
  Map<String, int> mana;
  Set<String> manaLocks;
  List<ModifierSource> rules;
  Map<String, String> artPreferences;
  bool summoningSicknessEnabled;
  PlayerState({
    required this.id,
    required this.seatId,
    required this.slot,
    this.generation = 1,
    this.life = 40,
    Map<String, int>? counters,
    this.citysBlessing = false,
    Map<String, int>? commanderDamage,
    List<TokenState>? tokens,
    List<UtilityState>? utilities,
    Map<String, int>? mana,
    Set<String>? manaLocks,
    List<ModifierSource>? rules,
    Map<String, String>? artPreferences,
    this.summoningSicknessEnabled = true,
  }) : counters =
           counters ??
           {'energy': 0, 'poison': 0, 'experience': 0, 'radiation': 0},
       commanderDamage = commanderDamage ?? {},
       tokens = tokens ?? [],
       utilities = utilities ?? [],
       mana = mana ?? {for (final color in manaColors) color: 0},
       manaLocks = manaLocks ?? {},
       rules = rules ?? [],
       artPreferences = artPreferences ?? {};
  static const manaColors = ['W', 'U', 'B', 'R', 'G', 'C'];
  List<String> get warnings => [
    if (life <= 0) 'Life is $life',
    if ((counters['poison'] ?? 0) >= 10) '10 or more poison counters',
    if (commanderDamage.values.any((value) => value >= 21))
      '21 or more damage from one commander',
  ];
  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    id: json['id'] as String,
    seatId: json['seatId'] as String,
    slot: json['slot'] as int,
    generation: json['generation'] as int,
    life: json['life'] as int,
    counters: _ints(json['counters']),
    citysBlessing: json['citysBlessing'] as bool,
    commanderDamage: _ints(json['commanderDamage']),
    tokens: _objects(json['tokens'], TokenState.fromJson),
    utilities: _objects(json['utilities'], UtilityState.fromJson),
    mana: _ints(json['mana']),
    manaLocks: (json['manaLocks'] as List? ?? []).cast<String>().toSet(),
    rules: _objects(json['rules'], ModifierSource.fromJson),
    artPreferences: _strings(json['artPreferences']),
    summoningSicknessEnabled: json['summoningSicknessEnabled'] as bool? ?? true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'seatId': seatId,
    'slot': slot,
    'generation': generation,
    'life': life,
    'counters': counters,
    'citysBlessing': citysBlessing,
    'commanderDamage': commanderDamage,
    'tokens': tokens.map((value) => value.toJson()).toList(),
    'utilities': utilities.map((value) => value.toJson()).toList(),
    'mana': mana,
    'manaLocks': manaLocks.toList(),
    'rules': rules.map((value) => value.toJson()).toList(),
    'artPreferences': artPreferences,
    'summoningSicknessEnabled': summoningSicknessEnabled,
  };
  PlayerState copy() => PlayerState.fromJson(cloneJson(toJson()));
}

class TokenState {
  String id;
  String definitionId;
  String name;
  String pt;
  String colors;
  String type;
  String abilities;
  int amount;
  int tapped;
  int summoningSick;
  int plusOneCounters;
  int minusOneCounters;
  Map<String, int> counters;
  String? artworkUrl;
  String? artworkSet;
  List<Map<String, dynamic>> artworkOptions;
  Map<String, dynamic> extra;
  TokenState({
    required this.id,
    this.definitionId = '',
    this.name = 'Token',
    this.pt = '',
    this.colors = '',
    this.type = '',
    this.abilities = '',
    this.amount = 0,
    this.tapped = 0,
    this.summoningSick = 0,
    this.plusOneCounters = 0,
    this.minusOneCounters = 0,
    Map<String, int>? counters,
    this.artworkUrl,
    this.artworkSet,
    List<Map<String, dynamic>>? artworkOptions,
    Map<String, dynamic>? extra,
  }) : counters = counters ?? {},
       artworkOptions = artworkOptions ?? [],
       extra = extra ?? {};
  bool get hasPowerToughness => pt.contains('/');
  bool get isEmblem =>
      name.toLowerCase().contains('emblem') ||
      type.toLowerCase().contains('emblem');
  bool get hasHaste =>
      RegExp(r'\bhaste\b', caseSensitive: false).hasMatch(abilities);
  int get untapped => amount - tapped;
  int get netPlusOneCounters => plusOneCounters - minusOneCounters;
  factory TokenState.fromJson(Map<String, dynamic> json) => TokenState(
    id: json['id'] as String,
    definitionId: json['definitionId'] as String? ?? '',
    name: json['name'] as String,
    pt: json['pt'] as String? ?? '',
    colors: json['colors'] as String? ?? '',
    type: json['type'] as String? ?? '',
    abilities: json['abilities'] as String? ?? '',
    amount: json['amount'] as int,
    tapped: json['tapped'] as int? ?? 0,
    summoningSick: json['summoningSick'] as int? ?? 0,
    plusOneCounters: json['plusOneCounters'] as int? ?? 0,
    minusOneCounters: json['minusOneCounters'] as int? ?? 0,
    counters: _ints(json['counters']),
    artworkUrl: json['artworkUrl'] as String?,
    artworkSet: json['artworkSet'] as String?,
    artworkOptions: _objects(json['artworkOptions'], (value) => value),
    extra: jsonMap(json['extra'] ?? {}),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'definitionId': definitionId,
    'name': name,
    'pt': pt,
    'colors': colors,
    'type': type,
    'abilities': abilities,
    'amount': amount,
    'tapped': tapped,
    'summoningSick': summoningSick,
    'plusOneCounters': plusOneCounters,
    'minusOneCounters': minusOneCounters,
    'counters': counters,
    'artworkUrl': artworkUrl,
    'artworkSet': artworkSet,
    'artworkOptions': artworkOptions,
    'extra': extra,
  };
  TokenState copy() => TokenState.fromJson(cloneJson(toJson()));
}

class UtilityState {
  String id;
  String kind;
  String name;
  String description;
  int value;
  int defaultValue;
  bool isActive;
  bool visible;
  String colors;
  String? artworkUrl;
  Map<String, dynamic> configuration;
  UtilityState({
    required this.id,
    this.kind = 'tracker',
    this.name = 'Tracker',
    this.description = '',
    this.value = 0,
    this.defaultValue = 0,
    this.isActive = false,
    this.visible = true,
    this.colors = '',
    this.artworkUrl,
    Map<String, dynamic>? configuration,
  }) : configuration = configuration ?? {};
  factory UtilityState.fromJson(Map<String, dynamic> json) => UtilityState(
    id: json['id'] as String,
    kind: json['kind'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    value: json['value'] as int? ?? 0,
    defaultValue: json['defaultValue'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? false,
    visible: json['visible'] as bool? ?? true,
    colors: json['colors'] as String? ?? '',
    artworkUrl: json['artworkUrl'] as String?,
    configuration: jsonMap(json['configuration'] ?? {}),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'description': description,
    'value': value,
    'defaultValue': defaultValue,
    'isActive': isActive,
    'visible': visible,
    'colors': colors,
    'artworkUrl': artworkUrl,
    'configuration': configuration,
  };
  UtilityState copy() => UtilityState.fromJson(cloneJson(toJson()));
}

List<UtilityState> defaultUtilities() => [
  UtilityState(id: newEntityId(), kind: 'storm_count', name: 'Storm'),
  UtilityState(id: newEntityId(), kind: 'mana_pool', name: 'Mana pool'),
];

class ModifierSource {
  String id;
  String ownerPlayerId;
  String definitionId;
  String name;
  bool global;
  bool enabled;
  int count;
  int revision;
  Map<String, dynamic> configuration;
  ModifierSource({
    required this.id,
    required this.ownerPlayerId,
    this.definitionId = '',
    this.name = '',
    this.global = false,
    this.enabled = false,
    this.count = 0,
    this.revision = 0,
    Map<String, dynamic>? configuration,
  }) : configuration = configuration ?? {};
  factory ModifierSource.fromJson(Map<String, dynamic> json) => ModifierSource(
    id: json['id'] as String,
    ownerPlayerId: json['ownerPlayerId'] as String,
    definitionId: json['definitionId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    global: json['global'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? false,
    count: json['count'] as int? ?? 0,
    revision: json['revision'] as int? ?? 0,
    configuration: jsonMap(json['configuration'] ?? {}),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerPlayerId': ownerPlayerId,
    'definitionId': definitionId,
    'name': name,
    'global': global,
    'enabled': enabled,
    'count': count,
    'revision': revision,
    'configuration': configuration,
  };
  ModifierSource copy() => ModifierSource.fromJson(cloneJson(toJson()));
}

class CommanderSource {
  String id;
  String ownerPlayerId;
  String name;
  CommanderSource({
    required this.id,
    required this.ownerPlayerId,
    required this.name,
  });
  factory CommanderSource.fromJson(Map<String, dynamic> json) =>
      CommanderSource(
        id: json['id'] as String,
        ownerPlayerId: json['ownerPlayerId'] as String,
        name: json['name'] as String,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerPlayerId': ownerPlayerId,
    'name': name,
  };
  CommanderSource copy() => CommanderSource.fromJson(toJson());
}

/// Field-level inverse, including whether a map key existed before the command.
class HistoryChange {
  List<dynamic> path;
  dynamic before;
  dynamic after;
  bool beforeExists;
  bool afterExists;
  HistoryChange({
    required this.path,
    this.before,
    this.after,
    this.beforeExists = true,
    this.afterExists = true,
  });
  factory HistoryChange.fromJson(Map<String, dynamic> json) => HistoryChange(
    path: List<dynamic>.from(json['path'] as List),
    before: json['before'],
    after: json['after'],
    beforeExists: json['beforeExists'] as bool,
    afterExists: json['afterExists'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'path': path,
    'before': before,
    'after': after,
    'beforeExists': beforeExists,
    'afterExists': afterExists,
  };
}

class HistoryCommand {
  String id;
  String label;
  DateTime at;
  int revision;
  int? delta;
  List<HistoryChange> changes;
  HistoryCommand({
    required this.id,
    required this.label,
    required this.at,
    required this.revision,
    this.delta,
    required this.changes,
  });
  factory HistoryCommand.fromJson(Map<String, dynamic> json) => HistoryCommand(
    id: json['id'] as String,
    label: json['label'] as String,
    at: DateTime.parse(json['at'] as String),
    revision: json['revision'] as int,
    delta: json['delta'] as int?,
    changes: _objects(json['changes'], HistoryChange.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'at': at.toIso8601String(),
    'revision': revision,
    'delta': delta,
    'changes': changes.map((value) => value.toJson()).toList(),
  };
}

class HistoryEntry {
  String id;
  String label;
  String? playerId;
  String? playerLabel;
  String? groupKey;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> affectedPlayerIds;
  List<HistoryCommand> commands;
  bool undone;
  HistoryEntry({
    required this.id,
    required this.label,
    this.playerId,
    this.playerLabel,
    this.groupKey,
    required this.createdAt,
    required this.updatedAt,
    required this.affectedPlayerIds,
    required this.commands,
    this.undone = false,
  });
  int get totalDelta =>
      commands.fold(0, (total, command) => total + (command.delta ?? 0));
  String get summary {
    if (groupKey?.startsWith('life:') == true) {
      final value = totalDelta;
      return 'Life ${value >= 0 ? '+' : ''}$value';
    }
    if (commands.length > 1 &&
        commands.every((command) => command.delta != null)) {
      return '$label (${totalDelta >= 0 ? '+' : ''}$totalDelta total)';
    }
    if (commands.length > 1) return '$label ×${commands.length}';
    return label;
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    label: json['label'] as String,
    playerId: json['playerId'] as String?,
    playerLabel: json['playerLabel'] as String?,
    groupKey: json['groupKey'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    affectedPlayerIds: (json['affectedPlayerIds'] as List).cast<String>(),
    commands: _objects(json['commands'], HistoryCommand.fromJson),
    undone: json['undone'] as bool? ?? false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'playerId': playerId,
    'playerLabel': playerLabel,
    'groupKey': groupKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'affectedPlayerIds': affectedPlayerIds,
    'commands': commands.map((value) => value.toJson()).toList(),
    'undone': undone,
  };
}

class GameArchive {
  String id;
  String label;
  DateTime savedAt;
  GameSession session;
  Map<String, String> playerLabels;
  GameArchive({
    required this.id,
    required this.label,
    required this.savedAt,
    required this.session,
    Map<String, String>? playerLabels,
  }) : playerLabels = playerLabels ?? {};
  factory GameArchive.fromJson(Map<String, dynamic> json) => GameArchive(
    id: json['id'] as String,
    label: json['label'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    session: GameSession.fromJson(jsonMap(json['session'])),
    playerLabels: _strings(json['playerLabels']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'savedAt': savedAt.toIso8601String(),
    'session': session.toJson(),
    'playerLabels': playerLabels,
  };
  GameArchive copy() => GameArchive.fromJson(cloneJson(toJson()));
}

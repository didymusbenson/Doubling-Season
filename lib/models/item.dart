import 'package:hive/hive.dart';
import 'token_counter.dart';
import 'token_definition.dart';
import '../utils/constants.dart';

part 'item.g.dart';

@HiveType(typeId: HiveTypeIds.item)
class Item extends HiveObject {
  // Basic properties (no validation needed)
  @HiveField(0)
  String abilities;

  @HiveField(1)
  String name;

  @HiveField(2)
  String pt;

  // Colors with validation
  @HiveField(3)
  String _colors = '';

  String get colors => _colors;
  set colors(String value) {
    _colors = value.toUpperCase();
    save(); // HiveObject method to persist changes
  }

  // Amount with dependent validation (CRITICAL)
  @HiveField(4)
  int _amount = 0;

  int get amount => _amount;
  set amount(int value) {
    _amount = value < 0 ? 0 : value;

    // Auto-correct dependent values
    if (_tapped > _amount) _tapped = _amount;
    if (_summoningSick > _amount) _summoningSick = _amount;

    save();
  }

  // Tapped with validation
  @HiveField(5)
  int _tapped = 0;

  int get tapped => _tapped;
  set tapped(int value) {
    if (value < 0) {
      _tapped = 0;
    } else if (value > _amount) {
      _tapped = _amount;
    } else {
      _tapped = value;
    }
    save();
  }

  // Summoning sickness with validation
  @HiveField(6)
  int _summoningSick = 0;

  int get summoningSick => _summoningSick;
  set summoningSick(int value) {
    if (value < 0) {
      _summoningSick = 0;
    } else if (value > _amount) {
      _summoningSick = _amount;
    } else {
      _summoningSick = value;
    }
    save();
  }

  // Counters
  @HiveField(7)
  int _plusOneCounters = 0;

  int get plusOneCounters => _plusOneCounters;
  set plusOneCounters(int value) {
    _plusOneCounters = value < 0 ? 0 : value;
    _reconcileCounters();
    save();
  }

  @HiveField(8)
  int _minusOneCounters = 0;

  int get minusOneCounters => _minusOneCounters;
  set minusOneCounters(int value) {
    _minusOneCounters = value < 0 ? 0 : value;
    _reconcileCounters();
    save();
  }

  @HiveField(9)
  List<TokenCounter> counters;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  double order;

  @HiveField(12, defaultValue: '')
  String? _type;

  String get type => _type ?? '';
  set type(String value) {
    _type = value;
    save();
  }

  @HiveField(13)
  String? artworkUrl;

  @HiveField(14)
  String? artworkSet;

  @HiveField(15)
  List<ArtworkVariant>? artworkOptions;

  // Constructor
  Item({
    required this.name,
    required this.pt,
    this.abilities = '',
    String colors = '',
    String type = '',
    int amount = 1,
    int tapped = 0,
    int summoningSick = 0,
    List<TokenCounter>? counters,
    DateTime? createdAt,
    this.order = 0.0,
    this.artworkUrl,
    this.artworkSet,
    this.artworkOptions,
  })  : counters = counters ?? [],
        _colors = colors.toUpperCase(),
        _type = type,
        _amount = amount < 0 ? 0 : amount,
        _tapped = tapped < 0 ? 0 : tapped,
        _summoningSick = summoningSick < 0 ? 0 : summoningSick,
        createdAt = createdAt ?? DateTime.now();

  // Computed properties
  bool get isEmblem =>
      name.toLowerCase().contains('emblem') ||
      type.toLowerCase().contains('emblem');

  int get netPlusOneCounters => plusOneCounters - minusOneCounters;

  bool get isPowerToughnessModified => netPlusOneCounters != 0;

  bool get canBeModifiedByCounters {
    final parts = pt.split('/');
    return parts.length == 2 &&
        int.tryParse(parts[0]) != null &&
        int.tryParse(parts[1]) != null;
  }

  String get formattedPowerToughness {
    final net = netPlusOneCounters;
    if (net == 0) return pt;

    if (canBeModifiedByCounters) {
      final parts = pt.split('/');
      final power = int.parse(parts[0]) + net;
      final toughness = int.parse(parts[1]) + net;
      return '$power/$toughness';
    }

    // Non-integer P/T
    return net > 0 ? '$pt (+$net/+$net)' : '$pt ($net/$net)';
  }

  // CRITICAL: Counter interaction logic (from Item.swift:149-173)
  void addPowerToughnessCounters(int amount) {
    if (amount > 0) {
      // Adding +1/+1 counters
      if (_minusOneCounters > 0) {
        final reduction = amount < _minusOneCounters ? amount : _minusOneCounters;
        _minusOneCounters -= reduction;
        final remaining = amount - reduction;
        _plusOneCounters += remaining;
      } else {
        _plusOneCounters += amount;
      }
    } else if (amount < 0) {
      // Adding -1/-1 counters
      final absAmount = amount.abs();
      if (_plusOneCounters > 0) {
        final reduction = absAmount < _plusOneCounters ? absAmount : _plusOneCounters;
        _plusOneCounters -= reduction;
        final remaining = absAmount - reduction;
        _minusOneCounters += remaining;
      } else {
        _minusOneCounters += absAmount;
      }
    }
    save();
  }

  // Reconcile +1/+1 and -1/-1 counters (called automatically by setters)
  // Per MTG rules, +1/+1 and -1/-1 counters cancel each other as a state-based action
  void _reconcileCounters() {
    if (_plusOneCounters > 0 && _minusOneCounters > 0) {
      final cancelAmount = _plusOneCounters < _minusOneCounters
          ? _plusOneCounters
          : _minusOneCounters;
      _plusOneCounters -= cancelAmount;
      _minusOneCounters -= cancelAmount;
    }
  }

  bool addCounter({required String name, int amount = 1}) {
    if (name.isEmpty || amount <= 0) return false;

    final existing = counters.where((c) => c.name == name).firstOrNull;
    if (existing != null) {
      existing.amount += amount;
    } else {
      counters.add(TokenCounter(name: name, amount: amount));
    }
    save();
    return true;
  }

  bool removeCounter({required String name, int amount = 1}) {
    final existing = counters.where((c) => c.name == name).firstOrNull;
    if (existing == null) return false;

    existing.amount -= amount;
    if (existing.amount <= 0) {
      counters.removeWhere((c) => c.name == name);
    }
    save();
    return true;
  }

  Item createDuplicate() {
    final newItem = Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      type: type,
      amount: 0,
      tapped: 0,
      summoningSick: 0,
      order: 0.0, // Order will be set by caller
      artworkUrl: artworkUrl,
      artworkSet: artworkSet,
      artworkOptions: artworkOptions != null ? List.from(artworkOptions!) : null,
    );

    // Store counter values to be applied after item is added to box
    // Caller must add item to box first, then call applyDuplicateCounters()
    return newItem;
  }

  // Call this AFTER adding the item to the Hive box
  void applyDuplicateCounters(Item source) {
    plusOneCounters = source.plusOneCounters;
    minusOneCounters = source.minusOneCounters;
    for (final counter in source.counters) {
      counters.add(TokenCounter(name: counter.name, amount: counter.amount));
    }
    save();
  }
}

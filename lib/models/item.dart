import 'package:hive/hive.dart';
import 'token_counter.dart';
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
    save();
  }

  @HiveField(8)
  int _minusOneCounters = 0;

  int get minusOneCounters => _minusOneCounters;
  set minusOneCounters(int value) {
    _minusOneCounters = value < 0 ? 0 : value;
    save();
  }

  @HiveField(9)
  List<TokenCounter> counters;

  @HiveField(10)
  DateTime createdAt;

  // Constructor
  Item({
    required this.name,
    required this.pt,
    this.abilities = '',
    String colors = '',
    int amount = 1,
    int tapped = 0,
    int summoningSick = 0,
    this.counters = const [],
    DateTime? createdAt,
  })  : _colors = colors.toUpperCase(),
        _amount = amount < 0 ? 0 : amount,
        _tapped = tapped < 0 ? 0 : tapped,
        _summoningSick = summoningSick < 0 ? 0 : summoningSick,
        createdAt = createdAt ?? DateTime.now();

  // Computed properties
  bool get isEmblem =>
      name.toLowerCase().contains('emblem') ||
      abilities.toLowerCase().contains('emblem');

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
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      amount: 0,
      tapped: 0,
      summoningSick: 0,
    )
      ..plusOneCounters = plusOneCounters
      ..minusOneCounters = minusOneCounters
      ..counters = counters.map((c) => TokenCounter(name: c.name, amount: c.amount)).toList();
  }
}

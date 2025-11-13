import 'item.dart';

class ArtworkVariant {
  final String set;
  final String url;

  ArtworkVariant({required this.set, required this.url});

  factory ArtworkVariant.fromJson(Map<String, dynamic> json) {
    return ArtworkVariant(
      set: json['set'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class TokenDefinition {
  final String name;
  final String abilities;
  final String pt;
  final String colors;
  final String type;
  final int popularity;
  final List<ArtworkVariant> artwork;

  TokenDefinition({
    required this.name,
    required this.abilities,
    required this.pt,
    required this.colors,
    required this.type,
    required this.popularity,
    this.artwork = const [],
  });

  // CRITICAL: Composite ID must match deduplication logic in process_tokens.py
  String get id => '$name|$pt|$colors|$type|$abilities';

  factory TokenDefinition.fromJson(Map<String, dynamic> json) {
    // Parse artwork array
    final artworkJson = json['artwork'] as List<dynamic>?;
    final artworkList = artworkJson
            ?.map((art) => ArtworkVariant.fromJson(art as Map<String, dynamic>))
            .toList() ??
        [];

    return TokenDefinition(
      name: json['name'] as String? ?? '',
      abilities: json['abilities'] as String? ?? '',
      pt: json['pt'] as String? ?? '',
      colors: json['colors'] as String? ?? '',
      type: json['type'] as String? ?? '',
      popularity: json['popularity'] as int? ?? 0,
      artwork: artworkList,
    );
  }

  bool matches({required String searchQuery}) {
    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return name.toLowerCase().contains(query) ||
        abilities.toLowerCase().contains(query) ||
        pt.toLowerCase().contains(query) ||
        type.toLowerCase().contains(query);
  }

  Item toItem({required int amount, required bool createTapped}) {
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      type: type,
      amount: amount,
      tapped: createTapped ? amount : 0,
      summoningSick: amount, // Always apply summoning sickness to new tokens
    );
  }

  String get cleanType {
    // Remove "Token" suffix if present
    return type.replaceAll(RegExp(r'\s+Token$', caseSensitive: false), '');
  }

  // Category for filtering
  Category get category {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('creature')) return Category.creature;
    if (lowerType.contains('artifact')) return Category.artifact;
    if (lowerType.contains('enchantment')) return Category.enchantment;
    if (lowerType.contains('emblem')) return Category.emblem;
    if (lowerType.contains('dungeon')) return Category.dungeon;
    if (name.toLowerCase().contains('counter')) return Category.counter;
    return Category.other;
  }
}

enum Category {
  creature,
  artifact,
  enchantment,
  emblem,
  dungeon,
  counter,
  other;

  String get displayName {
    switch (this) {
      case Category.creature:
        return 'Creature';
      case Category.artifact:
        return 'Artifact';
      case Category.enchantment:
        return 'Enchantment';
      case Category.emblem:
        return 'Emblem';
      case Category.dungeon:
        return 'Dungeon';
      case Category.counter:
        return 'Counter';
      case Category.other:
        return 'Other';
    }
  }
}

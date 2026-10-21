import '../models/item.dart';
import '../models/token_definition.dart' show ArtworkVariant;
import 'token_copy_semantics.dart';
import 'token_merge_compatibility.dart';

class BrudicladTokenDefinition {
  final String name;
  final String pt;
  final String colors;
  final String type;
  final String abilities;
  final String? artworkUrl;
  final String? artworkSet;
  final List<ArtworkVariant>? artworkOptions;
  final List<Item> sourceStacks;

  const BrudicladTokenDefinition({
    required this.name,
    required this.pt,
    required this.colors,
    required this.type,
    required this.abilities,
    this.artworkUrl,
    this.artworkSet,
    this.artworkOptions,
    required this.sourceStacks,
  });

  String get compositeId => '$name|$pt|$colors|$type|$abilities';
  String get pickerId => '$compositeId|${artworkUrl ?? ''}';
  int get totalTokens =>
      sourceStacks.fold<int>(0, (sum, item) => sum + item.amount);
}

class BrudicladTransformTarget {
  final Item source;
  final bool willMerge;
  final bool keepsCounters;
  final bool isNoOp;

  const BrudicladTransformTarget({
    required this.source,
    required this.willMerge,
    required this.keepsCounters,
    required this.isNoOp,
  });
}

class BrudicladTransformPlan {
  final BrudicladTokenDefinition chosen;
  final List<BrudicladTransformTarget> targets;
  final Item? mergeAnchor;

  const BrudicladTransformPlan({
    required this.chosen,
    required this.targets,
    required this.mergeAnchor,
  });

  int get affectedStacks =>
      targets.where((target) => !target.isNoOp || target.willMerge).length;

  int get affectedTokens => targets
      .where((target) => !target.isNoOp || target.willMerge)
      .fold<int>(0, (sum, target) => sum + target.source.amount);

  int get separateStacks =>
      targets.where((target) => target.keepsCounters).length;
}

class BrudicladTransformPlanner {
  const BrudicladTransformPlanner._();

  static List<BrudicladTokenDefinition> definitionsOnBoard(
    List<Item> items,
  ) {
    final order = <String>[];
    final grouped = <String, List<Item>>{};

    for (final item in items) {
      if (!TokenCopySemantics.isToken(item)) continue;
      final pt = TokenCopySemantics.copiablePtFor(item);
      final id = '${item.name}|$pt|${item.colors}|${item.type}|'
          '${item.abilities}|${item.artworkUrl ?? ''}';
      if (!grouped.containsKey(id)) order.add(id);
      grouped.putIfAbsent(id, () => <Item>[]).add(item);
    }

    return [
      for (final id in order) _definitionFrom(grouped[id]!.first, grouped[id]!),
    ];
  }

  static BrudicladTransformPlan build({
    required List<Item> items,
    required BrudicladTokenDefinition chosen,
  }) {
    final eligible = items.where(TokenCopySemantics.isToken).toList();
    final clean = eligible.where(TokenMergeCompatibility.isClean).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final anchor = clean.isEmpty ? null : clean.first;

    return BrudicladTransformPlan(
      chosen: chosen,
      mergeAnchor: anchor,
      targets: [
        for (final item in eligible)
          BrudicladTransformTarget(
            source: item,
            willMerge: TokenMergeCompatibility.isClean(item) && item != anchor,
            keepsCounters: !TokenMergeCompatibility.isClean(item),
            isNoOp: TokenMergeCompatibility.matchesIdentity(
              item,
              name: chosen.name,
              pt: chosen.pt,
              colors: chosen.colors,
              type: chosen.type,
              abilities: chosen.abilities,
              artworkUrl: chosen.artworkUrl,
            ),
          ),
      ],
    );
  }

  static BrudicladTokenDefinition _definitionFrom(
    Item item,
    List<Item> sources,
  ) =>
      BrudicladTokenDefinition(
        name: item.name,
        pt: TokenCopySemantics.copiablePtFor(item),
        colors: item.colors,
        type: item.type,
        abilities: item.abilities,
        artworkUrl: item.artworkUrl,
        artworkSet: item.artworkSet,
        artworkOptions: item.artworkOptions == null
            ? null
            : List<ArtworkVariant>.from(item.artworkOptions!),
        sourceStacks: List<Item>.unmodifiable(sources),
      );
}

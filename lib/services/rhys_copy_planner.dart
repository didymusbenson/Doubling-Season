import '../models/item.dart';
import '../models/token_definition.dart' show ArtworkVariant;
import '../database/token_database.dart';
import '../providers/rules_provider.dart';
import 'token_copy_semantics.dart';
import 'token_result_artwork_resolver.dart';

/// One fully-resolved token stack that Rhys will create.
///
/// Everything needed to build the [Item] is baked in here — including the
/// artwork — so the confirmation preview and the actual board mutation read
/// from the exact same snapshot and cannot diverge.
class RhysCopyResult {
  final String name;
  final String pt;
  final String colors;
  final String type;
  final String abilities;
  final int quantity;

  /// True if the rules engine clamped [quantity] to [GameConstants.maxTokenQuantity].
  final bool wasCapped;

  final String? artworkUrl;
  final String? artworkSet;
  final List<ArtworkVariant>? artworkOptions;

  const RhysCopyResult({
    required this.name,
    required this.pt,
    required this.colors,
    required this.type,
    required this.abilities,
    required this.quantity,
    required this.wasCapped,
    this.artworkUrl,
    this.artworkSet,
    this.artworkOptions,
  });

  String get compositeId => '$name|$pt|$colors|$type|$abilities';

  bool get hasPowerToughness => pt.trim().isNotEmpty;

  bool get hasHaste => abilities.toLowerCase().contains('haste');
}

/// The results produced by one source stack.
///
/// Rhys evaluates every eligible stack independently (see spec Q13), so the
/// source-to-results mapping is preserved all the way through execution: new
/// stacks are inserted adjacent to the source they came from.
class RhysCopyGroup {
  /// The board stack this group was derived from.
  final Item source;

  /// The P/T the copies were evaluated with (empty when the source's type line
  /// has no `Creature`, i.e. the source is an animated noncreature permanent).
  final String copiedPt;

  /// Evaluated results. Index 0 is the primary token (possibly replaced by a
  /// rule); the rest are companion tokens.
  final List<RhysCopyResult> results;

  /// The next item on the unified board (token, tracker, or toggle). New
  /// stacks are fractionally placed between this group's source and that
  /// item, so Rhys never jumps across an intervening utility.
  final double nextBoardOrder;

  const RhysCopyGroup({
    required this.source,
    required this.copiedPt,
    required this.results,
    required this.nextBoardOrder,
  });

  int get totalQuantity => results.fold<int>(0, (sum, r) => sum + r.quantity);
}

/// A complete, immutable plan for one Rhys activation.
class RhysCopyPlan {
  final List<RhysCopyGroup> groups;

  const RhysCopyPlan(this.groups);

  bool get isEmpty => groups.isEmpty;

  bool get isNotEmpty => groups.isNotEmpty;

  int get totalTokens => groups.fold<int>(0, (sum, g) => sum + g.totalQuantity);

  bool get wasCapped => groups.any((g) => g.results.any((r) => r.wasCapped));

  /// Flat list of every result, for a consolidated "3 Elf Warrior + 2 Squirrel"
  /// breakdown line.
  List<RhysCopyResult> get allResults => [for (final g in groups) ...g.results];
}

/// Builds the Rhys the Redeemed activation plan.
///
/// "For each creature token you control, create a token that's a copy of that
/// creature." The app has no separate model for *current* characteristics vs.
/// *copiable* values, so eligibility and copied P/T use the heuristics agreed
/// in `docs/activeDevelopment/.../RhysUtility.md`:
///
/// 1. A nonempty P/T means the stack is currently a creature → eligible.
/// 2. `Creature` in the stored type line means the P/T is part of the base
///    identity → copy it.
/// 3. No `Creature` in the type line means the P/T represents a temporary
///    animation → strip it from the copy (an animated Clue copies as a plain
///    Clue).
///
/// Name, colors, type, abilities and artwork are copied exactly as stored —
/// customized values are treated as the user's intended identity, with no
/// token-database lookup to second-guess them.
class RhysCopyPlanner {
  /// True if [item] is a creature token Rhys can copy right now.
  ///
  /// Emblems are never permanents Rhys sees, and an empty stack (amount 0,
  /// e.g. after a board wipe that zeroed instead of deleted) isn't on the
  /// battlefield.
  static bool isEligible(Item item) => TokenCopySemantics.isCreatureToken(item);

  /// P/T the copy should be created with, per the Creature-type heuristic.
  static String copiedPtFor(Item item) =>
      TokenCopySemantics.copiablePtFor(item);

  /// Snapshots [items], evaluates each eligible stack independently through
  /// the rules engine, and resolves artwork for every result.
  ///
  /// [tokenDatabase] must already be loaded; it is only consulted for tokens
  /// whose identity a replacement rule changed (an unchanged copy keeps the
  /// source's own artwork).
  static RhysCopyPlan build({
    required List<Item> items,
    required List<double> boardOrders,
    required RulesProvider rulesProvider,
    required TokenDatabase tokenDatabase,
  }) {
    final groups = <RhysCopyGroup>[];

    for (final source in items) {
      if (!isEligible(source)) continue;

      final copiedPt = copiedPtFor(source);
      final sourceIdentity =
          '${source.name}|$copiedPt|${source.colors}|${source.type}|${source.abilities}';

      // Each source stack feeds the engine independently, at its own amount —
      // unlike stacks are never combined before evaluation.
      final evaluated = rulesProvider.evaluateRules(
        source.name,
        copiedPt,
        source.colors,
        source.type,
        source.abilities,
        source.amount,
      );

      final results = <RhysCopyResult>[];
      for (int i = 0; i < evaluated.length; i++) {
        final r = evaluated[i];
        if (r.quantity <= 0) continue;

        // The primary result keeps the source's exact artwork only when no
        // replacement rule changed its identity. A rule that swaps the token
        // (Food → Treasure) also swaps its visual identity, so artwork is
        // resolved normally for the new identity. Companions always resolve
        // from their own identity.
        final keepsSourceArtwork = i == 0 && r.compositeId == sourceIdentity;

        if (keepsSourceArtwork) {
          results.add(RhysCopyResult(
            name: r.name,
            pt: r.pt,
            colors: r.colors,
            type: r.type,
            abilities: r.abilities,
            quantity: r.quantity,
            wasCapped: r.wasCapped,
            artworkUrl: source.artworkUrl,
            artworkSet: source.artworkSet,
            artworkOptions: source.artworkOptions != null
                ? List<ArtworkVariant>.from(source.artworkOptions!)
                : null,
          ));
        } else {
          final artwork = TokenResultArtworkResolver.resolve(
            result: r,
            tokenDatabase: tokenDatabase,
          );
          results.add(RhysCopyResult(
            name: r.name,
            pt: r.pt,
            colors: r.colors,
            type: r.type,
            abilities: r.abilities,
            quantity: r.quantity,
            wasCapped: r.wasCapped,
            artworkUrl: artwork.url,
            artworkSet: artwork.set,
            artworkOptions: artwork.options,
          ));
        }
      }

      if (results.isEmpty) continue;

      groups.add(RhysCopyGroup(
        source: source,
        copiedPt: copiedPt,
        results: results,
        nextBoardOrder: boardOrders
                .where((order) => order > source.order)
                .fold<double?>(
                    null,
                    (next, order) =>
                        next == null || order < next ? order : next) ??
            source.order + 1.0,
      ));
    }

    return RhysCopyPlan(groups);
  }
}

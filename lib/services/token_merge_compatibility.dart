import '../models/item.dart';

/// Canonical clean-stack compatibility used by token-creation and copy flows.
class TokenMergeCompatibility {
  const TokenMergeCompatibility._();

  static bool isClean(Item item) =>
      item.plusOneCounters == 0 &&
      item.minusOneCounters == 0 &&
      item.plusOnePowerCounters == 0 &&
      item.plusOneToughnessCounters == 0 &&
      item.counters.isEmpty;

  static bool matchesIdentity(
    Item item, {
    required String name,
    required String pt,
    required String colors,
    required String type,
    required String abilities,
    required String? artworkUrl,
  }) =>
      item.name == name &&
      item.pt == pt &&
      item.colors == colors &&
      item.type == type &&
      item.abilities == abilities &&
      item.artworkUrl == artworkUrl;

  static bool canMerge(
    Item item, {
    required String name,
    required String pt,
    required String colors,
    required String type,
    required String abilities,
    required String? artworkUrl,
  }) =>
      isClean(item) &&
      matchesIdentity(
        item,
        name: name,
        pt: pt,
        colors: colors,
        type: type,
        abilities: abilities,
        artworkUrl: artworkUrl,
      );
}

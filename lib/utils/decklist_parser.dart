/// Parses deck lists from various common export formats into card names.
///
/// Supported formats:
/// - Standard:    `1 Delina, Wild Mage (AFR) 317`
/// - Bare:        `1 Delina, Wild Mage`
/// - X-suffix:    `1x Biogenic Ooze (tmc) 49 [Creature]`
/// - Star-prefix: `*1 Biogenic Ooze`
/// - Name only:   `Biogenic Ooze`
/// - BBCode sections: `[Creatures]...[/Creatures]`
class DecklistParser {
  /// Pattern for section headers like [Creatures], [/deck], [deck title=...], [Commander{top}]
  static final _sectionHeaderPattern = RegExp(r'^\[.*\]$');

  /// Pattern for BBCode deck title: [deck title=Some Name]
  static final _deckTitlePattern = RegExp(r'^\[deck\s+title=(.+)\]$', caseSensitive: false);

  /// Pattern for quantity prefix: optional *, digits, optional x, then whitespace
  static final _qtyPattern = RegExp(r'^\*?(\d+)x?\s+');

  /// Parse a raw decklist string into a list of card names and an optional deck title.
  static DecklistParseResult parse(String input) {
    final cardNames = <String>{};
    String? deckTitle;

    for (final rawLine in input.split('\n')) {
      final line = rawLine.trim();

      // Skip blank lines
      if (line.isEmpty) continue;

      // Check for deck title
      final titleMatch = _deckTitlePattern.firstMatch(line);
      if (titleMatch != null) {
        deckTitle = titleMatch.group(1)?.trim();
        continue;
      }

      // Skip section headers
      if (_sectionHeaderPattern.hasMatch(line)) continue;

      // Strip quantity prefix
      String namePart;
      final qtyMatch = _qtyPattern.firstMatch(line);
      if (qtyMatch != null) {
        namePart = line.substring(qtyMatch.end);
      } else {
        namePart = line;
      }

      // Strip trailing metadata: everything from first ( or [ onward
      final parenIdx = namePart.indexOf('(');
      if (parenIdx > 0) {
        namePart = namePart.substring(0, parenIdx);
      }
      final bracketIdx = namePart.indexOf('[');
      if (bracketIdx > 0) {
        namePart = namePart.substring(0, bracketIdx);
      }

      // Strip foil flag
      namePart = namePart.replaceAll(RegExp(r'\s*\*F\*\s*$'), '');

      namePart = namePart.trim();
      if (namePart.isEmpty) continue;

      // Add full name
      cardNames.add(namePart);

      // For split/DFC cards, also add front face
      // Handle both " / " and " // " separators
      final splitIdx = namePart.indexOf(RegExp(r'\s+//?/?\s+'));
      if (splitIdx > 0) {
        final frontFace = namePart.substring(0, splitIdx).trim();
        if (frontFace.isNotEmpty) {
          cardNames.add(frontFace);
        }
      }
    }

    return DecklistParseResult(
      cardNames: cardNames.toList(),
      deckTitle: deckTitle,
    );
  }
}

class DecklistParseResult {
  final List<String> cardNames;
  final String? deckTitle;

  const DecklistParseResult({
    required this.cardNames,
    this.deckTitle,
  });
}

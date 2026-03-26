import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/token_database.dart';
import '../models/deck.dart';
import '../models/token_template.dart';
import '../models/token_definition.dart' as token_models;
import '../providers/deck_provider.dart';
import '../utils/color_utils.dart';
import '../utils/decklist_parser.dart';
import 'package:gradient_borders/gradient_borders.dart';
import '../utils/artwork_manager.dart';
import '../utils/constants.dart';
import '../widgets/common/background_text.dart';
import '../widgets/cropped_artwork_widget.dart';
import 'deck_detail_screen.dart';

/// Reads clipboard, parses decklist, and navigates to confirmation screen.
/// Call this from the decks list screen.
Future<void> importFromClipboardDecklist(BuildContext context) async {
  // Read clipboard
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final clipboardText = data?.text?.trim() ?? '';

  // Load token database
  final tokenDatabase = TokenDatabase();
  await tokenDatabase.loadTokens();

  if (!context.mounted) return;

  // Parse and match
  List<_MatchedToken> matches = [];
  String? deckTitle;

  if (clipboardText.isNotEmpty) {
    final parseResult = DecklistParser.parse(clipboardText);
    deckTitle = parseResult.deckTitle;
    final Map<String, _MatchedToken> matchMap = {};

    for (final cardName in parseResult.cardNames) {
      final tokens = tokenDatabase.findTokensByCardName(cardName);
      for (final token in tokens) {
        if (matchMap.containsKey(token.id)) {
          matchMap[token.id]!.sourceCards.add(cardName);
        } else {
          matchMap[token.id] = _MatchedToken(
            token: token,
            sourceCards: {cardName},
          );
        }
      }
    }

    matches = matchMap.values.toList()
      ..sort((a, b) => a.token.name.compareTo(b.token.name));
  }

  if (matches.isEmpty) {
    if (context.mounted) {
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No Tokens Detected'),
          content: const Text(
            'No tokens were detected in your clipboard content. '
            'Copy a decklist to your clipboard and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
      if (shouldRetry == true && context.mounted) {
        return importFromClipboardDecklist(context);
      }
    }
    return;
  }

  if (!context.mounted) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _DecklistConfirmScreen(
        matches: matches,
        deckTitle: deckTitle,
      ),
    ),
  );
}

// --- Confirmation Screen (full screen) ---

class _DecklistConfirmScreen extends StatefulWidget {
  final List<_MatchedToken> matches;
  final String? deckTitle;

  const _DecklistConfirmScreen({
    required this.matches,
    this.deckTitle,
  });

  @override
  State<_DecklistConfirmScreen> createState() => _DecklistConfirmScreenState();
}

class _DecklistConfirmScreenState extends State<_DecklistConfirmScreen> {
  @override
  void initState() {
    super.initState();
    _precacheArtwork();
  }

  void _precacheArtwork() async {
    final futures = <Future>[];
    for (final match in widget.matches) {
      final artwork = match.token.artwork;
      if (artwork.isNotEmpty) {
        futures.add(ArtworkManager.downloadArtwork(artwork.first.url));
      }
    }
    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  void _createDeck(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();

    final templates = <TokenTemplate>[];
    for (int i = 0; i < widget.matches.length; i++) {
      final token = widget.matches[i].token;
      final firstArtwork = token.artwork.isNotEmpty ? token.artwork.first : null;

      templates.add(TokenTemplate(
        name: token.name,
        pt: token.pt,
        abilities: token.abilities,
        colors: token.colors,
        type: token.type,
        order: i.toDouble(),
        artworkUrl: firstArtwork?.url,
        artworkSet: firstArtwork?.set,
        artworkOptions: token.artwork.isNotEmpty ? List.from(token.artwork) : null,
      ));
    }

    // Auto-detect color identity
    final colors = <String>{};
    for (final t in templates) {
      for (int i = 0; i < t.colors.length; i++) {
        if ('WUBRG'.contains(t.colors[i])) {
          colors.add(t.colors[i]);
        }
      }
    }
    final colorIdentity = StringBuffer();
    for (final c in ['W', 'U', 'B', 'R', 'G']) {
      if (colors.contains(c)) colorIdentity.write(c);
    }

    final deck = Deck(
      name: widget.deckTitle ?? 'Imported Deck',
      templates: templates,
      colorIdentity: colorIdentity.toString(),
    );
    deckProvider.saveDeck(deck);

    // Artwork already pre-cached in initState

    // Replace confirmation screen with deck detail
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DeckDetailScreen(deck: deck),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tokens Detected'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '${widget.matches.length} token${widget.matches.length == 1 ? '' : 's'} found in decklist',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.matches.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                return _buildTokenCard(context, widget.matches[index]);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _createDeck(context),
                icon: const Icon(Icons.add),
                label: Text('Create Deck (${widget.matches.length} tokens)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context, _MatchedToken match) {
    final token = match.token;
    final gradient = token.colors.isNotEmpty
        ? ColorUtils.gradientForColors(token.colors)
        : null;
    final artworkUrl = token.artwork.isNotEmpty ? token.artwork.first.url : null;
    const innerBorderRadius = UIConstants.borderRadius - 3.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        side: gradient != null
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: gradient != null
            ? BoxDecoration(
                border: GradientBoxBorder(
                  gradient: gradient,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(UIConstants.borderRadius),
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerBorderRadius),
          child: Stack(
            children: [
              // Base background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(innerBorderRadius),
                  ),
                ),
              ),

              // Artwork layer
              if (artworkUrl != null && !kIsWeb)
                Positioned.fill(
                  child: FutureBuilder<File?>(
                    future: ArtworkManager.getCachedArtworkFile(artworkUrl),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final crop = ArtworkManager.getCropPercentages(artworkUrl);
                        return CroppedArtworkWidget(
                          imageFile: snapshot.data!,
                          cropLeft: crop['left']!,
                          cropRight: crop['right']!,
                          cropTop: crop['top']!,
                          cropBottom: crop['bottom']!,
                          fillWidth: true,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

              // Content layer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BackgroundText(
                            child: Text(
                              token.pt.isNotEmpty ? '${token.name} ${token.pt}' : token.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          BackgroundText(
                            child: Text(
                              'From: ${match.sourceCards.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (token.abilities.isNotEmpty)
                      BackgroundText(
                        padding: const EdgeInsets.all(4),
                        child: Tooltip(
                          message: token.abilities,
                          child: Icon(Icons.info_outline, size: 20, color: Colors.grey[400]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Data classes ---

class _MatchedToken {
  final token_models.TokenDefinition token;
  final Set<String> sourceCards;

  _MatchedToken({required this.token, required this.sourceCards});
}

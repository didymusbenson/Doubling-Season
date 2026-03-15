import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/deck.dart';
import '../models/item.dart';
import '../models/token_template.dart';
import '../models/tracker_widget.dart';
import '../models/toggle_widget.dart';
import '../models/tracker_widget_template.dart';
import '../models/toggle_widget_template.dart';
import '../providers/deck_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/token_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';
import '../database/token_database.dart';
import '../models/token_definition.dart' as token_models;
import '../utils/constants.dart';
import '../utils/color_utils.dart';
import '../utils/artwork_manager.dart';
import '../widgets/common/background_text.dart';
import '../widgets/cropped_artwork_widget.dart';
import '../widgets/deck_save_sheet.dart';
import 'deck_detail_screen.dart';
import 'decklist_import_screen.dart';

class DecksListScreen extends StatefulWidget {
  const DecksListScreen({super.key});

  @override
  State<DecksListScreen> createState() => _DecksListScreenState();
}

class _DecksListScreenState extends State<DecksListScreen> {
  bool _editMode = false;
  final Set<int> _selectedIndices = {};

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();
    final artworkStyle = context.select<SettingsProvider, String>(
      (settings) => settings.artworkDisplayStyle,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        title: const Text('Decks'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.done : Icons.delete_outline),
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
                if (!_editMode) _selectedIndices.clear();
              });
            },
            tooltip: _editMode ? 'Done' : 'Delete',
          ),
          if (_isMobilePlatform)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _showImportOptions(context),
              tooltip: 'Import',
            ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: deckProvider.listenable,
        builder: (context, box, _) {
          final deckList = deckProvider.decks;

          if (deckList.isEmpty) {
            return _buildEmptyState();
          }

          return _buildDeckList(deckList, artworkStyle);
        },
      ),
      bottomNavigationBar: _editMode && _selectedIndices.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _bulkDelete(context),
                  icon: const Icon(Icons.delete),
                  label: Text('Delete ${_selectedIndices.length} deck${_selectedIndices.length == 1 ? '' : 's'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            )
          : !_editMode
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showSaveSheet(context),
                          icon: const Icon(Icons.save),
                          label: const Text('Save Board'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _createNewDeck(context),
                          icon: const Icon(Icons.add),
                          label: const Text('New Deck'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'No saved decks',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Use "Save Board" or "New Deck" below to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckList(List<Deck> deckList, String artworkStyle) {
    return ReorderableListView.builder(
      itemCount: deckList.length,
      padding: const EdgeInsets.only(
        top: UIConstants.listTopPadding,
        left: UIConstants.smallPadding,
        right: UIConstants.smallPadding,
        bottom: UIConstants.listBottomPadding,
      ),
      onReorder: (oldIndex, newIndex) {
        context.read<DeckProvider>().reorderDecks(oldIndex, newIndex);
      },
      proxyDecorator: _buildDragProxy,
      itemBuilder: (context, index) {
        final deck = deckList[index];
        return _buildDeckCard(deck, index, artworkStyle);
      },
    );
  }

  Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = lerpDouble(1.0, UIConstants.dragScaleFactor, animation.value) ?? 1.0;
        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: UIConstants.dragElevation,
            shadowColor: Colors.black.withValues(alpha: UIConstants.dragShadowOpacity),
            borderRadius: BorderRadius.circular(UIConstants.borderRadius),
            clipBehavior: Clip.antiAlias,
            type: MaterialType.transparency,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Builds a deck card with the gradient border as the outermost element.
  /// This matches the content_screen.dart pattern where the border Container
  /// is the keyed widget returned to ReorderableListView, ensuring the gradient
  /// border wraps the entire drag proxy during reorder.
  Widget _buildDeckCard(Deck deck, int index, String artworkStyle) {
    const borderWidth = 3.0;
    final innerBorderRadius = UIConstants.borderRadius - borderWidth;
    final colorIdentity = deck.colorIdentity ?? '';
    final artworkUrl = DeckProvider.resolveArtworkUrl(deck);
    final isFullView = artworkStyle == 'fullView';

    return Padding(
      key: ValueKey('deck_${deck.key}'),
      padding: const EdgeInsets.symmetric(vertical: UIConstants.verticalSpacing),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          border: GradientBoxBorder(
            gradient: ColorUtils.gradientForColors(colorIdentity),
            width: borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerBorderRadius),
          child: Material(
            color: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artworkWidth = constraints.maxWidth * UIConstants.artworkFadeoutWidthPercent;
                return Stack(
                  children: [
                    // Base background
                    Positioned.fill(
                      child: Container(color: Theme.of(context).cardColor),
                    ),

                    // Artwork layer
                    if (artworkUrl != null && artworkUrl.isNotEmpty && !kIsWeb)
                      _buildDeckArtwork(artworkUrl, innerBorderRadius, artworkWidth, isFullView),

                    // Content layer (InkWell + text)
                    InkWell(
                  onTap: _editMode ? null : () => _showDeckOptions(context, deck),
                  borderRadius: BorderRadius.circular(innerBorderRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BackgroundText(
                                child: Text(
                                  deck.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              BackgroundText(
                                child: Text(
                                  _buildSubtitle(deck),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_editMode)
                          Checkbox(
                            value: _selectedIndices.contains(index),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
                ); // Stack
              }, // LayoutBuilder builder
            ), // LayoutBuilder
          ), // Material
        ), // ClipRRect
      ), // Container (border)
    ); // Padding
  }

  Widget _buildDeckArtwork(String artworkUrl, double innerBorderRadius, double artworkWidth, bool isFullView) {
    return isFullView
        ? Positioned.fill(
            child: FutureBuilder<File?>(
              future: ArtworkManager.getCachedArtworkFile(artworkUrl),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final crop = ArtworkManager.getCropPercentages(artworkUrl);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(innerBorderRadius),
                    child: CroppedArtworkWidget(
                      imageFile: snapshot.data!,
                      cropLeft: crop['left']!,
                      cropRight: crop['right']!,
                      cropTop: crop['top']!,
                      cropBottom: crop['bottom']!,
                      fillWidth: true,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          )
        : Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: artworkWidth,
            child: FutureBuilder<File?>(
              future: ArtworkManager.getCachedArtworkFile(artworkUrl),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final crop = ArtworkManager.getCropPercentages(artworkUrl);
                  return ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(innerBorderRadius),
                      bottomRight: Radius.circular(innerBorderRadius),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Colors.transparent, Colors.white],
                          stops: [0.0, 0.50],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: CroppedArtworkWidget(
                        imageFile: snapshot.data!,
                        cropLeft: crop['left']!,
                        cropRight: crop['right']!,
                        cropTop: crop['top']!,
                        cropBottom: crop['bottom']!,
                        fillWidth: false,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          );
  }

  String _buildSubtitle(Deck deck) {
    final utilityCount = (deck.trackerWidgets?.length ?? 0) + (deck.toggleWidgets?.length ?? 0);

    if (deck.templates.isEmpty && utilityCount == 0) {
      return 'Empty deck';
    }

    final parts = <String>[];
    if (deck.templates.isNotEmpty) {
      final names = deck.templates.map((t) => t.name).toSet().toList();
      if (names.length <= 3) {
        parts.add(names.join(', '));
      } else {
        parts.add('${names.take(3).join(', ')}, and ${names.length - 3} others');
      }
    }
    if (utilityCount > 0) {
      parts.add('$utilityCount ${utilityCount == 1 ? 'utility' : 'utilities'}');
    }
    return parts.join(' + ');
  }

  void _showDeckOptions(BuildContext context, Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.style, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deck.name,
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildOptionTile(
                  context: sheetContext,
                  icon: Icons.play_arrow,
                  label: 'Clear board and load',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _loadDeckClearBoard(context, deck);
                  },
                ),
                const SizedBox(height: 4),
                _buildOptionTile(
                  context: sheetContext,
                  icon: Icons.add,
                  label: 'Add to current board',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _loadDeckAddToBoard(context, deck);
                  },
                ),
                if (_isMobilePlatform) ...[
                  const SizedBox(height: 4),
                  _buildOptionTile(
                    context: sheetContext,
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _shareDeck(context, deck);
                    },
                  ),
                ],
                const SizedBox(height: 4),
                _buildOptionTile(
                  context: sheetContext,
                  icon: Icons.edit,
                  label: 'Edit deck',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DeckDetailScreen(deck: deck),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                _buildOptionTile(
                  context: sheetContext,
                  icon: Icons.copy,
                  label: 'Duplicate',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.read<DeckProvider>().duplicateDeck(deck);
                  },
                ),
                const SizedBox(height: 4),
                _buildOptionTile(
                  context: sheetContext,
                  icon: Icons.delete,
                  label: 'Delete',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(context, deck);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Matches the FAB menu's _buildActionTile visual pattern
  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ensure any custom tokens in a deck exist in the custom token library.
  /// If a deck contains a token not found in the database or custom library,
  /// it gets recreated as a custom token so it's searchable/favoritable.
  void _ensureCustomTokensFromDeck(Deck deck) {
    final tokenDatabase = TokenDatabase();
    tokenDatabase.loadCustomTokens();

    for (final template in deck.templates) {
      final id = '${template.name}|${template.pt}|${template.colors}|${template.type}|${template.abilities}';
      if (tokenDatabase.findTokenById(id) != null) continue;

      // Build artwork list from template
      final artwork = <token_models.ArtworkVariant>[];
      if (template.artworkOptions != null) {
        artwork.addAll(template.artworkOptions!);
      } else if (template.artworkUrl != null) {
        artwork.add(token_models.ArtworkVariant(
          set: template.artworkSet ?? 'custom',
          url: template.artworkUrl!,
        ));
      }

      final definition = token_models.TokenDefinition(
        name: template.name,
        pt: template.pt,
        type: template.type,
        colors: template.colors,
        abilities: template.abilities,
        popularity: 0,
        artwork: artwork,
      );
      tokenDatabase.saveCustomToken(definition);
    }

    tokenDatabase.dispose();
  }

  Future<void> _loadDeckClearBoard(BuildContext context, Deck deck) async {
    final deckProvider = context.read<DeckProvider>();
    final tokenProvider = context.read<TokenProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();

    _ensureCustomTokensFromDeck(deck);
    await deckProvider.loadDeckClearBoard(deck, tokenProvider, trackerProvider, toggleProvider);

    if (context.mounted) {
      Navigator.pop(context); // Pop back to board
    }
  }

  Future<void> _loadDeckAddToBoard(BuildContext context, Deck deck) async {
    final deckProvider = context.read<DeckProvider>();
    final tokenProvider = context.read<TokenProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();

    _ensureCustomTokensFromDeck(deck);
    await deckProvider.loadDeckAddToBoard(deck, tokenProvider, trackerProvider, toggleProvider);

    if (context.mounted) {
      Navigator.pop(context); // Pop back to board
    }
  }

  Future<void> _shareDeck(BuildContext context, Deck deck) async {
    try {
      final deckProvider = context.read<DeckProvider>();
      final json = await deckProvider.exportDeckToJson(deck);

      // Sanitize filename
      final safeName = deck.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final fileName = '$safeName.json';

      debugPrint('DeckProvider: Sharing deck "${deck.name}"');

      await Share.shareXFiles(
        [XFile.fromData(
          utf8.encode(json),
          name: fileName,
          mimeType: 'application/json',
        )],
        subject: deck.name,
      );
    } catch (e) {
      debugPrint('DeckProvider: Share failed - $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share deck: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Delete "${deck.name}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<DeckProvider>().deleteDeck(deck);
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _bulkDelete(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();
    final deckList = deckProvider.decks;
    final count = _selectedIndices.length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Decks'),
        content: Text('Delete $count deck${count == 1 ? '' : 's'}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Collect decks to delete (by index, sorted descending to avoid index shifting)
              final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
              for (final idx in sorted) {
                if (idx < deckList.length) {
                  deckProvider.deleteDeck(deckList[idx]);
                }
              }
              debugPrint('DeckProvider: Bulk deleted $count decks');
              _selectedIndices.clear();
              Navigator.pop(dialogContext);
              setState(() {
                _editMode = false;
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSaveSheet(BuildContext context) {
    final tokenProvider = context.read<TokenProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
    final deckProvider = context.read<DeckProvider>();

    // Auto-detect colors from the board
    final boardColors = <String>{};
    for (final item in tokenProvider.items) {
      for (int i = 0; i < item.colors.length; i++) {
        if ('WUBRG'.contains(item.colors[i])) {
          boardColors.add(item.colors[i]);
        }
      }
    }
    for (final tracker in trackerProvider.trackers) {
      for (int i = 0; i < tracker.colorIdentity.length; i++) {
        if ('WUBRG'.contains(tracker.colorIdentity[i])) {
          boardColors.add(tracker.colorIdentity[i]);
        }
      }
    }
    for (final toggle in toggleProvider.toggles) {
      for (int i = 0; i < toggle.colorIdentity.length; i++) {
        if ('WUBRG'.contains(toggle.colorIdentity[i])) {
          boardColors.add(toggle.colorIdentity[i]);
        }
      }
    }

    // Build WUBRG-ordered string
    final suggestedColors = StringBuffer();
    for (final c in ['W', 'U', 'B', 'R', 'G']) {
      if (boardColors.contains(c)) suggestedColors.write(c);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DeckSaveSheet(suggestedColors: suggestedColors.toString()),
    ).then((result) {
      if (result == null || result is! DeckSaveResult) return;

      // Collect all board items with their orders
      final allBoardItems = <_BoardItemForSave>[];

      for (final item in tokenProvider.items) {
        allBoardItems.add(_BoardItemForSave(item, item.order, 'token'));
      }
      for (final tracker in trackerProvider.trackers) {
        allBoardItems.add(_BoardItemForSave(tracker, tracker.order, 'tracker'));
      }
      for (final toggle in toggleProvider.toggles) {
        allBoardItems.add(_BoardItemForSave(toggle, toggle.order, 'toggle'));
      }

      allBoardItems.sort((a, b) => a.order.compareTo(b.order));

      // Dedup tokens on name|pt|colors|type|abilities|artworkUrl
      final Map<String, bool> seenTokens = {};
      final List<TokenTemplate> templates = [];
      final List<TrackerWidgetTemplate> trackerTemplates = [];
      final List<ToggleWidgetTemplate> toggleTemplates = [];

      int normalizedIndex = 0;
      for (final boardItem in allBoardItems) {
        if (boardItem.type == 'token') {
          final item = boardItem.item as Item;
          final key = '${item.name}|${item.pt}|${item.colors}|${item.type}|${item.abilities}|${item.artworkUrl}';
          if (!seenTokens.containsKey(key)) {
            seenTokens[key] = true;
            final template = TokenTemplate.fromItem(item);
            template.order = normalizedIndex.toDouble();
            templates.add(template);
            normalizedIndex++;
          }
        } else if (boardItem.type == 'tracker') {
          final tracker = boardItem.item as TrackerWidget;
          final template = TrackerWidgetTemplate.fromWidget(tracker);
          template.order = normalizedIndex.toDouble();
          trackerTemplates.add(template);
          normalizedIndex++;
        } else if (boardItem.type == 'toggle') {
          final toggle = boardItem.item as ToggleWidget;
          final template = ToggleWidgetTemplate.fromWidget(toggle);
          template.order = normalizedIndex.toDouble();
          toggleTemplates.add(template);
          normalizedIndex++;
        }
      }

      final dedupCount = tokenProvider.items.length - templates.length;
      debugPrint('DeckProvider: Save dedup - ${tokenProvider.items.length} board tokens collapsed into ${templates.length} templates ($dedupCount duplicates removed)');
      debugPrint('DeckProvider: Save color auto-detection result: ${suggestedColors.toString()}, user selected: ${result.colorIdentity}');

      final deck = Deck(
        name: result.name,
        templates: templates,
        trackerWidgets: trackerTemplates.isEmpty ? null : trackerTemplates,
        toggleWidgets: toggleTemplates.isEmpty ? null : toggleTemplates,
        colorIdentity: result.colorIdentity,
      );
      deckProvider.saveDeck(deck);
    });
  }

  void _createNewDeck(BuildContext context) {
    final deckProvider = context.read<DeckProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const DeckSaveSheet(
        title: 'New Deck',
        buttonLabel: 'Create',
      ),
    ).then((result) {
      if (result == null || result is! DeckSaveResult) return;

      final deck = Deck(
        name: result.name,
        templates: [],
      );
      deck.colorIdentity = result.colorIdentity;
      deckProvider.saveDeck(deck);

      // Open the new deck for editing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DeckDetailScreen(deck: deck),
            ),
          );
        }
      });
    });
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              context: sheetContext,
              icon: Icons.list_alt,
              label: 'Import from Decklist',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(sheetContext);
                showDecklistImportSheet(context);
              },
            ),
            const SizedBox(height: 4),
            _buildOptionTile(
              context: sheetContext,
              icon: Icons.file_open,
              label: 'Import Deck File',
              color: Colors.green,
              onTap: () {
                Navigator.pop(sheetContext);
                _importDeck(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _importDeck(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'tsdeck'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String? jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final fileObj = File(file.path!);
        jsonString = await fileObj.readAsString();
      }

      if (jsonString == null) {
        throw Exception('Could not read file');
      }

      debugPrint('DeckProvider: Import - file picked: ${file.name}');

      if (context.mounted) {
        await context.read<DeckProvider>().importDeckFromJson(jsonString);
      }
    } catch (e) {
      debugPrint('DeckProvider: Import failed - $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import deck: $e')),
        );
      }
    }
  }
}

/// Helper class for preserving exact order when saving decks
class _BoardItemForSave {
  final dynamic item;
  final double order;
  final String type;

  _BoardItemForSave(this.item, this.order, this.type);
}


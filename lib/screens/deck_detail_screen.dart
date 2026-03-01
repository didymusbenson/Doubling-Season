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
import '../models/token_template.dart';
import '../models/token_definition.dart' as token_models;
import '../models/tracker_widget_template.dart';
import '../models/toggle_widget_template.dart';
import '../models/widget_definition.dart';
import '../providers/deck_provider.dart';
import '../utils/constants.dart';
import '../utils/color_utils.dart';
import '../utils/artwork_manager.dart';
import '../widgets/color_selection_button.dart';
import '../widgets/common/background_text.dart';
import '../widgets/cropped_artwork_widget.dart';
import 'token_search_screen.dart';
import 'widget_selection_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  final Deck deck;

  const DeckDetailScreen({super.key, required this.deck});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  late TextEditingController _nameController;
  bool _editMode = false;
  final Set<int> _selectedIndices = {};

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.deck.name);
    _precacheAllDeckArtwork();
  }

  /// Pre-cache artwork for all templates in the deck on open.
  /// Also auto-assigns artworkUrl from artworkOptions for templates that were
  /// saved before artwork assignment was implemented (old decks / migrations).
  void _precacheAllDeckArtwork() {
    if (kIsWeb) return;
    bool needsSave = false;

    for (final t in widget.deck.templates) {
      if (_autoAssignArtwork(t.artworkUrl, t.artworkOptions, (url, set) {
        t.artworkUrl = url;
        t.artworkSet = set;
      })) {
        needsSave = true;
      }
      _precacheArtwork(t.artworkUrl);
    }

    if (widget.deck.trackerWidgets != null) {
      for (final t in widget.deck.trackerWidgets!) {
        if (_autoAssignArtwork(t.artworkUrl, t.artworkOptions, (url, set) {
          t.artworkUrl = url;
          t.artworkSet = set;
        })) {
          needsSave = true;
        }
        _precacheArtwork(t.artworkUrl);
      }
    }

    if (widget.deck.toggleWidgets != null) {
      for (final t in widget.deck.toggleWidgets!) {
        if (_autoAssignArtwork(t.artworkUrl, t.artworkOptions, (url, set) {
          t.artworkUrl = url;
          t.artworkSet = set;
        })) {
          needsSave = true;
        }
        _precacheArtwork(t.artworkUrl);
      }
    }

    if (needsSave) {
      _updateLastModified();
      debugPrint('DeckDetailScreen: Auto-assigned artwork for templates missing artworkUrl');
    }
  }

  /// If artworkUrl is null but artworkOptions has entries, auto-assign the first one.
  /// Returns true if assignment was made.
  bool _autoAssignArtwork(String? artworkUrl, List<token_models.ArtworkVariant>? options, void Function(String url, String set) assign) {
    if (artworkUrl == null && options != null && options.isNotEmpty) {
      assign(options[0].url, options[0].set);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Get all templates as a unified list with type info, sorted by order
  List<_DeckItem> get _deckItems {
    final items = <_DeckItem>[];

    for (final t in widget.deck.templates) {
      items.add(_DeckItem(template: t, order: t.order, type: 'token'));
    }

    if (widget.deck.trackerWidgets != null) {
      for (final t in widget.deck.trackerWidgets!) {
        items.add(_DeckItem(template: t, order: t.order, type: 'tracker'));
      }
    }

    if (widget.deck.toggleWidgets != null) {
      for (final t in widget.deck.toggleWidgets!) {
        items.add(_DeckItem(template: t, order: t.order, type: 'toggle'));
      }
    }

    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  }

  void _updateLastModified() {
    widget.deck.lastModifiedAt = DateTime.now();
    widget.deck.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editing ${widget.deck.name}'),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.done : Icons.edit),
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
                if (!_editMode) _selectedIndices.clear();
              });
            },
            tooltip: _editMode ? 'Done' : 'Edit',
          ),
          if (_isMobilePlatform)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareDeck(context),
              tooltip: 'Share',
            ),
        ],
      ),
      body: Column(
        children: [
          // Deck header: editable name + color identity
          _buildDeckHeader(),

          // Template list
          Expanded(
            child: _buildTemplateList(),
          ),

          // Add buttons
          _buildAddButtons(),
        ],
      ),
      bottomNavigationBar: _editMode && _selectedIndices.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _bulkDelete(),
                  icon: const Icon(Icons.delete),
                  label: Text('Delete ${_selectedIndices.length} item${_selectedIndices.length == 1 ? '' : 's'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDeckHeader() {
    final colors = widget.deck.colorIdentity ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editable name + Deck Box thumbnail
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Deck Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    if (value.trim().isNotEmpty) {
                      widget.deck.name = value.trim();
                      _updateLastModified();
                      setState(() {}); // Update app bar title
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildDeckBoxThumbnail(),
            ],
          ),
          const SizedBox(height: 12),

          // Color identity toggles
          Text(
            'Color Identity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorToggle('W', Colors.yellow.shade200, 'White', colors),
              _buildColorToggle('U', Colors.blue, 'Blue', colors),
              _buildColorToggle('B', Colors.purple, 'Black', colors),
              _buildColorToggle('R', Colors.red, 'Red', colors),
              _buildColorToggle('G', Colors.green, 'Green', colors),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeckBoxThumbnail() {
    final artworkUrl = DeckProvider.resolveArtworkUrl(widget.deck);

    return GestureDetector(
      onTap: () => _pickDeckBoxImage(),
      onLongPress: widget.deck.customArtworkUrl != null ? () => _clearCustomArtwork() : null,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade400,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.5),
              child: _buildThumbnailContent(artworkUrl),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Deck Box',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailContent(String? artworkUrl) {
    if (artworkUrl == null || artworkUrl.isEmpty || kIsWeb) {
      return Center(
        child: Icon(Icons.photo_camera, size: 24, color: Colors.grey.shade400),
      );
    }

    // Check if it's a local file path (custom artwork)
    if (artworkUrl.startsWith('file://')) {
      final file = File(artworkUrl.replaceFirst('file://', ''));
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, width: 60, height: 60);
      }
      return Center(
        child: Icon(Icons.photo_camera, size: 24, color: Colors.grey.shade400),
      );
    }

    // Scryfall URL - use cached artwork
    return FutureBuilder<File?>(
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
        return Center(
          child: Icon(Icons.photo_camera, size: 24, color: Colors.grey.shade400),
        );
      },
    );
  }

  Future<void> _pickDeckBoxImage() async {
    if (kIsWeb) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      // Resize the picked file (overwrites temp file in place)
      final resized = await ArtworkManager.resizeImageFile(File(filePath));

      // Copy to persistent app-managed location so it survives temp cleanup
      final cacheDir = await ArtworkManager.getArtworkCacheDirectory();
      final deckKey = widget.deck.key ?? 'unknown';
      final persistentFile = File('${cacheDir.path}/deck_box_$deckKey.png');
      await resized.copy(persistentFile.path);

      setState(() {
        widget.deck.customArtworkUrl = 'file://${persistentFile.path}';
        _updateLastModified();
      });
    } catch (e) {
      debugPrint('DeckDetailScreen: Failed to pick deck box image - $e');
    }
  }

  void _clearCustomArtwork() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Custom Art'),
        content: const Text('Remove custom deck box art? The thumbnail will revert to the first token\'s artwork.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                widget.deck.customArtworkUrl = null;
                _updateLastModified();
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorToggle(String symbol, Color color, String label, String currentColors) {
    return ColorSelectionButton(
      symbol: symbol,
      isSelected: currentColors.contains(symbol),
      color: color,
      label: label,
      onChanged: (selected) {
        setState(() {
          final colors = Set<String>.from(
            (widget.deck.colorIdentity ?? '').split('').where((c) => 'WUBRG'.contains(c)),
          );
          if (selected) {
            colors.add(symbol);
          } else {
            colors.remove(symbol);
          }
          // Rebuild in WUBRG order
          final buffer = StringBuffer();
          for (final c in ['W', 'U', 'B', 'R', 'G']) {
            if (colors.contains(c)) buffer.write(c);
          }
          widget.deck.colorIdentity = buffer.toString();
          _updateLastModified();
        });
      },
    );
  }

  Widget _buildTemplateList() {
    final items = _deckItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.token, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No tokens or utilities in this deck',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the buttons below to add some',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onReorder: (oldIndex, newIndex) => _handleReorder(items, oldIndex, newIndex),
      proxyDecorator: _buildDragProxy,
      itemBuilder: (context, index) {
        final item = items[index];

        // Use stable key based on type + identity hash to avoid Dismissible conflicts after removal
        final stableKey = '${item.type}_${identityHashCode(item.template)}';

        if (_editMode) {
          return Container(
            key: ValueKey('edit_$stableKey'),
            child: _buildItemCardWithCheckbox(item, index),
          );
        }

        // Border wraps outside, Dismissible inside ClipRRect so red slides within the card
        return _buildDismissibleCard(
          key: ValueKey('dismiss_$stableKey'),
          item: item,
        );
      },
    );
  }

  /// Wraps card content in the correct border structure matching content_screen.dart:
  /// Padding (margin) → Container (gradient border) → ClipRRect → Material (card color)
  Widget _buildBorderedCard({required String colorIdentity, required Widget child, bool transparentBackground = false}) {
    const borderWidth = 3.0;
    final innerBorderRadius = UIConstants.borderRadius - borderWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            color: transparentBackground ? Colors.transparent : Theme.of(context).cardColor,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Builds a deck item card with the Dismissible INSIDE the ClipRRect,
  /// so the red swipe background is contained within the gradient border.
  /// Matches the content_screen.dart pattern.
  Widget _buildDismissibleCard({required Key key, required _DeckItem item}) {
    const borderWidth = 3.0;
    final innerBorderRadius = UIConstants.borderRadius - borderWidth;
    final colorIdentity = _getItemColorIdentity(item);

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          child: Dismissible(
            key: ValueKey('inner_dismiss_${identityHashCode(item.template)}'),
            direction: DismissDirection.endToStart,
            background: Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(innerBorderRadius),
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove item?'),
                  content: Text('Remove "${_getItemName(item)}" from this deck?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ) ?? false;
            },
            onDismissed: (_) {
              _removeItem(item);
            },
            child: Material(
              color: Colors.transparent,
              child: _buildItemContent(item),
            ),
          ),
        ),
      ),
    );
  }


  /// Edit-mode card with checkbox on the right, matching DecksListScreen pattern.
  Widget _buildItemCardWithCheckbox(_DeckItem item, int index) {
    return _buildBorderedCard(
      colorIdentity: _getItemColorIdentity(item),
      transparentBackground: true,
      child: _buildItemContent(item, checkboxIndex: index),
    );
  }

  String _getItemColorIdentity(_DeckItem item) {
    if (item.type == 'token') return (item.template as TokenTemplate).colors;
    if (item.type == 'tracker') return (item.template as TrackerWidgetTemplate).colorIdentity;
    return (item.template as ToggleWidgetTemplate).colorIdentity;
  }

  /// Builds a deck item with full-width artwork background and BackgroundText,
  /// matching the TokenCard visual pattern. Used for all item types.
  Widget _buildItemWithArtwork({
    required String? artworkUrl,
    required String name,
    required String subtitle,
    String? trailing,
    IconData? leadingIcon,
    int? checkboxIndex,
  }) {
    const innerBorderRadius = UIConstants.borderRadius - 3.0;

    return Stack(
      children: [
        // Base background
        Positioned.fill(
          child: Container(color: Theme.of(context).cardColor),
        ),

        // Full-width artwork layer
        if (artworkUrl != null && artworkUrl.isNotEmpty && !kIsWeb)
          Positioned.fill(
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
          ),

        // Content layer with BackgroundText
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                BackgroundText(
                  padding: const EdgeInsets.all(4),
                  child: Icon(leadingIcon, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BackgroundText(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      BackgroundText(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                BackgroundText(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    trailing,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (checkboxIndex != null)
                _buildCheckbox(checkboxIndex),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemContent(_DeckItem item, {int? checkboxIndex}) {
    if (item.type == 'token') {
      final template = item.template as TokenTemplate;
      return _buildItemWithArtwork(
        artworkUrl: template.artworkUrl,
        name: template.name,
        subtitle: template.abilities,
        trailing: template.pt.isNotEmpty ? template.pt : null,
        checkboxIndex: checkboxIndex,
      );
    } else if (item.type == 'tracker') {
      final template = item.template as TrackerWidgetTemplate;
      return _buildItemWithArtwork(
        artworkUrl: template.artworkUrl,
        name: template.name,
        subtitle: template.description,
        leadingIcon: Icons.show_chart,
        checkboxIndex: checkboxIndex,
      );
    } else {
      final template = item.template as ToggleWidgetTemplate;
      return _buildItemWithArtwork(
        artworkUrl: template.artworkUrl,
        name: template.name,
        subtitle: template.onDescription,
        leadingIcon: Icons.toggle_on,
        checkboxIndex: checkboxIndex,
      );
    }
  }

  Widget _buildCheckbox(int index) {
    return Checkbox(
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
    );
  }

  String _getItemName(_DeckItem item) {
    if (item.type == 'token') return (item.template as TokenTemplate).name;
    if (item.type == 'tracker') return (item.template as TrackerWidgetTemplate).name;
    return (item.template as ToggleWidgetTemplate).name;
  }

  void _removeItem(_DeckItem item) {
    setState(() {
      if (item.type == 'token') {
        widget.deck.templates.remove(item.template);
      } else if (item.type == 'tracker') {
        widget.deck.trackerWidgets?.remove(item.template);
      } else {
        widget.deck.toggleWidgets?.remove(item.template);
      }
      _updateLastModified();
    });
  }

  void _bulkDelete() {
    final items = _deckItems;
    final count = _selectedIndices.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove items?'),
        content: Text('Remove $count item${count == 1 ? '' : 's'} from this deck?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Collect items to remove (sorted descending)
              final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
              for (final idx in sorted) {
                if (idx < items.length) {
                  _removeItem(items[idx]);
                }
              }
              debugPrint('DeckProvider: Bulk deleted $count items from deck "${widget.deck.name}"');
              _selectedIndices.clear();
              Navigator.pop(ctx);
              setState(() {
                _editMode = false;
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _handleReorder(List<_DeckItem> items, int oldIndex, int newIndex) {
    final movingDown = newIndex > oldIndex;
    if (newIndex > oldIndex) newIndex -= 1;

    final item = items[oldIndex];

    double newOrder;
    if (newIndex == 0) {
      newOrder = items.first.order - 1.0;
    } else if (newIndex == items.length - 1) {
      newOrder = items.last.order + 1.0;
    } else {
      if (movingDown) {
        newOrder = (items[newIndex].order + items[newIndex + 1].order) / 2.0;
      } else {
        newOrder = (items[newIndex - 1].order + items[newIndex].order) / 2.0;
      }
    }

    // Update the order on the template
    if (item.type == 'token') {
      (item.template as TokenTemplate).order = newOrder;
    } else if (item.type == 'tracker') {
      (item.template as TrackerWidgetTemplate).order = newOrder;
    } else {
      (item.template as ToggleWidgetTemplate).order = newOrder;
    }

    _updateLastModified();

    // Check compaction
    final updated = _deckItems;
    for (int i = 0; i < updated.length - 1; i++) {
      if ((updated[i + 1].order - updated[i].order) < 0.001) {
        for (int j = 0; j < updated.length; j++) {
          if (updated[j].type == 'token') {
            (updated[j].template as TokenTemplate).order = j.toDouble();
          } else if (updated[j].type == 'tracker') {
            (updated[j].template as TrackerWidgetTemplate).order = j.toDouble();
          } else {
            (updated[j].template as ToggleWidgetTemplate).order = j.toDouble();
          }
        }
        debugPrint('DeckProvider: Compacted template orders in deck "${widget.deck.name}"');
        break;
      }
    }

    setState(() {});
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

  Widget _buildAddButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addToken(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Token'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addUtility(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Utility'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToken() async {
    final result = await Navigator.of(context).push<token_models.TokenDefinition>(
      MaterialPageRoute(
        builder: (context) => const TokenSearchScreen(selectorMode: true),
        fullscreenDialog: true,
      ),
    );

    if (result == null) return;

    // Build a TokenTemplate from the selected definition
    final template = TokenTemplate(
      name: result.name,
      pt: result.pt,
      abilities: result.abilities,
      colors: result.colors,
      type: result.type,
      order: _nextOrder(),
      artworkUrl: result.artwork.isNotEmpty ? result.artwork[0].url : null,
      artworkSet: result.artwork.isNotEmpty ? result.artwork[0].set : null,
      artworkOptions: result.artwork.isNotEmpty ? List.from(result.artwork) : null,
    );

    setState(() {
      widget.deck.templates.add(template);
      _updateLastModified();
    });

    // Pre-cache artwork so it appears immediately in the deck list
    _precacheArtwork(template.artworkUrl);
  }

  Future<void> _addUtility() async {
    final result = await Navigator.of(context).push<WidgetDefinition>(
      MaterialPageRoute(
        builder: (context) => const WidgetSelectionScreen(selectorMode: true),
        fullscreenDialog: true,
      ),
    );

    if (result == null) return;

    final order = _nextOrder();

    setState(() {
      if (result.type == WidgetType.tracker || result.type == WidgetType.special) {
        final template = TrackerWidgetTemplate(
          name: result.name,
          description: result.description,
          colorIdentity: result.colorIdentity,
          defaultValue: result.defaultValue ?? 0,
          tapIncrement: result.tapIncrement,
          longPressIncrement: result.longPressIncrement,
          hasAction: result.hasAction,
          actionButtonText: result.actionButtonText,
          actionType: result.actionType,
          order: order,
          artworkUrl: result.artwork.isNotEmpty ? result.artwork[0].url : null,
          artworkSet: result.artwork.isNotEmpty ? result.artwork[0].set : null,
          artworkOptions: result.artwork.isNotEmpty ? List.from(result.artwork) : null,
        );
        widget.deck.trackerWidgets ??= [];
        widget.deck.trackerWidgets!.add(template);
      } else if (result.type == WidgetType.toggle) {
        final template = ToggleWidgetTemplate(
          name: result.name,
          colorIdentity: result.colorIdentity,
          onDescription: result.description,
          offDescription: result.offDescription ?? '',
          order: order,
          artworkUrl: result.artwork.isNotEmpty ? result.artwork[0].url : null,
          artworkSet: result.artwork.isNotEmpty ? result.artwork[0].set : null,
          artworkOptions: result.artwork.isNotEmpty ? List.from(result.artwork) : null,
        );
        widget.deck.toggleWidgets ??= [];
        widget.deck.toggleWidgets!.add(template);
      }
      _updateLastModified();
    });

    // Pre-cache artwork so it appears immediately in the deck list
    if (result.artwork.isNotEmpty) {
      _precacheArtwork(result.artwork[0].url);
    }
  }

  /// Fire-and-forget download of artwork to local cache so it renders in deck cards.
  void _precacheArtwork(String? url) {
    if (url == null || url.isEmpty || url.startsWith('file://') || kIsWeb) return;
    ArtworkManager.downloadArtwork(url).then((_) {
      if (mounted) setState(() {}); // Rebuild to show newly cached artwork
    }).catchError((e) {
      debugPrint('DeckDetailScreen: Artwork precache failed for $url - $e');
    });
  }

  double _nextOrder() {
    final items = _deckItems;
    if (items.isEmpty) return 0.0;
    return items.last.order.floor() + 1.0;
  }

  Future<void> _shareDeck(BuildContext context) async {
    try {
      final deckProvider = context.read<DeckProvider>();
      final json = await deckProvider.exportDeckToJson(widget.deck);

      final safeName = widget.deck.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final fileName = '$safeName.json';

      debugPrint('DeckProvider: Sharing deck "${widget.deck.name}"');

      await Share.shareXFiles(
        [XFile.fromData(
          utf8.encode(json),
          name: fileName,
          mimeType: 'application/json',
        )],
        subject: widget.deck.name,
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
}

/// Helper class for unified deck item list
class _DeckItem {
  final dynamic template;
  final double order;
  final String type; // 'token', 'tracker', 'toggle'

  _DeckItem({required this.template, required this.order, required this.type});
}

import 'dart:convert' show utf8;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:share_plus/share_plus.dart';
import '../models/deck.dart';
import '../models/token_template.dart';
import '../models/token_definition.dart' as token_models;
import '../models/tracker_widget_template.dart';
import '../models/toggle_widget_template.dart';
import '../models/widget_definition.dart';
import '../providers/deck_provider.dart';
import '../utils/constants.dart';
import '../utils/color_utils.dart';
import '../widgets/color_selection_button.dart';
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
        title: Text(widget.deck.name),
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
          // Editable name
          TextField(
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
      itemBuilder: (context, index) {
        final item = items[index];

        if (_editMode) {
          return Container(
            key: ValueKey('deckitem_edit_$index'),
            child: Row(
              children: [
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
                Expanded(child: _buildItemCard(item)),
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),
              ],
            ),
          );
        }

        return Dismissible(
          key: ValueKey('deckitem_dismiss_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
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
          child: _buildItemCard(item),
        );
      },
    );
  }

  Widget _buildItemCard(_DeckItem item) {
    if (item.type == 'token') {
      final template = item.template as TokenTemplate;
      final colorIdentity = template.colors;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          border: GradientBoxBorder(
            gradient: ColorUtils.gradientForColors(colorIdentity),
            width: 3.0,
          ),
        ),
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (template.abilities.isNotEmpty)
                        Text(
                          template.abilities,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (template.pt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      template.pt,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } else if (item.type == 'tracker') {
      final template = item.template as TrackerWidgetTemplate;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          border: GradientBoxBorder(
            gradient: ColorUtils.gradientForColors(template.colorIdentity),
            width: 3.0,
          ),
        ),
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
          child: ListTile(
            leading: const Icon(Icons.show_chart, size: 20),
            title: Text(template.name),
            subtitle: Text(template.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            dense: true,
          ),
        ),
      );
    } else {
      final template = item.template as ToggleWidgetTemplate;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          border: GradientBoxBorder(
            gradient: ColorUtils.gradientForColors(template.colorIdentity),
            width: 3.0,
          ),
        ),
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
          child: ListTile(
            leading: const Icon(Icons.toggle_on, size: 20),
            title: Text(template.name),
            subtitle: Text(template.onDescription, maxLines: 1, overflow: TextOverflow.ellipsis),
            dense: true,
          ),
        ),
      );
    }
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

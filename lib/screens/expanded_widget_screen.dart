import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracker_widget.dart';
import '../models/toggle_widget.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';
import '../widgets/artwork_selection_sheet.dart';
import '../widgets/color_selection_button.dart';
import '../utils/artwork_manager.dart';
import '../database/widget_database.dart';

class ExpandedWidgetScreen extends StatefulWidget {
  final dynamic widget; // TrackerWidget or ToggleWidget
  final bool isTracker;

  const ExpandedWidgetScreen({
    super.key,
    required this.widget,
    required this.isTracker,
  });

  @override
  State<ExpandedWidgetScreen> createState() => _ExpandedWidgetScreenState();
}

class _ExpandedWidgetScreenState extends State<ExpandedWidgetScreen> {
  bool _artworkCleanupAttempted = false;
  late TextEditingController _descriptionController;

  // Cached artwork Future to prevent FutureBuilder rebuilds
  Future<File?>? _cachedArtworkFuture;

  // Widget database for loading artwork options
  final _widgetDatabase = WidgetDatabase();

  // Color selection state (same as ExpandedTokenScreen)
  late bool _whiteSelected;
  late bool _blueSelected;
  late bool _blackSelected;
  late bool _redSelected;
  late bool _greenSelected;

  @override
  void initState() {
    super.initState();
    // Cache the artwork Future
    if (_artworkUrl != null) {
      _cachedArtworkFuture = ArtworkManager.getCachedArtworkFile(_artworkUrl!);
    }

    // Initialize description controller for trackers
    if (widget.isTracker) {
      _descriptionController = TextEditingController(
        text: (widget.widget as TrackerWidget).description,
      );
    }

    // Initialize color selections from widget's colorIdentity
    final colorIdentity = widget.isTracker
        ? (widget.widget as TrackerWidget).colorIdentity
        : (widget.widget as ToggleWidget).colorIdentity;
    _whiteSelected = colorIdentity.contains('W');
    _blueSelected = colorIdentity.contains('U');
    _blackSelected = colorIdentity.contains('B');
    _redSelected = colorIdentity.contains('R');
    _greenSelected = colorIdentity.contains('G');

    // Load widget definition to populate artwork options if needed (matching token pattern)
    _loadWidgetDefinition();
  }

  @override
  void dispose() {
    if (widget.isTracker) {
      _descriptionController.dispose();
    }
    super.dispose();
  }

  String get _widgetId {
    return widget.isTracker
        ? (widget.widget as TrackerWidget).widgetId
        : (widget.widget as ToggleWidget).widgetId;
  }

  String get _name {
    return widget.isTracker
        ? (widget.widget as TrackerWidget).name
        : (widget.widget as ToggleWidget).name;
  }

  String get _description {
    if (widget.isTracker) {
      return (widget.widget as TrackerWidget).description;
    } else {
      final toggle = widget.widget as ToggleWidget;
      return '${toggle.onDescription}\n\n${toggle.offDescription}';
    }
  }

  String? get _artworkUrl {
    return widget.isTracker
        ? (widget.widget as TrackerWidget).artworkUrl
        : (widget.widget as ToggleWidget).artworkUrl;
  }

  set _artworkUrl(String? value) {
    if (widget.isTracker) {
      (widget.widget as TrackerWidget).artworkUrl = value;
    } else {
      (widget.widget as ToggleWidget).artworkUrl = value;
    }
    // Update cached future
    _cachedArtworkFuture = value != null ? ArtworkManager.getCachedArtworkFile(value) : null;
  }

  String? get _artworkSet {
    return widget.isTracker
        ? (widget.widget as TrackerWidget).artworkSet
        : (widget.widget as ToggleWidget).artworkSet;
  }

  set _artworkSet(String? value) {
    if (widget.isTracker) {
      (widget.widget as TrackerWidget).artworkSet = value;
    } else {
      (widget.widget as ToggleWidget).artworkSet = value;
    }
  }

  void _saveWidget() {
    if (widget.isTracker) {
      context.read<TrackerProvider>().updateTracker(widget.widget as TrackerWidget);
    } else {
      context.read<ToggleProvider>().updateToggle(widget.widget as ToggleWidget);
    }
  }

  void _updateColors() {
    String newColors = '';
    if (_whiteSelected) newColors += 'W';
    if (_blueSelected) newColors += 'U';
    if (_blackSelected) newColors += 'B';
    if (_redSelected) newColors += 'R';
    if (_greenSelected) newColors += 'G';

    if (widget.isTracker) {
      (widget.widget as TrackerWidget).colorIdentity = newColors;
    } else {
      (widget.widget as ToggleWidget).colorIdentity = newColors;
    }
    _saveWidget();
  }

  void _deleteWidget() {
    if (widget.isTracker) {
      context.read<TrackerProvider>().deleteTracker(widget.widget as TrackerWidget);
    } else {
      context.read<ToggleProvider>().deleteToggle(widget.widget as ToggleWidget);
    }
  }

  /// Load widget definition to populate artwork options if needed
  /// Matches ExpandedTokenScreen pattern (lines 83-136)
  Future<void> _loadWidgetDefinition() async {
    try {
      // PRIORITY 1: Use artworkOptions from widget if available (persisted from creation)
      final currentOptions = widget.isTracker
          ? (widget.widget as TrackerWidget).artworkOptions
          : (widget.widget as ToggleWidget).artworkOptions;

      if (currentOptions != null && currentOptions.isNotEmpty) {
        // Artwork options already loaded, no need to fetch from database
        return;
      }

      // PRIORITY 2: Load from widget database (synchronous - no async load needed)
      // Note: Unlike TokenDatabase which loads from JSON, WidgetDatabase is hardcoded
      // so loadWidgets() completes synchronously in the constructor

      // Find matching widget definition by name
      final matchingDefinition = _widgetDatabase.filteredWidgets.cast<dynamic>().firstWhere(
        (def) => def.name == _name,
        orElse: () => null,
      );

      // If no matching definition found, this is likely a custom widget (no artwork available)
      if (matchingDefinition == null) {
        debugPrint('No widget definition found for: $_name (likely custom widget)');
        return;
      }

      // Store artwork options on widget for future use
      if (matchingDefinition.artwork.isNotEmpty) {
        if (widget.isTracker) {
          final tracker = widget.widget as TrackerWidget;
          tracker.artworkOptions = List.from(matchingDefinition.artwork);
          tracker.save();
        } else {
          final toggle = widget.widget as ToggleWidget;
          toggle.artworkOptions = List.from(matchingDefinition.artwork);
          toggle.save();
        }
      }
    } catch (e) {
      debugPrint('Error loading widget definition: $e');
      // Silent failure - utility will work without artwork options
    }
  }

  void _showArtworkSelection() {
    // Get artwork options from the utility (already loaded in initState)
    final artworkOptions = widget.isTracker
        ? (widget.widget as TrackerWidget).artworkOptions
        : (widget.widget as ToggleWidget).artworkOptions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ArtworkSelectionSheet(
          artworkVariants: artworkOptions ?? [],
          onArtworkSelected: _handleArtworkSelected,
          onRemoveArtwork: _artworkUrl != null ? _removeArtwork : null,
          currentArtworkUrl: _artworkUrl,
          currentArtworkSet: _artworkSet,
          tokenName: _name,
          tokenIdentity: _widgetId, // Use utility ID as identity
          databaseLoadError: false,
        ),
      ),
    );
  }

  void _handleArtworkSelected(String artworkUrl, String? setCode) {
    setState(() {
      _artworkUrl = artworkUrl;
      _artworkSet = setCode;
      _saveWidget();
    });
  }

  void _removeArtwork() {
    setState(() {
      _artworkUrl = null;
      _artworkSet = null;
      _saveWidget();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utility Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              _deleteWidget();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name (read-only)
            _buildReadOnlyField(
              label: 'Name',
              value: _name,
              context: context,
            ),

            const SizedBox(height: 16),

            // Description (editable for trackers, read-only for toggles)
            if (widget.isTracker)
              _buildEditableDescriptionField(context)
            else
              _buildReadOnlyField(
                label: 'States',
                value: _description,
                context: context,
                maxLines: null,
              ),

            const SizedBox(height: 16),

            // Color Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Colors',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ColorSelectionButton(
                          symbol: 'W',
                          isSelected: _whiteSelected,
                          color: Colors.yellow,
                          label: 'White',
                          onChanged: (value) {
                            setState(() => _whiteSelected = value);
                            _updateColors();
                          },
                        ),
                        ColorSelectionButton(
                          symbol: 'U',
                          isSelected: _blueSelected,
                          color: Colors.blue,
                          label: 'Blue',
                          onChanged: (value) {
                            setState(() => _blueSelected = value);
                            _updateColors();
                          },
                        ),
                        ColorSelectionButton(
                          symbol: 'B',
                          isSelected: _blackSelected,
                          color: Colors.purple,
                          label: 'Black',
                          onChanged: (value) {
                            setState(() => _blackSelected = value);
                            _updateColors();
                          },
                        ),
                        ColorSelectionButton(
                          symbol: 'R',
                          isSelected: _redSelected,
                          color: Colors.red,
                          label: 'Red',
                          onChanged: (value) {
                            setState(() => _redSelected = value);
                            _updateColors();
                          },
                        ),
                        ColorSelectionButton(
                          symbol: 'G',
                          isSelected: _greenSelected,
                          color: Colors.green,
                          label: 'Green',
                          onChanged: (value) {
                            setState(() => _greenSelected = value);
                            _updateColors();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Artwork Selection
            _buildArtworkSection(context),

            const SizedBox(height: 24),

            // Help text
            Text(
              widget.isTracker
                  ? 'Tap +/- to adjust value. Long-press for ${(widget.widget as TrackerWidget).longPressIncrement}.'
                  : 'Tap the checkbox button on the card to toggle ON/OFF state.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableDescriptionField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            hintText: 'Add optional description...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) {
            // Save description to tracker
            (widget.widget as TrackerWidget).description = value;
            _saveWidget();
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required BuildContext context,
    int? maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          width: double.infinity,
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkSection(BuildContext context) {
    return GestureDetector(
      onTap: _showArtworkSelection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Artwork',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            // Display artwork thumbnail or "select" text
            if (kIsWeb && _artworkUrl != null && !_artworkUrl!.startsWith('file://'))
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _artworkUrl!,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildSelectArtworkPrompt(context),
                ),
              )
            else if (!kIsWeb && _cachedArtworkFuture != null)
              FutureBuilder<File?>(
                future: _cachedArtworkFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.data == null) {
                      // Cleanup: Remove invalid artwork URL
                      if (!_artworkCleanupAttempted) {
                        _artworkCleanupAttempted = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _artworkUrl = null;
                              _saveWidget();
                            });
                          }
                        });
                      }
                      return _buildSelectArtworkPrompt(context);
                    }

                    final file = snapshot.data!;
                    // Add unique key for custom artwork to force reload on replacement
                    final isCustomArtwork = _artworkUrl!.startsWith('file://');
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        key: isCustomArtwork ? ValueKey(file.path + file.lastModifiedSync().toString()) : null,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              )
            else
              _buildSelectArtworkPrompt(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectArtworkPrompt(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.image,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        const SizedBox(width: 12),
        Text(
          'Tap to select artwork',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

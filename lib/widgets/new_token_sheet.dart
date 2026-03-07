import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/token_definition.dart' as token_models;
import '../providers/token_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';
import '../providers/settings_provider.dart';
import '../database/token_database.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_preference_manager.dart';
import 'color_selection_button.dart';

class NewTokenSheet extends StatefulWidget {
  /// When true, pops with a TokenDefinition instead of creating on the board.
  final bool selectorMode;

  const NewTokenSheet({super.key, this.selectorMode = false});

  @override
  State<NewTokenSheet> createState() => _NewTokenSheetState();
}

class _NewTokenSheetState extends State<NewTokenSheet> {
  final _nameController = TextEditingController();
  final _ptController = TextEditingController();
  final _typeController = TextEditingController();
  final _abilitiesController = TextEditingController();

  int _amount = 1;
  bool _createTapped = false;
  bool _isCreating = false; // Prevent multi-tap
  File? _stagedArtwork; // Temp file picked by user, moved to custom_artwork/ on create

  // CRITICAL: SwiftUI NewTokenSheet uses ColorSelectionButton, not TextField
  bool _whiteSelected = false;
  bool _blueSelected = false;
  bool _blackSelected = false;
  bool _redSelected = false;
  bool _greenSelected = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ptController.dispose();
    _typeController.dispose();
    _abilitiesController.dispose();
    super.dispose();
  }

  String _getColorString() {
    String colors = '';
    if (_whiteSelected) colors += 'W';
    if (_blueSelected) colors += 'U';
    if (_blackSelected) colors += 'B';
    if (_redSelected) colors += 'R';
    if (_greenSelected) colors += 'G';
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Token'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createToken,
            child: Text(
              _isCreating ? 'Creating...' : 'Create',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Token Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _ptController,
              decoration: const InputDecoration(
                labelText: 'Power/Toughness',
                hintText: 'e.g., 1/1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Type',
                hintText: 'e.g., Creature — Elf Warrior',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Color Selection (using ColorSelectionButton from Phase 2)
            const Text(
              'Colors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  onChanged: (value) => setState(() => _whiteSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'U',
                  isSelected: _blueSelected,
                  color: Colors.blue,
                  label: 'Blue',
                  onChanged: (value) => setState(() => _blueSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'B',
                  isSelected: _blackSelected,
                  color: Colors.purple,
                  label: 'Black',
                  onChanged: (value) => setState(() => _blackSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'R',
                  isSelected: _redSelected,
                  color: Colors.red,
                  label: 'Red',
                  onChanged: (value) => setState(() => _redSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'G',
                  isSelected: _greenSelected,
                  color: Colors.green,
                  label: 'Green',
                  onChanged: (value) => setState(() => _greenSelected = value),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _abilitiesController,
              decoration: const InputDecoration(
                labelText: 'Abilities',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 16),
              _buildArtworkUpload(),
            ],
            // Hide quantity/multiplier/tapped in selector mode (deck editing)
            if (!widget.selectorMode) ...[
              const SizedBox(height: 24),

              const Text(
                'Quantity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  IconButton(
                    onPressed: _amount > 1 ? () => setState(() => _amount--) : null,
                    icon: const Icon(Icons.remove_circle),
                    iconSize: 32,
                  ),
                  Expanded(
                    child: Text(
                      '$_amount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _amount++),
                    icon: const Icon(Icons.add_circle),
                    iconSize: 32,
                  ),
                ],
              ),

              if (multiplier > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Current multiplier: x$multiplier - Final amount will be ${_amount * multiplier}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              SwitchListTile(
                title: const Text('Create Tapped'),
                subtitle: const Text('Tokens enter the battlefield tapped'),
                value: _createTapped,
                onChanged: (value) => setState(() => _createTapped = value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkUpload() {
    if (_stagedArtwork != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(_stagedArtwork!, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Artwork attached',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _stagedArtwork = null),
            icon: const Icon(Icons.close),
            tooltip: 'Remove artwork',
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _pickArtwork,
      icon: const Icon(Icons.image),
      label: const Text('Upload Artwork'),
    );
  }

  Future<void> _pickArtwork() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      // Get theme colors to match app styling
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final toolbarColor = const Color(0xFF0061a4);
      final backgroundColor = isDark ? const Color(0xFF181818) : Colors.white;
      const toolbarWidgetColor = Colors.white;
      final cropFrameColor = isDark ? Colors.white : Colors.black;
      final cropGridColor = isDark
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.3);
      final dimmedLayerColor = isDark ? Colors.black : Colors.white.withValues(alpha: 0.5);

      // Crop with locked 4:3 aspect ratio (matches artwork_selection_sheet)
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Token Artwork',
            toolbarColor: toolbarColor,
            toolbarWidgetColor: toolbarWidgetColor,
            backgroundColor: backgroundColor,
            activeControlsWidgetColor: toolbarColor,
            dimmedLayerColor: dimmedLayerColor,
            cropFrameColor: cropFrameColor,
            cropGridColor: cropGridColor,
            cropGridStrokeWidth: 1,
            cropFrameStrokeWidth: 2,
            initAspectRatio: CropAspectRatioPreset.ratio4x3,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Token Artwork',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      // Resize to cap at 768px on longest edge (matches artwork_selection_sheet)
      final resized = await ArtworkManager.resizeImageFile(File(croppedFile.path));
      setState(() => _stagedArtwork = resized);
    } catch (e) {
      debugPrint('NewTokenSheet: Failed to pick artwork - $e');
    }
  }

  /// Move staged artwork from temp to persistent custom_artwork/ directory.
  /// Returns file:// URL on success, null on failure.
  Future<String?> _commitStagedArtwork() async {
    if (_stagedArtwork == null) return null;
    try {
      final customDir = await ArtworkManager.getCustomUploadsDirectory();
      final fileName = 'custom_${const Uuid().v4()}.png';
      final persistentFile = await _stagedArtwork!.copy('${customDir.path}/$fileName');
      return 'file://${persistentFile.path}';
    } catch (e) {
      debugPrint('NewTokenSheet: Failed to commit staged artwork - $e');
      return null;
    }
  }

  Future<void> _createToken() async {
    if (_nameController.text.isEmpty) {
      return;
    }

    // Selector mode: build a TokenDefinition and pop it back
    if (widget.selectorMode) {
      // Commit staged artwork if present so it persists beyond this sheet
      final artworkList = <token_models.ArtworkVariant>[];
      if (_stagedArtwork != null) {
        final artworkUrl = await _commitStagedArtwork();
        if (artworkUrl != null) {
          artworkList.add(token_models.ArtworkVariant(set: 'custom', url: artworkUrl));
        }
      }

      final definition = token_models.TokenDefinition(
        name: _nameController.text,
        pt: _ptController.text,
        type: _typeController.text.trim(),
        colors: _getColorString(),
        abilities: _abilitiesController.text,
        popularity: 0,
        artwork: artworkList,
      );

      // Persist to custom token library
      final tokenDatabase = TokenDatabase();
      tokenDatabase.saveCustomToken(definition);
      tokenDatabase.dispose();

      if (mounted) {
        Navigator.pop(context, definition);
      }
      return;
    }

    // Prevent multi-tap
    setState(() => _isCreating = true);

    final tokenProvider = context.read<TokenProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
    final settings = context.read<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;
    final finalAmount = _amount * multiplier;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    final newOrder = maxOrder.floor() + 1.0;

    // Create final token immediately (no placeholder)
    final newItem = Item(
      name: _nameController.text,
      pt: _ptController.text,
      type: _typeController.text.trim(),
      colors: _getColorString(),
      abilities: _abilitiesController.text,
      amount: finalAmount,
      tapped: _createTapped ? finalAmount : 0,
      summoningSick: 0, // Will be set below if needed
      order: newOrder,
    );

    // Apply artwork: staged upload takes priority, then check preferences
    if (_stagedArtwork != null) {
      final artworkUrl = await _commitStagedArtwork();
      if (artworkUrl != null) {
        newItem.artworkUrl = artworkUrl;
      }
    } else {
      // Load preferred artwork from preferences (Custom Artwork Feature)
      final artworkPrefManager = ArtworkPreferenceManager();
      final tokenIdentity = '${newItem.name}|${newItem.pt}|${newItem.colors}|${newItem.type}|${newItem.abilities}';
      final preferredArtwork = artworkPrefManager.getPreferredArtwork(tokenIdentity);
      if (preferredArtwork != null) {
        newItem.artworkUrl = preferredArtwork;
      }
    }

    // Persist to custom token library (after artwork is resolved)
    {
      final customArtwork = <token_models.ArtworkVariant>[];
      if (newItem.artworkUrl != null) {
        customArtwork.add(token_models.ArtworkVariant(
          set: 'custom',
          url: newItem.artworkUrl!,
        ));
      }
      final definition = token_models.TokenDefinition(
        name: _nameController.text,
        pt: _ptController.text,
        type: _typeController.text.trim(),
        colors: _getColorString(),
        abilities: _abilitiesController.text,
        popularity: 0,
        artwork: customArtwork,
      );
      final tokenDatabase = TokenDatabase();
      tokenDatabase.saveCustomToken(definition);
      tokenDatabase.addToRecent(definition, settings);
      tokenDatabase.dispose();
    }

    // Insert token immediately
    await tokenProvider.insertItem(newItem);

    // Apply summoning sickness if enabled AND token is a creature without Haste
    // (must be after insert because setter calls save())
    if (settings.summoningSicknessEnabled &&
        newItem.hasPowerToughness &&
        !newItem.hasHaste) {
      newItem.summoningSick = finalAmount;
    }

    // Close dialog - token is on board and usable
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

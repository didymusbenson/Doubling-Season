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
import '../providers/rules_provider.dart';
import '../database/token_database.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_preference_manager.dart';
import 'color_selection_button.dart';
import '../services/token_creation_service.dart';

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

              Builder(
                builder: (context) {
                  final rulesProvider = context.read<RulesProvider>();
                  if (!rulesProvider.hasActiveRules) return const SizedBox.shrink();
                  final results = rulesProvider.evaluateRules(
                    _nameController.text.isEmpty ? 'Token' : _nameController.text,
                    _ptController.text,
                    _getColorString(),
                    _typeController.text.trim(),
                    _abilitiesController.text,
                    _amount,
                  );
                  final previewText = results.length == 1
                      ? 'Final amount: ${results.first.quantity}'
                      : results.map((r) => '${r.quantity} ${r.name}').join(' + ');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      previewText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),

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
    final rulesProvider = context.read<RulesProvider>();

    final tokenName = _nameController.text;
    final tokenPt = _ptController.text;
    final tokenType = _typeController.text.trim();
    final tokenColors = _getColorString();
    final tokenAbilities = _abilitiesController.text;

    // Evaluate rules to get all tokens to create
    final results = rulesProvider.evaluateRules(
      tokenName, tokenPt, tokenColors, tokenType, tokenAbilities, _amount,
    );

    // Commit staged artwork for the primary token
    String? stagedArtworkUrl;
    if (_stagedArtwork != null) {
      stagedArtworkUrl = await _commitStagedArtwork();
    }

    // Persist to custom token library
    {
      final customArtwork = <token_models.ArtworkVariant>[];
      if (stagedArtworkUrl != null) {
        customArtwork.add(token_models.ArtworkVariant(
          set: 'custom',
          url: stagedArtworkUrl,
        ));
      }
      final definition = token_models.TokenDefinition(
        name: tokenName,
        pt: tokenPt,
        type: tokenType,
        colors: tokenColors,
        abilities: tokenAbilities,
        popularity: 0,
        artwork: customArtwork,
      );
      final tokenDatabase = TokenDatabase();
      tokenDatabase.saveCustomToken(definition);
      tokenDatabase.addToRecent(definition, settings);
      tokenDatabase.dispose();
    }

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    double nextOrder = maxOrder.floor() + 1.0;

    // Create primary token (results.first)
    final primaryResult = results.first;
    if (primaryResult.quantity > 0) {
      String? artworkUrl;
      if (stagedArtworkUrl != null) {
        artworkUrl = stagedArtworkUrl;
      } else {
        final artworkPrefManager = ArtworkPreferenceManager();
        final tokenIdentity = '${primaryResult.name}|${primaryResult.pt}|${primaryResult.colors}|${primaryResult.type}|${primaryResult.abilities}';
        artworkUrl = artworkPrefManager.getPreferredArtwork(tokenIdentity);
      }

      final newItem = Item(
        name: primaryResult.name,
        pt: primaryResult.pt,
        type: primaryResult.type,
        colors: primaryResult.colors,
        abilities: primaryResult.abilities,
        amount: primaryResult.quantity,
        tapped: _createTapped ? primaryResult.quantity : 0,
        summoningSick: 0,
        order: nextOrder,
        artworkUrl: artworkUrl,
      );
      nextOrder += 1.0;

      await tokenProvider.insertItem(newItem);

      // Apply summoning sickness AFTER insert
      if (settings.summoningSicknessEnabled &&
          newItem.hasPowerToughness &&
          !newItem.hasHaste) {
        newItem.summoningSick = primaryResult.quantity;
      }
    }

    // Create companion tokens via shared service
    if (results.length > 1) {
      final tokenDatabase = TokenDatabase();
      await TokenCreationService.createCompanionTokens(
        results: results,
        tokenProvider: tokenProvider,
        summoningSicknessEnabled: settings.summoningSicknessEnabled,
        insertionOrder: nextOrder,
        tokenDatabase: tokenDatabase,
      );
      tokenDatabase.dispose();
    }

    // Check if any results were capped
    final wasCapped = results.any((r) => r.wasCapped);

    // Show cap alert before closing (context is still valid)
    if (wasCapped && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Woah there!'),
          content: const Text(
            'Looks like your deck is popping off. Congrats! '
            'For performance reasons, tokens have been capped at 999,999. '
            'Please win the game this turn.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    // Close dialog - token is on board and usable
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

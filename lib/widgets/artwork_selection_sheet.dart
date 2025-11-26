import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/token_definition.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_preference_manager.dart';

/// Bottom sheet for selecting token artwork from available variants
class ArtworkSelectionSheet extends StatefulWidget {
  final List<ArtworkVariant> artworkVariants;
  final Function(String url, String setCode) onArtworkSelected;
  final VoidCallback? onRemoveArtwork;
  final String? currentArtworkUrl;
  final String? currentArtworkSet;
  final String tokenName;
  final String tokenIdentity; // Composite ID for preference lookup (NEW - Custom Artwork Feature)
  final bool databaseLoadError; // Whether token database failed to load

  const ArtworkSelectionSheet({
    super.key,
    required this.artworkVariants,
    required this.onArtworkSelected,
    this.onRemoveArtwork,
    this.currentArtworkUrl,
    this.currentArtworkSet,
    required this.tokenName,
    required this.tokenIdentity,
    this.databaseLoadError = false,
  });

  @override
  State<ArtworkSelectionSheet> createState() => _ArtworkSelectionSheetState();
}

class _ArtworkSelectionSheetState extends State<ArtworkSelectionSheet> {
  bool _isDownloading = false;

  Future<void> _downloadAllArtwork() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download All Artwork'),
        content: Text('Download all artwork for ${widget.tokenName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDownloading = true;
    });

    int successCount = 0;
    int failCount = 0;
    bool hadNetworkError = false;

    // Download each artwork sequentially
    for (final variant in widget.artworkVariants) {
      try {
        // Check if already cached
        final cachedFile = await ArtworkManager.getCachedArtworkFile(variant.url);
        if (cachedFile == null) {
          // Download if not cached
          final result = await ArtworkManager.downloadArtwork(variant.url);
          if (result != null) {
            successCount++;
          } else {
            failCount++;
          }
          // Rebuild after each download to show progress
          if (mounted) {
            setState(() {});
          }
        } else {
          successCount++;
        }
      } catch (e) {
        debugPrint('Failed to download artwork from ${variant.set}: $e');
        failCount++;
        if (e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup')) {
          hadNetworkError = true;
        }
        // Continue with next artwork even if one fails
      }
    }

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Token Artwork',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.artworkVariants.isNotEmpty)
                        IconButton(
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download),
                          onPressed: _isDownloading ? null : _downloadAllArtwork,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Database load error message
                    if (widget.databaseLoadError)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 40,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Token database failed to load. Artwork options may not be available.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Currently selected artwork (only show if there's artwork selected)
                    if (widget.currentArtworkUrl != null && widget.onRemoveArtwork != null)
                      Container(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Thumbnail
                              FutureBuilder<File?>(
                                future: ArtworkManager.getCachedArtworkFile(widget.currentArtworkUrl!),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    final file = snapshot.data!;
                                    // Add unique key for custom artwork to force reload on replacement
                                    final isCustomArtwork = widget.currentArtworkUrl!.startsWith('file://');
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        file,
                                        key: isCustomArtwork ? ValueKey(file.path + file.lastModifiedSync().toString()) : null,
                                        width: 80,
                                        height: 112,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      width: 80,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.image,
                                        size: 40,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  }
                                },
                              ),

                              const SizedBox(width: 16),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Currently Selected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.currentArtworkSet ?? 'Unknown Set',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Remove button
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onRemoveArtwork!();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.currentArtworkUrl != null && widget.onRemoveArtwork != null)
                      const Divider(height: 1),

                    // Artwork options grid (always show, even if no Scryfall variants)
                    // Grid always includes custom artwork upload tile at index 0
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65, // Adjust for card proportions
                        ),
                        itemCount: widget.artworkVariants.length + 1, // +1 for custom tile
                        itemBuilder: (context, index) {
                          // First tile: Custom artwork upload tile
                          if (index == 0) {
                            return _CustomArtworkTile(
                              tokenIdentity: widget.tokenIdentity,
                              isSelected: widget.currentArtworkUrl?.startsWith('file://') ?? false,
                              currentArtworkUrl: widget.currentArtworkUrl,
                              onUploadComplete: (filePath) {
                                // Apply custom artwork to token
                                setState(() {});
                                Navigator.pop(context); // Close sheet
                                widget.onArtworkSelected(filePath, 'Custom Upload');
                              },
                              onRemoveArtwork: widget.onRemoveArtwork,
                            );
                          }

                          // Remaining tiles: Scryfall artwork options
                          final variant = widget.artworkVariants[index - 1];
                          return _ArtworkOption(
                            variant: variant,
                            onTap: () async {
                              // Show confirmation preview dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => _ArtworkConfirmationDialog(
                                  variant: variant,
                                ),
                              );

                              // Rebuild to show newly cached artwork
                              if (mounted) {
                                setState(() {});
                              }

                              if (confirmed == true && context.mounted) {
                                Navigator.pop(context); // Close selection sheet
                                widget.onArtworkSelected(variant.url, variant.set);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual artwork option card
class _ArtworkOption extends StatelessWidget {
  final ArtworkVariant variant;
  final VoidCallback onTap;

  const _ArtworkOption({
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail
          Expanded(
            child: FutureBuilder<File?>(
              future: ArtworkManager.getCachedArtworkFile(variant.url),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  // Show cached image
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  );
                } else {
                  // Show download placeholder
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.download,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          // Set code
          Text(
            variant.set,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog with artwork preview
class _ArtworkConfirmationDialog extends StatelessWidget {
  final ArtworkVariant variant;

  const _ArtworkConfirmationDialog({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large preview image
            FutureBuilder<File?>(
              future: _downloadAndCache(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 300,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading preview...'),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  // Check if it's a network error
                  final isNetworkError = snapshot.error.toString().contains('SocketException') ||
                      snapshot.error.toString().contains('Failed host lookup');

                  return Container(
                    height: 300,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          isNetworkError
                              ? 'Failed to load image.\n\nPlease check your internet connection.'
                              : 'Failed to load image:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasData && snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      height: 400,
                    ),
                  );
                } else {
                  return Container(
                    height: 300,
                    alignment: Alignment.center,
                    child: const Text(
                      'No image available.\n\nPlease check your internet connection.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Set info
            Text(
              variant.set,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Download and cache artwork, showing progress
  Future<File?> _downloadAndCache(BuildContext context) async {
    try {
      final file = await ArtworkManager.downloadArtwork(variant.url);
      return file;
    } catch (e) {
      rethrow;
    }
  }
}

/// Custom artwork upload tile (NEW - Custom Artwork Feature)
/// Shows camera icon when no custom art exists, thumbnail when it does
class _CustomArtworkTile extends StatefulWidget {
  final String tokenIdentity;
  final bool isSelected; // Is the current artwork the custom artwork?
  final String? currentArtworkUrl; // Current artwork URL to check at deletion time
  final Function(String filePath) onUploadComplete;
  final VoidCallback? onRemoveArtwork; // Called when custom artwork is deleted

  const _CustomArtworkTile({
    required this.tokenIdentity,
    required this.isSelected,
    required this.currentArtworkUrl,
    required this.onUploadComplete,
    this.onRemoveArtwork,
  });

  @override
  State<_CustomArtworkTile> createState() => _CustomArtworkTileState();
}

class _CustomArtworkTileState extends State<_CustomArtworkTile> {
  final _artworkPrefManager = ArtworkPreferenceManager();
  final _imagePicker = ImagePicker();

  Future<void> _handleTap() async {
    final hasCustom = _artworkPrefManager.hasCustomArtwork(widget.tokenIdentity);

    if (hasCustom) {
      // State B: Show replacement dialog
      await _showReplacementDialog();
    } else {
      // State A: Show educational dialog then picker
      await _showEducationalDialogAndPick();
    }
  }

  Future<void> _showEducationalDialogAndPick() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Artwork Tips'),
        content: const Text(
          'For best results:\n\n'
          '• Use high-quality images\n'
          '• You will be prompted to crop to a 4:3 aspect ratio\n'
          '• The cropped image will fit perfectly on the token card\n\n'
          'Ready to select an image?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _pickAndSaveImage();
    }
  }

  Future<void> _showReplacementDialog() async {
    final customPath = _artworkPrefManager.getCustomArtworkPath(widget.tokenIdentity);

    final action = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and X button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Custom Artwork',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom artwork preview
              if (customPath != null)
                Builder(
                  builder: (context) {
                    final file = File(customPath.replaceFirst('file://', ''));
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        key: ValueKey(file.path + file.lastModifiedSync().toString()),
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Delete button (destructive)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, 'delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Upload New button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'upload'),
                      child: const Text('Upload New'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Use This button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'use'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Use This'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Handle the selected action
    if (action == 'delete' && mounted) {
      await _deleteCustomArtwork();
    } else if (action == 'upload' && mounted) {
      await _pickAndSaveImage();
    } else if (action == 'use' && mounted) {
      // Reselect this custom artwork
      final customPath = _artworkPrefManager.getCustomArtworkPath(widget.tokenIdentity);
      if (customPath != null) {
        setState(() {});
        widget.onUploadComplete(customPath);
      }
    }
  }

  Future<void> _deleteCustomArtwork() async {
    try {
      final customPath = _artworkPrefManager.getCustomArtworkPath(widget.tokenIdentity);

      if (customPath != null) {
        // Delete the physical file
        final file = File(customPath.replaceFirst('file://', ''));
        if (await file.exists()) {
          await file.delete();
        }

        // Clear the preference
        await _artworkPrefManager.setCustomArtwork(widget.tokenIdentity, null);

        // Only clear the currently selected artwork if the custom artwork IS CURRENTLY selected
        // Check current selection at deletion time (not cached isSelected from sheet open)
        final isCustomCurrentlySelected = widget.currentArtworkUrl?.startsWith('file://') ?? false;
        if (widget.onRemoveArtwork != null && isCustomCurrentlySelected) {
          // Close the artwork selection sheet (to avoid showing stale "Currently Selected")
          // Then the parent will clear the item's artwork
          if (mounted) {
            // Pop the sheet, then notify parent after a frame
            Navigator.of(context, rootNavigator: true).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onRemoveArtwork!();
            });
          }
        } else {
          // Update UI if custom wasn't selected (tile changes from thumbnail to upload icon)
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      // Silent failure - no user feedback needed
      debugPrint('Failed to delete custom artwork: $e');
    }
  }

  Future<void> _pickAndSaveImage() async {
    try {
      // Step 1: Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      // Get theme colors to match app styling
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      // AESTHETIC DECISION: Use Material 3 light mode primary blue for toolbar in both modes
      // Dark mode's auto-generated lighter blue was too light; this darker blue provides
      // better visual consistency and matches the button colors users see in light mode
      final toolbarColor = const Color(0xFF0061a4);

      // Theme-aware colors
      final backgroundColor = isDark ? const Color(0xFF181818) : Colors.white;
      final toolbarWidgetColor = Colors.white;
      final statusBarColor = Color.alphaBlend(
        Colors.black.withValues(alpha: 0.2),
        toolbarColor,
      ); // Slightly darker than toolbar
      final cropFrameColor = isDark ? Colors.white : Colors.black;
      final cropGridColor = isDark
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.3);
      final dimmedLayerColor = isDark ? Colors.black : Colors.white.withValues(alpha: 0.5);

      // Step 2: Crop image with locked 4:3 aspect ratio
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Token Artwork',
            toolbarColor: toolbarColor,
            toolbarWidgetColor: toolbarWidgetColor,
            statusBarColor: statusBarColor,
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

      // User cancelled cropping
      if (croppedFile == null) return;

      // Delete old custom artwork file if it exists AND clear image cache
      final oldCustomPath = _artworkPrefManager.getCustomArtworkPath(widget.tokenIdentity);
      if (oldCustomPath != null) {
        final oldFile = File(oldCustomPath.replaceFirst('file://', ''));
        if (await oldFile.exists()) {
          // Clear Flutter's image cache for the old file
          final fileImage = FileImage(oldFile);
          fileImage.evict();

          // Delete the file
          await oldFile.delete();
        }
      }

      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final customArtDir = Directory('${appDir.path}/custom_artwork');
      if (!await customArtDir.exists()) {
        await customArtDir.create(recursive: true);
      }

      // Generate unique filename using hash of token identity
      final identityHash = md5.convert(utf8.encode(widget.tokenIdentity)).toString();
      final extension = croppedFile.path.split('.').last;
      final fileName = 'custom_$identityHash.$extension';
      final filePath = '${customArtDir.path}/$fileName';

      // Copy cropped image to app directory
      await File(croppedFile.path).copy(filePath);

      // Save preference with file:// protocol
      final fileUrl = 'file://$filePath';
      await _artworkPrefManager.setCustomArtwork(widget.tokenIdentity, fileUrl);

      // Clear any cached version of the new file path (defensive)
      final newFile = File(filePath);
      final newFileImage = FileImage(newFile);
      newFileImage.evict();

      // Notify parent
      if (mounted) {
        widget.onUploadComplete(fileUrl);
      }
    } catch (e) {
      // Silent failure - no user feedback needed
      debugPrint('Failed to upload custom artwork: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = _artworkPrefManager.hasCustomArtwork(widget.tokenIdentity);
    final customPath = _artworkPrefManager.getCustomArtworkPath(widget.tokenIdentity);

    // Check if custom file actually exists
    final customFile = customPath != null ? File(customPath.replaceFirst('file://', '')) : null;
    final customFileExists = customFile?.existsSync() ?? false;
    final showCustomThumbnail = hasCustom && customPath != null && customFileExists;

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail
          Expanded(
            child: Stack(
              children: [
                // Background container (always blue)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: showCustomThumbnail
                      ? Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              customFile!,
                              key: ValueKey(customFile!.path + customFile!.lastModifiedSync().toString()),
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.blue,
                          ),
                        ),
                ),

                // Edit icon overlay (State B only)
                if (showCustomThumbnail)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Checkmark overlay (if selected)
                if (widget.isSelected)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Label
          Text(
            showCustomThumbnail ? 'Custom' : 'Upload',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

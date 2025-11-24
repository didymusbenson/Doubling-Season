import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  const ArtworkSelectionSheet({
    super.key,
    required this.artworkVariants,
    required this.onArtworkSelected,
    this.onRemoveArtwork,
    this.currentArtworkUrl,
    this.currentArtworkSet,
    required this.tokenName,
    required this.tokenIdentity,
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

      // Show result feedback
      if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hadNetworkError
                  ? 'Downloaded $successCount/${successCount + failCount} images. Please check your internet connection.'
                  : 'Downloaded $successCount/${successCount + failCount} images. Some downloads failed.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully downloaded all artwork ($successCount images)'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        snapshot.data!,
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

                    // Content
                    if (widget.artworkVariants.isEmpty)
                      // No artwork available
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No token art available',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "This token doesn't have official\nartwork in the database.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    else
                      // Artwork options grid (Custom Artwork Feature: +1 for custom tile)
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
  final Function(String filePath) onUploadComplete;
  final VoidCallback? onRemoveArtwork; // Called when custom artwork is deleted

  const _CustomArtworkTile({
    required this.tokenIdentity,
    required this.isSelected,
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
          '• Artwork will be cropped to fit the card\n'
          '• Consider pre-cropping to portrait orientation\n\n'
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(customPath.replaceFirst('file://', '')),
                    height: 200,
                    fit: BoxFit.cover,
                  ),
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

        // Clear the currently selected artwork in the parent widget
        if (widget.onRemoveArtwork != null) {
          widget.onRemoveArtwork!();
        }

        // Update UI
        if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Custom artwork deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete artwork: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSaveImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      // Delete old custom artwork file if it exists
      final oldCustomPath = _artworkPrefManager.getCustomArtworkPath(widget.tokenIdentity);
      if (oldCustomPath != null) {
        final oldFile = File(oldCustomPath.replaceFirst('file://', ''));
        if (await oldFile.exists()) {
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
      final extension = image.path.split('.').last;
      final fileName = 'custom_$identityHash.$extension';
      final filePath = '${customArtDir.path}/$fileName';

      // Copy image to app directory
      await File(image.path).copy(filePath);

      // Save preference with file:// protocol
      final fileUrl = 'file://$filePath';
      await _artworkPrefManager.setCustomArtwork(widget.tokenIdentity, fileUrl);

      // Notify parent
      if (mounted) {
        widget.onUploadComplete(fileUrl);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom artwork uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload artwork: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: showCustomThumbnail
                      ? Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              customFile!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Theme.of(context).primaryColor,
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

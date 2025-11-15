import 'dart:io';
import 'package:flutter/material.dart';
import '../models/token_definition.dart';
import '../utils/artwork_manager.dart';

/// Bottom sheet for selecting token artwork from available variants
class ArtworkSelectionSheet extends StatelessWidget {
  final List<ArtworkVariant> artworkVariants;
  final Function(String url, String setCode) onArtworkSelected;
  final VoidCallback? onRemoveArtwork;
  final String? currentArtworkUrl;
  final String? currentArtworkSet;

  const ArtworkSelectionSheet({
    super.key,
    required this.artworkVariants,
    required this.onArtworkSelected,
    this.onRemoveArtwork,
    this.currentArtworkUrl,
    this.currentArtworkSet,
  });

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
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
                    if (currentArtworkUrl != null && onRemoveArtwork != null)
                      Container(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Thumbnail
                              FutureBuilder<File?>(
                                future: ArtworkManager.getCachedArtworkFile(currentArtworkUrl!),
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
                                      currentArtworkSet ?? 'Unknown Set',
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
                                  onRemoveArtwork!();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (currentArtworkUrl != null && onRemoveArtwork != null)
                      const Divider(height: 1),

                    // Content
                    if (artworkVariants.isEmpty)
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
                      // Artwork options
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: artworkVariants.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final variant = artworkVariants[index];
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

                              if (confirmed == true && context.mounted) {
                                Navigator.pop(context); // Close selection sheet
                                onArtworkSelected(variant.url, variant.set);
                              }
                            },
                          );
                        },
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

/// Individual artwork option in the list
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            FutureBuilder<File?>(
              future: ArtworkManager.getCachedArtworkFile(variant.url),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  // Show cached image
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
                  // Show loading placeholder
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

            // Set info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.set,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSetName(variant.set),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  /// Get full set name from set code
  /// TODO: Expand this with more complete set name mappings
  String _getSetName(String setCode) {
    const setNames = {
      'M15': 'Core Set 2015',
      'KLD': 'Kaladesh',
      'DOM': 'Dominaria',
      'ACR': 'Assassin\'s Creed',
      'MKM': 'Murders at Karlov Manor',
      'HOU': 'Hour of Devastation',
      'M3C': 'Modern Horizons 3 Commander',
      // Add more as needed
    };

    return setNames[setCode] ?? setCode;
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
                  return Container(
                    height: 300,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Failed to load image:\n${snapshot.error}'),
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
                    child: const Text('No image available'),
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Set info
            Text(
              '${_ArtworkOption(variant: variant, onTap: () {})._getSetName(variant.set)} — ${variant.set}',
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

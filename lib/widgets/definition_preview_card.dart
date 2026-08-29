import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gradient_borders/gradient_borders.dart';

import '../utils/artwork_manager.dart';
import '../utils/color_utils.dart';
import '../utils/constants.dart';
import 'common/background_text.dart';
import 'cropped_artwork_widget.dart';
import 'mana/mana_text.dart';

/// Shared artwork-backed definition row used by deckbuilding and token pickers.
class DefinitionPreviewCard extends StatelessWidget {
  final String? artworkUrl;
  final String colorIdentity;
  final String name;
  final String subtitle;
  final String? trailing;
  final IconData? leadingIcon;
  final Widget? endWidget;
  final bool selected;
  final bool showBorder;
  final VoidCallback? onTap;

  const DefinitionPreviewCard({
    super.key,
    this.artworkUrl,
    required this.colorIdentity,
    required this.name,
    required this.subtitle,
    this.trailing,
    this.leadingIcon,
    this.endWidget,
    this.selected = false,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const borderWidth = 3.0;
    final body = ClipRRect(
      borderRadius:
          BorderRadius.circular(UIConstants.borderRadius - borderWidth),
      child: Material(
        color: Theme.of(context).cardColor,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (artworkUrl != null && artworkUrl!.isNotEmpty)
                Positioned.fill(child: _Artwork(url: artworkUrl!)),
              if (selected)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.22),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            BackgroundText(
                              child: ManaText(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null)
                      BackgroundText(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(trailing!,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(Icons.check,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ],
                    if (endWidget != null) endWidget!,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!showBorder) return body;
    final gradient = ColorUtils.gradientForColors(colorIdentity);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        border: GradientBoxBorder(
          gradient: selected
              ? LinearGradient(colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary
                ])
              : gradient,
          width: selected ? 4 : borderWidth,
        ),
      ),
      child: body,
    );
  }
}

class _Artwork extends StatelessWidget {
  final String url;
  const _Artwork({required this.url});

  @override
  Widget build(BuildContext context) {
    final crop = ArtworkManager.getCropPercentages(url);
    if (kIsWeb) {
      return CroppedArtworkWidget(
        imageUrl: url,
        cropLeft: crop['left']!,
        cropRight: crop['right']!,
        cropTop: crop['top']!,
        cropBottom: crop['bottom']!,
      );
    }
    return FutureBuilder<File?>(
      future: _loadArtwork(),
      builder: (context, snapshot) => snapshot.data == null
          ? const SizedBox.shrink()
          : CroppedArtworkWidget(
              imageFile: snapshot.data!,
              cropLeft: crop['left']!,
              cropRight: crop['right']!,
              cropTop: crop['top']!,
              cropBottom: crop['bottom']!,
            ),
    );
  }

  Future<File?> _loadArtwork() async {
    final cached = await ArtworkManager.getCachedArtworkFile(url);
    return cached ?? await ArtworkManager.downloadArtwork(url);
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/toggle_widget.dart';
import '../providers/settings_provider.dart';
import '../providers/toggle_provider.dart';
import '../screens/expanded_widget_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/color_utils.dart';
import 'cropped_artwork_widget.dart';

class ToggleWidgetCard extends StatefulWidget {
  final ToggleWidget toggle;

  const ToggleWidgetCard({super.key, required this.toggle});

  @override
  State<ToggleWidgetCard> createState() => _ToggleWidgetCardState();
}

class _ToggleWidgetCardState extends State<ToggleWidgetCard> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  @override
  void didUpdateWidget(ToggleWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.toggle.artworkUrl != widget.toggle.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, String>(
      selector: (context, settings) => settings.artworkDisplayStyle,
      builder: (context, artworkDisplayStyle, child) {
        return GestureDetector(
          // Tap card body to open expanded view
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ExpandedWidgetScreen(
                  widget: widget.toggle,
                  isTracker: false,
                ),
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Base card background layer
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
                    ),
                  ),

                  // Gradient background layer
                  if (_getCurrentArtworkUrl() == null || _getCurrentArtworkUrl()!.isEmpty)
                    _buildGradientLayer(context)
                  else
                    _buildConditionalGradient(context),

                  // Artwork layer
                  if (_getCurrentArtworkUrl() != null)
                    _buildArtworkLayer(context, constraints, artworkDisplayStyle),

                  // Content layer
                  Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(UIConstants.cardPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side: Name and Description (takes remaining space)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Name
                              _buildTextWithBackground(
                                context: context,
                                child: Text(
                                  widget.toggle.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),

                              const SizedBox(height: UIConstants.mediumSpacing),

                              // Current description (ON or OFF)
                              _buildTextWithBackground(
                                context: context,
                                child: Text(
                                  widget.toggle.currentDescription,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: UIConstants.mediumSpacing),

                        // Right side: Toggle button (shrink-wraps)
                        _buildToggleButton(context),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToggleButton(BuildContext context) {
    final toggleProvider = context.read<ToggleProvider>();
    final activeColor = Colors.green;
    final inactiveColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return GestureDetector(
      onTap: () {
        widget.toggle.toggle();
        toggleProvider.updateToggle(widget.toggle);
      },
      child: _buildTextWithBackground(
        context: context,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          widget.toggle.isActive ? Icons.check_box : Icons.check_box_outline_blank,
          size: 48, // Large size to match tracker value emphasis
          color: widget.toggle.isActive ? activeColor : inactiveColor,
        ),
      ),
    );
  }

  String? _getCurrentArtworkUrl() {
    // Use state-specific artwork if available, otherwise fall back to general artwork
    return widget.toggle.currentArtworkUrl;
  }

  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.toggle.colorIdentity, isEmblem: false);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
        ),
      ),
    );
  }

  Widget _buildConditionalGradient(BuildContext context) {
    final artworkUrl = _getCurrentArtworkUrl();
    if (artworkUrl == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
            final gradient = ColorUtils.gradientForColors(widget.toggle.colorIdentity, isEmblem: false);
            return Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints, String artworkDisplayStyle) {
    final artworkUrl = _getCurrentArtworkUrl();
    if (artworkUrl == null) return const SizedBox.shrink();

    final crop = ArtworkManager.getCropPercentages(artworkUrl);

    if (artworkDisplayStyle == 'fadeout') {
      // Fadeout mode - right 50% only
      final cardWidth = constraints.maxWidth;
      final artworkWidth = cardWidth * 0.50;

      return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: artworkWidth,
        child: FutureBuilder<File?>(
          future: ArtworkManager.getCachedArtworkFile(artworkUrl),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
              final shouldAnimate = elapsed > 100 && !_artworkAnimated;

              if (shouldAnimate) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _artworkAnimated = true;
                    });
                  }
                });
              }

              return AnimatedOpacity(
                opacity: 1.0,
                duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
                curve: Curves.easeIn,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(UIConstants.smallBorderRadius),
                    bottomRight: Radius.circular(UIConstants.smallBorderRadius),
                  ),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
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
                ),
              );
            }

            // Cleanup logic
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.data == null &&
                !_artworkCleanupAttempted) {
              final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
              if (elapsed > 2000) {
                _artworkCleanupAttempted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    widget.toggle.artworkUrl = null;
                    widget.toggle.save();
                  }
                });
              }
            }

            return const SizedBox.shrink();
          },
        ),
      );
    } else {
      // Full view mode - fills entire card
      return Positioned.fill(
        child: FutureBuilder<File?>(
          future: ArtworkManager.getCachedArtworkFile(artworkUrl),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
              final shouldAnimate = elapsed > 100 && !_artworkAnimated;

              if (shouldAnimate) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _artworkAnimated = true;
                    });
                  }
                });
              }

              return AnimatedOpacity(
                opacity: 1.0,
                duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
                curve: Curves.easeIn,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
                  child: CroppedArtworkWidget(
                    imageFile: snapshot.data!,
                    cropLeft: crop['left']!,
                    cropRight: crop['right']!,
                    cropTop: crop['top']!,
                    cropBottom: crop['bottom']!,
                    fillWidth: true,
                  ),
                ),
              );
            }

            // Cleanup logic
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.data == null &&
                !_artworkCleanupAttempted) {
              final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
              if (elapsed > 2000) {
                _artworkCleanupAttempted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    widget.toggle.artworkUrl = null;
                    widget.toggle.save();
                  }
                });
              }
            }

            return const SizedBox.shrink();
          },
        ),
      );
    }
  }

  Widget _buildTextWithBackground({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

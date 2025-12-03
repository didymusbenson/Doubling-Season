import 'dart:io';
import 'package:flutter/foundation.dart';
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
          // Tap to toggle
          onTap: () {
            final toggleProvider = context.read<ToggleProvider>();
            widget.toggle.toggle();
            toggleProvider.updateToggle(widget.toggle);
          },
          // Long-press to open expanded view
          onLongPress: () {
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
                      borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextWithBackground(
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
                            ),
                            const SizedBox(width: UIConstants.mediumSpacing),
                            // State indicator
                            _buildTextWithBackground(
                              context: context,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Icon(
                                widget.toggle.isActive ? Icons.check_circle : Icons.circle_outlined,
                                size: UIConstants.iconSize,
                                color: widget.toggle.isActive
                                    ? Colors.green
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
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
                ],
              );
            },
          ),
        );
      },
    );
  }

  String? _getCurrentArtworkUrl() {
    // Use state-specific artwork if available, otherwise fall back to general artwork
    return widget.toggle.currentArtworkUrl;
  }

  Widget _buildGradientLayer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ColorUtils.gradientForColors(widget.toggle.colorIdentity, isEmblem: false),
        borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
      ),
    );
  }

  Widget _buildConditionalGradient(BuildContext context) {
    final artworkUrl = _getCurrentArtworkUrl();
    if (artworkUrl == null) return const SizedBox.shrink();

    return FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(artworkUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
          return _buildGradientLayer(context);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints, String artworkDisplayStyle) {
    final artworkUrl = _getCurrentArtworkUrl();
    if (artworkUrl == null) return const SizedBox.shrink();

    return FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(artworkUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == null) {
            // Cleanup: Remove invalid artwork URL
            if (!_artworkCleanupAttempted) {
              _artworkCleanupAttempted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.toggle.artworkUrl = null;
                widget.toggle.save();
              });
            }
            return const SizedBox.shrink();
          }

          // Determine if artwork loaded quickly (cached) or slowly (network)
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          final shouldAnimate = elapsed > 100 && !_artworkAnimated;

          if (shouldAnimate) {
            _artworkAnimated = true;
          }

          final artworkWidget = CroppedArtworkWidget(
            imageFile: snapshot.data!,
            cropLeft: 0.088,
            cropRight: 0.088,
            cropTop: 0.145,
            cropBottom: 0.368,
            fillWidth: artworkDisplayStyle == 'fullView',
          );

          if (artworkDisplayStyle == 'fadeout') {
            return ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.white],
                  stops: [0.0, 0.50],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: shouldAnimate
                  ? AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: artworkWidget,
                    )
                  : artworkWidget,
            );
          } else {
            return shouldAnimate
                ? AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: artworkWidget,
                  )
                : artworkWidget;
          }
        }

        return const SizedBox.shrink();
      },
    );
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

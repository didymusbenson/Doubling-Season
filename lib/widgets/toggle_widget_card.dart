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
import 'common/background_text.dart';
// Unused import was causing build warnings
// import 'cropped_artwork_widget.dart';
import 'mixins/artwork_display_mixin.dart';

class ToggleWidgetCard extends StatefulWidget {
  final ToggleWidget toggle;

  const ToggleWidgetCard({super.key, required this.toggle});

  @override
  State<ToggleWidgetCard> createState() => _ToggleWidgetCardState();
}

class _ToggleWidgetCardState extends State<ToggleWidgetCard> with ArtworkDisplayMixin {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  // Implement ArtworkDisplayMixin interface
  @override
  DateTime get createdAt => _createdAt;

  @override
  bool get artworkAnimated => _artworkAnimated;

  @override
  set artworkAnimated(bool value) => _artworkAnimated = value;

  @override
  bool get artworkCleanupAttempted => _artworkCleanupAttempted;

  @override
  set artworkCleanupAttempted(bool value) => _artworkCleanupAttempted = value;

  @override
  String? get artworkUrl => widget.toggle.currentArtworkUrl;

  @override
  void clearArtwork() {
    widget.toggle.artworkUrl = null;
    widget.toggle.artworkSet = null;
    widget.toggle.artworkOptions = null;
    widget.toggle.save();
    // FUTURE: When state-specific artwork is implemented, also clear:
    // widget.toggle.onArtworkUrl = null;
    // widget.toggle.offArtworkUrl = null;
  }

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
          child: Opacity(
            opacity: 1.0, // Full opacity (matching TokenCard pattern for consistent swipe behavior)
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                children: [
                  // Base card background layer (transparent to allow red swipe indicator through)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
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
                    buildArtworkLayer(
                      context: context,
                      constraints: constraints,
                      artworkDisplayStyle: artworkDisplayStyle,
                    ),

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
                              BackgroundText(
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
                              BackgroundText(
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
          ), // Opacity
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
      child: BackgroundText(
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
}

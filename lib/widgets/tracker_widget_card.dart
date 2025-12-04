import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracker_widget.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';
import '../screens/expanded_widget_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/color_utils.dart';
import 'cropped_artwork_widget.dart';

class TrackerWidgetCard extends StatefulWidget {
  final TrackerWidget tracker;

  const TrackerWidgetCard({super.key, required this.tracker});

  @override
  State<TrackerWidgetCard> createState() => _TrackerWidgetCardState();
}

class _TrackerWidgetCardState extends State<TrackerWidgetCard> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;
  Future<File?>? _cachedArtworkFuture;
  String? _cachedArtworkUrl;

  @override
  void didUpdateWidget(TrackerWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.tracker.artworkUrl != widget.tracker.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }

  Future<File?> _getArtworkFuture(String artworkUrl) {
    // Cache the future only if URL hasn't changed
    if (_cachedArtworkUrl != artworkUrl || _cachedArtworkFuture == null) {
      _cachedArtworkUrl = artworkUrl;
      _cachedArtworkFuture = ArtworkManager.getCachedArtworkFile(artworkUrl);
    }
    return _cachedArtworkFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, String>(
      selector: (context, settings) => settings.artworkDisplayStyle,
      builder: (context, artworkDisplayStyle, child) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ExpandedWidgetScreen(
                  widget: widget.tracker,
                  isTracker: true,
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
                  if (widget.tracker.artworkUrl == null || widget.tracker.artworkUrl!.isEmpty)
                    _buildGradientLayer(context)
                  else
                    _buildConditionalGradient(context),

                  // Artwork layer
                  if (widget.tracker.artworkUrl != null)
                    _buildArtworkLayer(context, constraints, artworkDisplayStyle),

                  // Content layer
                  Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(UIConstants.cardPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side: Name, Description, Buttons (takes remaining space)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Name
                              _buildTextWithBackground(
                                context: context,
                                child: Text(
                                  widget.tracker.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),

                              // Description (if present)
                              if (widget.tracker.description.isNotEmpty) ...[
                                const SizedBox(height: UIConstants.mediumSpacing),
                                _buildTextWithBackground(
                                  context: context,
                                  child: Text(
                                    widget.tracker.description,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                ),
                              ],

                              const SizedBox(height: UIConstants.mediumSpacing),

                              // Button Row (left-aligned)
                              _buildActionButtons(context),
                            ],
                          ),
                        ),

                        const SizedBox(width: UIConstants.mediumSpacing),

                        // Right side: Value display (shrink-wraps)
                        _buildValueDisplay(context),
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

  Widget _buildActionButtons(BuildContext context) {
    final trackerProvider = context.read<TrackerProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    const int buttonCount = 2; // Decrement, Increment

    return LayoutBuilder(
      builder: (context, constraints) {
        const double buttonInternalWidth = UIConstants.actionButtonInternalWidth;
        const double totalButtonWidth = buttonCount * buttonInternalWidth;
        final double availableSpacingWidth = constraints.maxWidth - totalButtonWidth;
        final double spacing = (availableSpacingWidth / (buttonCount - 1)).clamp(
          UIConstants.minButtonSpacing,
          UIConstants.maxButtonSpacing,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Decrement button
            _buildActionButton(
              context,
              icon: Icons.remove,
              onTap: () {
                widget.tracker.decrement(widget.tracker.tapIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              onLongPress: () {
                widget.tracker.decrement(widget.tracker.longPressIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              color: primaryColor,
              spacing: spacing,
            ),

            // Increment button
            _buildActionButton(
              context,
              icon: Icons.add,
              onTap: () {
                widget.tracker.increment(widget.tracker.tapIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              onLongPress: () {
                widget.tracker.increment(widget.tracker.longPressIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              color: primaryColor,
              spacing: 0, // Last button gets no spacing
            ),
          ],
        );
      },
    );
  }

  Widget _buildValueDisplay(BuildContext context) {
    // Big number display - takes full vertical space
    return GestureDetector(
      onTap: () => _showValueEditDialog(context),
      child: _buildTextWithBackground(
        context: context,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '${widget.tracker.currentValue}',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showValueEditDialog(BuildContext context) {
    final trackerProvider = context.read<TrackerProvider>();
    final controller = TextEditingController(text: '${widget.tracker.currentValue}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${widget.tracker.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final newValue = int.tryParse(value) ?? widget.tracker.currentValue;
            widget.tracker.currentValue = newValue.clamp(0, double.maxFinite.toInt());
            trackerProvider.updateTracker(widget.tracker);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? widget.tracker.currentValue;
              widget.tracker.currentValue = newValue.clamp(0, double.maxFinite.toInt());
              trackerProvider.updateTracker(widget.tracker);
              Navigator.of(context).pop();
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color color,
    required double spacing,
  }) {
    final buttonBackgroundColor = Theme.of(context).cardColor.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(UIConstants.actionButtonPadding),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius: BorderRadius.circular(UIConstants.actionButtonBorderRadius),
            border: Border.all(
              color: color,
              width: UIConstants.actionButtonBorderWidth,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: UIConstants.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.tracker.colorIdentity, isEmblem: false);

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
    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: _getArtworkFuture(widget.tracker.artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
            final gradient = ColorUtils.gradientForColors(widget.tracker.colorIdentity, isEmblem: false);
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
    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: _getArtworkFuture(widget.tracker.artworkUrl!),
        builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == null) {
            // Cleanup: Remove invalid artwork URL (with 2-second delay to prevent interference with drag/upload operations)
            if (!_artworkCleanupAttempted) {
              _artworkCleanupAttempted = true;
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  widget.tracker.artworkUrl = null;
                  widget.tracker.save();
                }
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
      ),
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

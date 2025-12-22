import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/artwork_manager.dart';
import '../../utils/constants.dart';
import '../cropped_artwork_widget.dart';

/// Mixin providing shared artwork display logic for all card types.
///
/// This follows the TokenCard pattern (gold standard) with separate methods
/// for full view and fadeout modes.
///
/// Card types that display artwork (TokenCard, TrackerWidgetCard, ToggleWidgetCard)
/// should use this mixin to avoid duplicating the artwork layer implementation.
///
/// Required state variables in the widget class:
/// ```dart
/// final DateTime _createdAt = DateTime.now();
/// bool _artworkAnimated = false;
/// bool _artworkCleanupAttempted = false;
/// ```
///
/// Required getters/setters to implement:
/// ```dart
/// DateTime get createdAt => _createdAt;
/// bool get artworkAnimated => _artworkAnimated;
/// set artworkAnimated(bool value) => _artworkAnimated = value;
/// bool get artworkCleanupAttempted => _artworkCleanupAttempted;
/// set artworkCleanupAttempted(bool value) => _artworkCleanupAttempted = value;
/// String? get artworkUrl;  // For TokenCard: widget.item.artworkUrl
///                          // For TrackerWidget: widget.tracker.artworkUrl
///                          // For ToggleWidget: widget.toggle.currentArtworkUrl
///                          //   NOTE: currentArtworkUrl is scaffolded for state-specific
///                          //   artwork but not implemented - always returns artworkUrl
/// void clearArtwork();     // Clear artworkUrl, artworkSet, artworkOptions, save()
/// ```
mixin ArtworkDisplayMixin<T extends StatefulWidget> on State<T> {
  // Subclasses must provide these
  DateTime get createdAt;
  bool get artworkAnimated;
  set artworkAnimated(bool value);
  bool get artworkCleanupAttempted;
  set artworkCleanupAttempted(bool value);
  String? get artworkUrl;
  void clearArtwork();

  /// Main artwork layer builder - delegates to specific mode methods.
  ///
  /// This is the entry point called from the card's build() method.
  Widget buildArtworkLayer({
    required BuildContext context,
    required BoxConstraints constraints,
    required String artworkDisplayStyle,
  }) {
    if (artworkDisplayStyle == 'fadeout') {
      return buildFadeoutArtwork(context, constraints);
    } else {
      return buildFullViewArtwork(context, constraints);
    }
  }

  /// Build full-width artwork background layer (fills entire card).
  Widget buildFullViewArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages(artworkUrl);

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Determine if artwork should animate
            // If it appears > 100ms after card creation = downloaded (animate)
            // If it appears < 100ms after card creation = cached (no animation)
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            final shouldAnimate = elapsed > UIConstants.artworkAnimationThreshold && !artworkAnimated;

            if (shouldAnimate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    artworkAnimated = true;
                  });
                }
              });
            }

            return AnimatedOpacity(
              opacity: 1.0,
              duration: shouldAnimate ? UIConstants.artworkFadeInDuration : Duration.zero,
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

          // If artwork file is missing, clear the invalid reference
          // BUT: Only do this if widget has been stable for >2 seconds to avoid cleanup during drag/scroll
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !artworkCleanupAttempted) {
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            if (elapsed > UIConstants.artworkCleanupDelay) {
              artworkCleanupAttempted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  clearArtwork();
                }
              });
            }
          }

          // Show empty background while loading or if file missing
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build fadeout artwork layer (right-side 50% with gradient fade).
  Widget buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages(artworkUrl);
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * UIConstants.artworkFadeoutWidthPercent;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: artworkWidth,
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Same animation logic as full view
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            final shouldAnimate = elapsed > UIConstants.artworkAnimationThreshold && !artworkAnimated;

            if (shouldAnimate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    artworkAnimated = true;
                  });
                }
              });
            }

            return AnimatedOpacity(
              opacity: 1.0,
              duration: shouldAnimate ? UIConstants.artworkFadeInDuration : Duration.zero,
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(UIConstants.smallBorderRadius),
                  bottomRight: Radius.circular(UIConstants.smallBorderRadius),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) {
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

          // If artwork file is missing, clear the invalid reference
          // BUT: Only do this if widget has been stable for >2 seconds to avoid cleanup during drag/scroll
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !artworkCleanupAttempted) {
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            if (elapsed > UIConstants.artworkCleanupDelay) {
              artworkCleanupAttempted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  clearArtwork();
                }
              });
            }
          }

          // Show empty background while loading or if file missing
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

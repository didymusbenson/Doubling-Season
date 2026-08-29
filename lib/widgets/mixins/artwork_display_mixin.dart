import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final Map<String, Future<ArtworkRenderSource>> _expandedSourceFutures = {};
  final Map<String, Future<File?>> _expandedFileFutures = {};

  // Subclasses must provide these
  DateTime get createdAt;
  bool get artworkAnimated;
  set artworkAnimated(bool value);
  bool get artworkCleanupAttempted;
  set artworkCleanupAttempted(bool value);
  String? get artworkUrl;
  void clearArtwork();

  Future<ArtworkRenderSource> _expandedSourceFuture(
    String canonicalUrl,
    ExpandedArtworkRenderer renderer,
  ) {
    final key = '${renderer.name}|$canonicalUrl';
    return _expandedSourceFutures.putIfAbsent(
      key,
      () => ArtworkManager.resolveExpandedRenderSource(
        canonicalUrl,
        renderer: renderer,
      ),
    );
  }

  Future<File?> _expandedFileFuture(String url) =>
      _expandedFileFutures.putIfAbsent(
        url,
        () => ArtworkManager.getCachedArtworkFile(url),
      );

  /// Try to re-download a missing artwork file. If download fails, clear the reference.
  void _redownloadOrClear(String url) {
    // Custom artwork (file://) can't be re-downloaded — clear immediately
    if (url.startsWith('file://')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clearArtwork();
      });
      return;
    }

    ArtworkManager.downloadArtwork(url).then((file) {
      if (!mounted) return;
      if (file != null) {
        // Download succeeded — rebuild to show artwork
        setState(() {});
      } else {
        // Download failed — URL is genuinely broken, clear it
        clearArtwork();
      }
    });
  }

  /// Main artwork layer builder - delegates to specific mode methods.
  ///
  /// This is the entry point called from the card's build() method.
  Widget buildArtworkLayer({
    required BuildContext context,
    required BoxConstraints constraints,
    required String artworkDisplayStyle,
    bool isExpanded = false,
    double? revealViewportHeight,
    double cornerRadius = UIConstants.borderRadius - 3.0,
    ExpandedArtworkRenderer expandedRenderer =
        ArtworkManager.expandedArtworkRenderer,
  }) {
    if (isExpanded) {
      return buildExpandedArtwork(
        context,
        constraints,
        renderer: expandedRenderer,
        cornerRadius: cornerRadius,
      );
    }
    if (artworkDisplayStyle == 'fadeout') {
      return buildFadeoutArtwork(
        context,
        constraints,
        cornerRadius: cornerRadius,
        revealViewportHeight: revealViewportHeight,
      );
    } else {
      return buildFullViewArtwork(
        context,
        constraints,
        cornerRadius: cornerRadius,
        revealViewportHeight: revealViewportHeight,
      );
    }
  }

  /// Builds only the expanded artwork overlay.
  ///
  /// Callers keep their compact artwork renderer mounted underneath this layer
  /// so its decoded image remains visible until the expanded source is ready.
  Widget buildExpandedArtwork(
    BuildContext context,
    BoxConstraints constraints, {
    ExpandedArtworkRenderer renderer = ArtworkManager.expandedArtworkRenderer,
    double cornerRadius = UIConstants.borderRadius - 3.0,
  }) {
    final canonicalUrl = artworkUrl!;

    if (kIsWeb) {
      if (canonicalUrl.startsWith('file://')) return const SizedBox.shrink();
      final source = ArtworkManager.expandedRenderSource(
        canonicalUrl,
        renderer: renderer,
      );
      final crop = source.useCanonicalCrop
          ? ArtworkManager.getCropPercentages(canonicalUrl)
          : ArtworkManager.getCropPercentages('file://derived-art-crop');
      final canonicalCrop = ArtworkManager.getCropPercentages(canonicalUrl);
      return Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: CroppedArtworkWidget(
            imageUrl: source.url,
            fallbackImageUrl: source.useCanonicalCrop ? null : canonicalUrl,
            fallbackCropLeft: canonicalCrop['left'],
            fallbackCropRight: canonicalCrop['right'],
            fallbackCropTop: canonicalCrop['top'],
            fallbackCropBottom: canonicalCrop['bottom'],
            cropLeft: crop['left']!,
            cropRight: crop['right']!,
            cropTop: crop['top']!,
            cropBottom: crop['bottom']!,
            fillWidth: true,
            fadeIn: true,
          ),
        ),
      );
    }

    return Positioned.fill(
      child: FutureBuilder<ArtworkRenderSource>(
        future: _expandedSourceFuture(canonicalUrl, renderer),
        builder: (context, sourceSnapshot) {
          final source = sourceSnapshot.data;
          if (source == null) return const SizedBox.shrink();
          return FutureBuilder<File?>(
            future: _expandedFileFuture(source.url),
            builder: (context, fileSnapshot) {
              final file = fileSnapshot.data;
              if (file == null) return const SizedBox.shrink();
              final crop = source.useCanonicalCrop
                  ? ArtworkManager.getCropPercentages(canonicalUrl)
                  : ArtworkManager.getCropPercentages(
                      'file://derived-art-crop',
                    );
              return ClipRRect(
                borderRadius: BorderRadius.circular(cornerRadius),
                child: CroppedArtworkWidget(
                  imageFile: file,
                  cropLeft: crop['left']!,
                  cropRight: crop['right']!,
                  cropTop: crop['top']!,
                  cropBottom: crop['bottom']!,
                  fillWidth: true,
                  fadeIn: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Build the CroppedArtworkWidget with the appropriate source (file or URL).
  CroppedArtworkWidget _buildCroppedWidget({
    File? file,
    required Map<String, double> crop,
    required bool fillWidth,
    double? revealViewportHeight,
  }) {
    if (kIsWeb) {
      // Web: skip file:// URLs (custom artwork not supported on web)
      final url = artworkUrl;
      if (url == null || url.startsWith('file://')) {
        return CroppedArtworkWidget(
          imageUrl: '', // Will fail gracefully
          cropLeft: crop['left']!,
          cropRight: crop['right']!,
          cropTop: crop['top']!,
          cropBottom: crop['bottom']!,
          fillWidth: fillWidth,
          layoutHeight: revealViewportHeight,
        );
      }
      return CroppedArtworkWidget(
        imageUrl: url,
        cropLeft: crop['left']!,
        cropRight: crop['right']!,
        cropTop: crop['top']!,
        cropBottom: crop['bottom']!,
        fillWidth: fillWidth,
        layoutHeight: revealViewportHeight,
      );
    }
    return CroppedArtworkWidget(
      imageFile: file,
      cropLeft: crop['left']!,
      cropRight: crop['right']!,
      cropTop: crop['top']!,
      cropBottom: crop['bottom']!,
      fillWidth: fillWidth,
      layoutHeight: revealViewportHeight,
    );
  }

  /// Build full-width artwork background layer (fills entire card).
  Widget buildFullViewArtwork(
    BuildContext context,
    BoxConstraints constraints, {
    double cornerRadius = UIConstants.borderRadius - 3.0,
    double? revealViewportHeight,
  }) {
    final crop = ArtworkManager.getCropPercentages(artworkUrl);

    // Web: render directly from URL (no local file cache)
    if (kIsWeb) {
      // Skip custom artwork (file:// URLs) on web
      if (artworkUrl!.startsWith('file://')) return const SizedBox.shrink();

      return Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: _buildCroppedWidget(
            crop: crop,
            fillWidth: true,
            revealViewportHeight: revealViewportHeight,
          ),
        ),
      );
    }

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Determine if artwork should animate
            // If it appears > 100ms after card creation = downloaded (animate)
            // If it appears < 100ms after card creation = cached (no animation)
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            final shouldAnimate =
                elapsed > UIConstants.artworkAnimationThreshold &&
                    !artworkAnimated;

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
              duration: shouldAnimate
                  ? UIConstants.artworkFadeInDuration
                  : Duration.zero,
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cornerRadius),
                child: _buildCroppedWidget(
                  file: snapshot.data!,
                  crop: crop,
                  fillWidth: true,
                  revealViewportHeight: revealViewportHeight,
                ),
              ),
            );
          }

          // Artwork file missing — try re-downloading before giving up
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !artworkCleanupAttempted) {
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            if (elapsed > UIConstants.artworkCleanupDelay) {
              artworkCleanupAttempted = true;
              _redownloadOrClear(artworkUrl!);
            }
          }

          // Show empty background while loading or if file missing
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build fadeout artwork layer (right-side 50% with gradient fade).
  Widget buildFadeoutArtwork(
    BuildContext context,
    BoxConstraints constraints, {
    double cornerRadius = UIConstants.smallBorderRadius,
    double? revealViewportHeight,
  }) {
    final crop = ArtworkManager.getCropPercentages(artworkUrl);
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * UIConstants.artworkFadeoutWidthPercent;

    // Web: render directly from URL (no local file cache)
    if (kIsWeb) {
      // Skip custom artwork (file:// URLs) on web
      if (artworkUrl!.startsWith('file://')) return const SizedBox.shrink();

      return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: artworkWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(cornerRadius),
            bottomRight: Radius.circular(cornerRadius),
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
            child: _buildCroppedWidget(
              crop: crop,
              fillWidth: false,
              revealViewportHeight: revealViewportHeight,
            ),
          ),
        ),
      );
    }

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
            final shouldAnimate =
                elapsed > UIConstants.artworkAnimationThreshold &&
                    !artworkAnimated;

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
              duration: shouldAnimate
                  ? UIConstants.artworkFadeInDuration
                  : Duration.zero,
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(cornerRadius),
                  bottomRight: Radius.circular(cornerRadius),
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
                  child: _buildCroppedWidget(
                    file: snapshot.data!,
                    crop: crop,
                    fillWidth: false,
                    revealViewportHeight: revealViewportHeight,
                  ),
                ),
              ),
            );
          }

          // Artwork file missing — try re-downloading before giving up
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !artworkCleanupAttempted) {
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            if (elapsed > UIConstants.artworkCleanupDelay) {
              artworkCleanupAttempted = true;
              _redownloadOrClear(artworkUrl!);
            }
          }

          // Show empty background while loading or if file missing
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

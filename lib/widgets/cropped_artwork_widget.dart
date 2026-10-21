import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Widget that displays cropped artwork based on image-relative crop percentages.
///
/// Supports two sources:
/// - [imageFile]: Load from a local File (mobile/desktop)
/// - [imageUrl]: Load from a network URL (web, or as fallback)
///
/// Provide exactly one of [imageFile] or [imageUrl].
class CroppedArtworkWidget extends StatefulWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final double? fallbackCropLeft;
  final double? fallbackCropRight;
  final double? fallbackCropTop;
  final double? fallbackCropBottom;
  final double cropLeft;
  final double cropRight;
  final double cropTop;
  final double cropBottom;
  final bool fillWidth;
  final bool fadeIn;
  final double? layoutHeight;
  final Animation<double>? verticalCenterProgress;

  const CroppedArtworkWidget({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.fallbackImageUrl,
    this.fallbackCropLeft,
    this.fallbackCropRight,
    this.fallbackCropTop,
    this.fallbackCropBottom,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    this.fillWidth = true,
    this.fadeIn = false,
    this.layoutHeight,
    this.verticalCenterProgress,
  }) : assert(imageFile != null || imageUrl != null,
            'Either imageFile or imageUrl must be provided');

  @override
  State<CroppedArtworkWidget> createState() => _CroppedArtworkWidgetState();
}

class _CroppedArtworkWidgetState extends State<CroppedArtworkWidget>
    with SingleTickerProviderStateMixin {
  static const int _maxDecodedWidth = 768;
  ImageInfo? _cachedImageInfo;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  /// Cache key: file path or URL string
  String? _cachedSource;
  bool _isLoading = false;
  bool _usingFallback = false;
  int _loadGeneration = 0;
  late final AnimationController _fadeController;

  String? get _primarySource => widget.imageFile?.path ?? widget.imageUrl;

  String? get _activeSource =>
      _usingFallback ? widget.fallbackImageUrl : _primarySource;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: widget.fadeIn ? 0 : 1,
    );
    _loadImageIfNeeded();
  }

  @override
  void didUpdateWidget(CroppedArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSource = oldWidget.imageFile?.path ?? oldWidget.imageUrl;
    if (oldSource != _primarySource ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _usingFallback = false;
      _isLoading = false;
      _stopListening();
      _cachedImageInfo?.dispose();
      _cachedImageInfo = null;
      _cachedSource = null;
      _fadeController.value = widget.fadeIn ? 0 : 1;
      _loadImageIfNeeded();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _stopListening();
    _cachedImageInfo?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _stopListening() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _loadImageIfNeeded() {
    final source = _activeSource;
    if (_isLoading || (_cachedImageInfo != null && _cachedSource == source)) {
      return;
    }

    final generation = ++_loadGeneration;
    _isLoading = true;
    final provider = _providerFor(source);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((imageInfo, _) {
      stream.removeListener(listener);
      if (!mounted || generation != _loadGeneration) {
        imageInfo.dispose();
        return;
      }
      _imageStream = null;
      _imageStreamListener = null;
      setState(() {
        _cachedImageInfo?.dispose();
        _cachedImageInfo = imageInfo;
        _cachedSource = source;
        _isLoading = false;
      });
      if (widget.fadeIn) {
        _fadeController.forward(from: 0);
      } else {
        _fadeController.value = 1;
      }
    }, onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!mounted || generation != _loadGeneration) return;
      _imageStream = null;
      _imageStreamListener = null;
      if (!_usingFallback && widget.fallbackImageUrl != null) {
        _usingFallback = true;
        _isLoading = false;
        _loadImageIfNeeded();
        return;
      }
      if (kDebugMode) {
        debugPrint('CroppedArtworkWidget: Failed to load image: $error');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  ImageProvider<Object> _providerFor(String? source) {
    if (source == null) throw StateError('No image source available');

    final ImageProvider<Object> provider;
    if (!_usingFallback && widget.imageFile != null && !kIsWeb) {
      provider = FileImage(widget.imageFile!);
    } else {
      provider = NetworkImage(source);
    }

    // ResizeImage participates in Flutter's global ImageCache. Identical card
    // artwork now shares a pending decode and decoded image instead of every
    // CroppedArtworkWidget reading and decoding the file independently. The
    // cap also protects boards containing legacy full-resolution custom art.
    return ResizeImage.resizeIfNeeded(_maxDecodedWidth, null, provider);
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedImageInfo != null) {
      return FadeTransition(
        opacity: _fadeController,
        child: CustomPaint(
          painter: _CroppedArtworkPainter(
            image: _cachedImageInfo!.image,
            cropLeft: _usingFallback
                ? widget.fallbackCropLeft ?? widget.cropLeft
                : widget.cropLeft,
            cropRight: _usingFallback
                ? widget.fallbackCropRight ?? widget.cropRight
                : widget.cropRight,
            cropTop: _usingFallback
                ? widget.fallbackCropTop ?? widget.cropTop
                : widget.cropTop,
            cropBottom: _usingFallback
                ? widget.fallbackCropBottom ?? widget.cropBottom
                : widget.cropBottom,
            fillWidth: widget.fillWidth,
            layoutHeight: widget.layoutHeight,
            verticalCenterProgress: widget.verticalCenterProgress,
          ),
          size: Size.infinite,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CroppedArtworkPainter extends CustomPainter {
  final ui.Image image;
  final double cropLeft;
  final double cropRight;
  final double cropTop;
  final double cropBottom;
  final bool fillWidth;
  final double? layoutHeight;
  final Animation<double>? verticalCenterProgress;

  _CroppedArtworkPainter({
    required this.image,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    required this.fillWidth,
    this.layoutHeight,
    this.verticalCenterProgress,
  }) : super(repaint: verticalCenterProgress);

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the cropped region in image coordinates
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    // Source rect: the portion of the image we want to show (after cropping)
    final srcLeft = imageWidth * cropLeft;
    final srcTop = imageHeight * cropTop;
    final srcRight = imageWidth * (1 - cropRight);
    final srcBottom = imageHeight * (1 - cropBottom);

    final srcRect = Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);

    // Calculate cropped image dimensions
    final croppedWidth = srcRect.width;
    final croppedHeight = srcRect.height;

    // Calculate destination rect based on fillWidth parameter
    final Rect dstRect;
    final stableHeight = layoutHeight ?? size.height;
    if (fillWidth) {
      // FULL VIEW: Keep the width-derived scale stable, but center the
      // resulting image in the live viewport. AnimatedSize can therefore
      // reveal more artwork while the image translates smoothly to remain
      // centered instead of leaving the expansion entirely below it.
      final scaleToFillWidth = size.width / croppedWidth;
      final scaledHeight = croppedHeight * scaleToFillWidth;
      final progress = verticalCenterProgress?.value ?? 1;
      final centerHeight = layoutHeight == null
          ? size.height
          : ui.lerpDouble(layoutHeight, size.height, progress)!;
      final dstTop = (centerHeight - scaledHeight) / 2;
      dstRect = Rect.fromLTWH(0, dstTop, size.width, scaledHeight);
    } else {
      // FADEOUT: Fill height, ensure minimum width fills container
      final scaleToFillHeight = stableHeight / croppedHeight;
      final scaledWidth = croppedWidth * scaleToFillHeight;

      if (scaledWidth < size.width) {
        // Image is too narrow - rescale to fill width, may overflow vertically
        final scaleToFillWidth = size.width / croppedWidth;
        final rescaledHeight = croppedHeight * scaleToFillWidth;
        final dstTop = (stableHeight - rescaledHeight) / 2;
        dstRect = Rect.fromLTWH(0, dstTop, size.width, rescaledHeight);
      } else {
        // Image is wide enough - use height-based scaling, overflow left
        final dstLeft =
            size.width - scaledWidth; // Will be negative if overflow
        dstRect = Rect.fromLTWH(dstLeft, 0, scaledWidth, stableHeight);
      }
    }

    // Clip to canvas bounds to hide overflow
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw the cropped portion of the image, scaled to fill width
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CroppedArtworkPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.cropLeft != cropLeft ||
        oldDelegate.cropRight != cropRight ||
        oldDelegate.cropTop != cropTop ||
        oldDelegate.cropBottom != cropBottom ||
        oldDelegate.fillWidth != fillWidth ||
        oldDelegate.layoutHeight != layoutHeight;
  }
}

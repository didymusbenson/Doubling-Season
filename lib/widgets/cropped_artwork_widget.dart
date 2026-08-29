import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  }) : assert(imageFile != null || imageUrl != null,
            'Either imageFile or imageUrl must be provided');

  @override
  State<CroppedArtworkWidget> createState() => _CroppedArtworkWidgetState();
}

class _CroppedArtworkWidgetState extends State<CroppedArtworkWidget>
    with SingleTickerProviderStateMixin {
  ui.Image? _cachedImage;

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
      _cachedImage?.dispose();
      _cachedImage = null;
      _cachedSource = null;
      _fadeController.value = widget.fadeIn ? 0 : 1;
      _loadImageIfNeeded();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _cachedImage?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadImageIfNeeded() {
    final source = _activeSource;
    if (_isLoading || (_cachedImage != null && _cachedSource == source)) {
      return;
    }

    final generation = ++_loadGeneration;
    _isLoading = true;
    _loadImage(source).then((image) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _cachedImage?.dispose();
          _cachedImage = image;
          _cachedSource = source;
          _isLoading = false;
        });
        if (widget.fadeIn) {
          _fadeController.forward(from: 0);
        } else {
          _fadeController.value = 1;
        }
      } else {
        image.dispose();
      }
    }).catchError((error) {
      if (!mounted || generation != _loadGeneration) return;
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
  }

  Future<ui.Image> _loadImage(String? source) async {
    final Uint8List bytes;

    if (widget.imageFile != null && !kIsWeb) {
      bytes = await widget.imageFile!.readAsBytes();
    } else if (source != null) {
      final response = await http.get(Uri.parse(source));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image: HTTP ${response.statusCode}');
      }
      bytes = response.bodyBytes;
    } else {
      throw StateError('No image source available');
    }

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedImage != null) {
      return FadeTransition(
        opacity: _fadeController,
        child: CustomPaint(
          painter: _CroppedArtworkPainter(
            image: _cachedImage!,
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

  _CroppedArtworkPainter({
    required this.image,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    required this.fillWidth,
    this.layoutHeight,
  });

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
      // FULL VIEW: Fill width, crop height
      final scaleToFillWidth = size.width / croppedWidth;
      final scaledHeight = croppedHeight * scaleToFillWidth;
      final dstTop = (stableHeight - scaledHeight) / 2;
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

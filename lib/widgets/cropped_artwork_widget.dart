import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Widget that displays cropped artwork based on image-relative crop percentages
class CroppedArtworkWidget extends StatelessWidget {
  final File imageFile;
  final double cropLeft;
  final double cropRight;
  final double cropTop;
  final double cropBottom;
  final bool fillWidth;

  const CroppedArtworkWidget({
    super.key,
    required this.imageFile,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    this.fillWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _loadImage(imageFile),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CustomPaint(
            painter: _CroppedArtworkPainter(
              image: snapshot.data!,
              cropLeft: cropLeft,
              cropRight: cropRight,
              cropTop: cropTop,
              cropBottom: cropBottom,
              fillWidth: fillWidth,
            ),
            size: Size.infinite,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<ui.Image> _loadImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _CroppedArtworkPainter extends CustomPainter {
  final ui.Image image;
  final double cropLeft;
  final double cropRight;
  final double cropTop;
  final double cropBottom;
  final bool fillWidth;

  _CroppedArtworkPainter({
    required this.image,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    required this.fillWidth,
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
    if (fillWidth) {
      // FULL VIEW: Fill width, crop height
      final scaleToFillWidth = size.width / croppedWidth;
      final scaledHeight = croppedHeight * scaleToFillWidth;
      final dstTop = (size.height - scaledHeight) / 2;
      dstRect = Rect.fromLTWH(0, dstTop, size.width, scaledHeight);
    } else {
      // FADEOUT: Fill height, crop width, align right
      final scaleToFillHeight = size.height / croppedHeight;
      final scaledWidth = croppedWidth * scaleToFillHeight;
      final dstLeft = size.width - scaledWidth; // Align to right edge
      dstRect = Rect.fromLTWH(dstLeft, 0, scaledWidth, size.height);
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
        oldDelegate.fillWidth != fillWidth;
  }
}

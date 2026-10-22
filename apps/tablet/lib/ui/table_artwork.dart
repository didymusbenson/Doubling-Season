import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:doubling_season/utils/artwork_manager.dart';
import '../services/tablet_media_store.dart';

class TableArtwork extends StatelessWidget {
  static final Map<String, Future<Uint8List?>> _downloads = {};
  static final Map<String, DateTime> _retryAfter = {};

  /// Validate a new choice before replacing the currently saved artwork.
  static Future<Uint8List> validatedBytes(String source) async {
    Uint8List? bytes;
    if (source.startsWith('tablet-art:')) {
      bytes = await TabletMediaStore.read(source);
    } else if (source.startsWith('data:image/')) {
      bytes = Uri.parse(source).data?.contentAsBytes();
    } else {
      final uri = Uri.tryParse(source);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('Choose a complete image URL.');
      }
      if (!kIsWeb) {
        if (_retryAfter.containsKey(source)) {
          _downloads.remove(source);
          _retryAfter.remove(source);
        }
        bytes = await _cached(source);
      } else {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) bytes = response.bodyBytes;
      }
    }
    if (bytes == null || bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      throw const FormatException(
        'The image could not be loaded. Choose an image smaller than 12 MB.',
      );
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Only a re-downloadable, corrupt cache is discarded; saved selection and
      // immutable user media survive every failed load.
      _downloads.remove(source);
      if (!kIsWeb &&
          (source.startsWith('https://') || source.startsWith('http://'))) {
        await ArtworkManager.deleteCachedArtwork(source);
      }
      rethrow;
    }
    return bytes;
  }

  static Future<Uint8List?> _cached(String source) {
    final retry = _retryAfter[source];
    if (retry != null && DateTime.now().isAfter(retry)) {
      _downloads.remove(source);
      _retryAfter.remove(source);
    }
    if (!_downloads.containsKey(source) && _downloads.length >= 64) {
      final oldest = _downloads.keys.first;
      _downloads.remove(oldest);
      _retryAfter.remove(oldest);
    }
    return _downloads.putIfAbsent(source, () async {
      Uint8List? bytes;
      try {
        final file =
            await ArtworkManager.getCachedArtworkFile(source) ??
            await ArtworkManager.downloadArtwork(source);
        bytes = await file?.readAsBytes();
      } catch (_) {
        // A later render can retry a temporary network failure.
      }
      if (bytes == null) {
        _retryAfter[source] = DateTime.now().add(const Duration(seconds: 30));
      }
      return bytes;
    });
  }

  final String? url;
  final BoxFit fit;
  final Widget? placeholder;
  final bool crop;
  const TableArtwork({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.crop = false,
  });
  @override
  Widget build(BuildContext context) {
    Widget fallback() => placeholder ?? const SizedBox.expand();
    Widget frame(
      BuildContext context,
      Widget child,
      int? frame,
      bool synchronous,
    ) => synchronous
        ? child
        : AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 160),
            child: child,
          );
    Widget memory(Uint8List bytes) => Image.memory(
      bytes,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: frame,
      errorBuilder: (_, _, _) => fallback(),
    );
    final source = url;
    if (source == null || source.isEmpty) return fallback();
    if (source.startsWith('tablet-art:')) {
      return FutureBuilder<Uint8List?>(
        future: TabletMediaStore.read(source),
        builder: (context, snapshot) =>
            snapshot.data == null ? fallback() : memory(snapshot.data!),
      );
    }
    try {
      if (source.startsWith('data:image/')) {
        return memory(Uri.parse(source).data!.contentAsBytes());
      }
      if (source.startsWith('http://') || source.startsWith('https://')) {
        final display = crop
            ? (ArtworkManager.deriveScryfallArtCropUrl(source) ?? source)
            : source;
        if (!kIsWeb) {
          return FutureBuilder<Uint8List?>(
            future: _cached(display),
            builder: (context, snapshot) {
              if (snapshot.data != null) return memory(snapshot.data!);
              if (snapshot.connectionState == ConnectionState.done &&
                  display != source) {
                return FutureBuilder<Uint8List?>(
                  future: _cached(source),
                  builder: (context, fallbackSnapshot) =>
                      fallbackSnapshot.data == null
                      ? fallback()
                      : memory(fallbackSnapshot.data!),
                );
              }
              return fallback();
            },
          );
        }
        return Image.network(
          display,
          fit: fit,
          gaplessPlayback: true,
          frameBuilder: frame,
          errorBuilder: (_, _, _) => display == source
              ? fallback()
              : Image.network(
                  source,
                  fit: fit,
                  frameBuilder: frame,
                  errorBuilder: (_, _, _) => fallback(),
                ),
        );
      }
    } catch (_) {
      /* Missing imported media never clears the selection. */
    }
    return fallback();
  }
}

/// The same joined, readable surface is shared by tokens and utilities.
class TableArtworkSurface extends StatelessWidget {
  final String? url;
  final Widget child;
  final String style;
  final bool expanded;
  const TableArtworkSurface({
    super.key,
    required this.url,
    required this.child,
    this.style = 'full',
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (url != null)
        Positioned.fill(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SizedBox.expand(
                key: ValueKey('$url:$style'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (style == 'fadeout' && !expanded)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: .5,
                          heightFactor: 1,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.transparent, Colors.white],
                              stops: [0, .5],
                            ).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: TableArtwork(url: url, crop: true),
                          ),
                        ),
                      )
                    else
                      TableArtwork(url: url, crop: true, fit: BoxFit.fitWidth),
                    const ColoredBox(color: Color(0x99000000)),
                  ],
                ),
              ),
            ),
          ),
        ),
      child,
    ],
  );
}

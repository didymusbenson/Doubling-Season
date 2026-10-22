import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:doubling_season/utils/artwork_manager.dart';
import '../services/tablet_media_store.dart';

class TableArtwork extends StatelessWidget {
  static final Map<String, Future<Uint8List?>> _downloads = {};
  static Future<Uint8List?> _cached(String source) =>
      _downloads.putIfAbsent(source, () async {
        try {
          final file =
              await ArtworkManager.getCachedArtworkFile(source) ??
              await ArtworkManager.downloadArtwork(source);
          return await file?.readAsBytes();
        } catch (_) {
          return null;
        }
      });
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
    Widget memory(Uint8List bytes) => Image.memory(
      bytes,
      fit: fit,
      gaplessPlayback: true,
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
      if (source.startsWith('data:image/'))
        return memory(Uri.parse(source).data!.contentAsBytes());
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
          errorBuilder: (_, _, _) => display == source
              ? fallback()
              : Image.network(
                  source,
                  fit: fit,
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

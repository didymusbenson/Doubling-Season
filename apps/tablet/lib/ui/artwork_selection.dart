import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/table_state.dart';
import '../features/board_service.dart';
import '../services/tablet_catalog.dart';
import '../services/tablet_media_store.dart';
import 'table_artwork.dart';
import 'table_modal_frame.dart';
import 'artwork_credit.dart';
import 'workspace/player_keyboard.dart';

/// Native selection remains staged until crop and image decoding both succeed.
Future<String?> pickTabletArtwork(
  BuildContext context, {
  int quarterTurns = 0,
}) async {
  final FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
  } on PlatformException catch (error) {
    throw ArtworkImportException(error);
  }
  if (picked == null || !context.mounted) return null;
  final bytes = picked.files.single.bytes;
  if (bytes == null || bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('Choose an image smaller than 8 MB.');
  }
  final codec = await ui.instantiateImageCodec(bytes);
  late final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  if (!context.mounted) {
    image.dispose();
    return null;
  }
  try {
    final cropped = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (_) => TableModalFrame(
        quarterTurns: quarterTurns,
        child: _ArtworkCrop(image: image),
      ),
    );
    return cropped == null ? null : await TabletMediaStore.save(cropped);
  } finally {
    image.dispose();
  }
}

/// Preserve the platform diagnostic while giving a safe next step. This does
/// not imply that a native provider/permission failure has been repaired.
class ArtworkImportException implements Exception {
  const ArtworkImportException(this.cause);
  final PlatformException cause;
  @override
  String toString() =>
      'Image selection failed. Try again, or choose a local JPEG/PNG. '
      'Your current artwork is unchanged.\n'
      '${cause.code}: ${cause.message ?? "No platform message"}'
      '${cause.details == null ? "" : "\n${cause.details}"}';
}

class TabletArtworkSelection extends StatefulWidget {
  final BoardService board;
  final TabletCatalog catalog;
  final PlayerState player;
  final TokenState token;
  final int quarterTurns;
  final ValueChanged<bool>? onPreviewChanged;
  final Future<void> Function(String)? validate;
  const TabletArtworkSelection({
    super.key,
    required this.board,
    required this.catalog,
    required this.player,
    required this.token,
    this.quarterTurns = 0,
    this.onPreviewChanged,
    this.validate,
  });
  @override
  State<TabletArtworkSelection> createState() => _TabletArtworkSelectionState();
}

class _TabletArtworkSelectionState extends State<TabletArtworkSelection> {
  late final BoardScope scope;
  @override
  void initState() {
    super.initState();
    scope = widget.board.scope(widget.player.id);
  }

  final url = TextEditingController();
  Map<String, dynamic>? candidate;
  bool busy = false;
  String? error;
  int downloaded = 0;
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _validate(String source) async {
    if (widget.validate != null) {
      await widget.validate!(source);
    } else {
      await TableArtwork.validatedBytes(source);
    }
  }

  Future<void> choose(Map<String, dynamic> art) async {
    await _validate(art['url'] as String);
    if (mounted) {
      // Pasting a known printing URL must not lose its authoritative credit.
      // Match only the exact source URL; do not infer an artist from provenance
      // or download any additional image to recover metadata.
      final source = art['url'];
      final known = <Map<String, dynamic>>[
        ...widget.token.artworkOptions,
        ...?widget.catalog
            .byId(widget.token.definitionId)
            ?.artwork
            .map((variant) => variant.toJson()),
      ].where((option) => option['url'] == source).toList();
      final providedArtist = (art['artist'] as String? ?? '').trim();
      final providedSet = (art['set'] as String? ?? '').trim();
      final knownArtist = known
          .map((option) => option['artist'] as String? ?? '')
          .where((credit) => credit.trim().isNotEmpty && credit != 'Custom URL')
          .firstOrNull;
      final knownSet = known
          .map((option) => option['set'] as String? ?? '')
          .where((set) => set.trim().isNotEmpty && set != 'Custom URL')
          .firstOrNull;
      final enriched = <String, dynamic>{
        ...art,
        if ((providedArtist.isEmpty || providedArtist == 'Custom URL') &&
            knownArtist != null)
          'artist': knownArtist,
        if ((providedSet.isEmpty || providedSet == 'Custom URL') &&
            knownSet != null)
          'set': knownSet,
      };
      setState(() => candidate = enriched);
      widget.onPreviewChanged?.call(true);
      _revealCandidate();
    }
  }

  final _candidateKey = GlobalKey();

  void _revealCandidate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _candidateKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final catalogOptions =
        widget.catalog
            .byId(token.definitionId)
            ?.artwork
            .map((a) => a.toJson())
            .toList() ??
        <Map<String, dynamic>>[];
    final storedOptions = token.artworkOptions.isEmpty
        ? catalogOptions
        : token.artworkOptions;
    final options = storedOptions.map((art) {
      final known = catalogOptions
          .where((item) => item['url'] == art['url'])
          .firstOrNull;
      return <String, dynamic>{
        ...art,
        if ((art['artist'] as String? ?? '').isEmpty && known != null)
          'artist': known['artist'],
      };
    }).toList();
    final selected =
        candidate ??
        {
          'url': token.artworkUrl,
          'set': token.artworkSet,
          'artist':
              options
                  .where((art) => art['url'] == token.artworkUrl)
                  .map((art) => art['artist'])
                  .firstOrNull ??
              '',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerField(controller: url, label: 'Artwork image URL'),
        const SizedBox(height: 8),
        const Text(
          'Use a direct HTTP(S) image link, not a webpage (up to 12 MB).',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: busy
                ? null
                : () => run(() async {
                    final source = url.text.trim();
                    final uri = Uri.tryParse(source);
                    if (uri == null ||
                        !{'http', 'https'}.contains(uri.scheme) ||
                        uri.host.isEmpty) {
                      throw const FormatException(
                        'Enter a complete http:// or https:// image URL.',
                      );
                    }
                    await choose({
                      'url': source,
                      'artist': '',
                      'set': 'Custom URL',
                    });
                  }),
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview image URL'),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (selected['url'] != null)
          Padding(
            key: _candidateKey,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  candidate == null ? 'Current artwork' : 'Preview — not saved',
                ),
                SizedBox(
                  height: 160,
                  child: TableArtwork(
                    url: selected['url'] as String?,
                    fit: BoxFit.contain,
                  ),
                ),
                if ((selected['set'] as String? ?? '').isNotEmpty)
                  Text(selected['set'] as String),
                TabletArtworkCredit(
                  url: selected['url'] as String?,
                  artist: selected['artist'] as String?,
                ),
                if (candidate != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                setState(() => candidate = null);
                                widget.onPreviewChanged?.call(false);
                              },
                        child: const Text('Discard preview'),
                      ),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final art = candidate!;
                                await _validate(art['url'] as String);
                                if (!mounted) return;
                                await widget.board.setArtwork(
                                  widget.player.id,
                                  token.id,
                                  art['url'] as String,
                                  set: art['set'] as String?,
                                  artist: art['artist'] as String?,
                                  captured: scope,
                                );
                                if (mounted) {
                                  setState(() => candidate = null);
                                  widget.onPreviewChanged?.call(false);
                                }
                              }),
                        icon: const Icon(Icons.check),
                        label: const Text('Use this artwork'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final style in {
              'full': 'Full artwork',
              'fadeout': 'Fadeout',
            }.entries)
              ChoiceChip(
                label: Text(style.value),
                selected:
                    (token.extra['artworkDisplayStyle'] ?? 'full') == style.key,
                onSelected: busy
                    ? null
                    : (_) => run(
                        () => widget.board.setArtworkStyle(
                          widget.player.id,
                          token.id,
                          style.key,
                          captured: scope,
                        ),
                      ),
              ),
            if (token.artworkUrl != null)
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await widget.board.setArtwork(
                          widget.player.id,
                          token.id,
                          null,
                          captured: scope,
                        );
                        if (mounted) {
                          setState(() => candidate = null);
                          widget.onPreviewChanged?.call(false);
                        }
                      }),
                icon: const Icon(Icons.hide_image_outlined),
                label: const Text('Remove artwork'),
              ),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final source = await pickTabletArtwork(
                          context,
                          quarterTurns: widget.quarterTurns,
                        );
                        if (source != null) {
                          await choose({
                            'url': source,
                            'artist': 'user uploaded',
                            'set': 'Custom',
                          });
                        }
                      }),
                icon: const Icon(Icons.upload),
                label: Text(
                  token.artworkUrl?.startsWith('tablet-art:') == true
                      ? 'Replace / recrop upload'
                      : 'Upload and crop',
                ),
              ),
          ],
        ),
        if (options.isNotEmpty) ...[
          const Divider(height: 24),
          const Text('Choose a printing'),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('artwork-options-scroll'),
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final art in options)
                SizedBox(
                  width: 132,
                  child: InkWell(
                    onTap: busy ? null : () => run(() => choose(art)),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              width: 132,
                              height: 108,
                              child: TableArtwork(url: art['url'] as String?),
                            ),
                            if (art['url'] == token.artworkUrl)
                              const Positioned(
                                right: 4,
                                top: 4,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.lightGreenAccent,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          art['set'] as String? ?? '',
                          textAlign: TextAlign.center,
                        ),
                        TabletArtworkCredit(
                          url: art['url'] as String?,
                          artist: art['artist'] as String?,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: busy
                ? null
                : () => run(() async {
                    var count = 0;
                    for (final art in options) {
                      await TableArtwork.validatedBytes(art['url'] as String);
                      count++;
                      if (mounted) setState(() => downloaded = count);
                    }
                  }),
            icon: const Icon(Icons.download),
            label: Text(
              downloaded == 0
                  ? 'Download all artwork'
                  : 'Downloaded $downloaded / ${options.length}',
            ),
          ),
        ],
      ],
    );
  }
}

/// Encodes the same 4:3 crop that the preview paints, without mutating the
/// caller's image. Holding a clone keeps the source valid across route dismissal.
Future<Uint8List> encodeTabletArtworkCrop(
  ui.Image image,
  Rect source, {
  int quarterTurns = 0,
}) async {
  final retained = image.clone();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _paintArtworkCrop(
    canvas,
    const Size(768, 576),
    retained,
    source,
    quarterTurns,
  );
  final picture = recorder.endRecording();
  ui.Image? cropped;
  try {
    cropped = await picture.toImage(768, 576);
    final bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('The crop could not be saved. Please try again.');
    }
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    cropped?.dispose();
    picture.dispose();
    retained.dispose();
  }
}

void _paintArtworkCrop(
  Canvas canvas,
  Size size,
  ui.Image image,
  Rect source,
  int quarterTurns,
) {
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.scale(size.width / source.width, size.height / source.height);
  canvas.translate(-source.left, -source.top);
  switch (quarterTurns % 4) {
    case 1:
      canvas.translate(image.height.toDouble(), 0);
      canvas.rotate(math.pi / 2);
    case 2:
      canvas.translate(image.width.toDouble(), image.height.toDouble());
      canvas.rotate(math.pi);
    case 3:
      canvas.translate(0, image.width.toDouble());
      canvas.rotate(-math.pi / 2);
  }
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
}

class _ArtworkCrop extends StatefulWidget {
  final ui.Image image;
  const _ArtworkCrop({required this.image});
  @override
  State<_ArtworkCrop> createState() => _ArtworkCropState();
}

class _ArtworkCropState extends State<_ArtworkCrop> {
  late final ui.Image image = widget.image.clone();
  double zoom = 1, x = 0, y = 0;
  int quarterTurns = 0;
  bool busy = false;
  String? error;
  Size get rotatedSize => quarterTurns.isOdd
      ? Size(image.height.toDouble(), image.width.toDouble())
      : Size(image.width.toDouble(), image.height.toDouble());
  Rect get source {
    final size = rotatedSize;
    final width = math.min(size.width, size.height * 4 / 3) / zoom;
    final height = width * 3 / 4;
    return Rect.fromLTWH(
      (size.width - width) * (x + 1) / 2,
      (size.height - height) * (y + 1) / 2,
      width,
      height,
    );
  }

  void rotate(int direction) {
    if (busy) return;
    setState(() {
      quarterTurns = (quarterTurns + direction) % 4;
      final oldX = x;
      x = direction > 0 ? -y : y;
      y = direction > 0 ? oldX : -oldX;
    });
  }

  @override
  void dispose() {
    image.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await encodeTabletArtworkCrop(
        image,
        source,
        quarterTurns: quarterTurns,
      );
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Crop artwork')),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: GestureDetector(
                    onPanUpdate: busy
                        ? null
                        : (details) => setState(() {
                            x = (x - details.delta.dx / 100).clamp(-1, 1);
                            y = (y - details.delta.dy / 100).clamp(-1, 1);
                          }),
                    child: CustomPaint(
                      painter: _CropPainter(image, source, quarterTurns),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MergeSemantics(
                      child: Semantics(
                        label: 'Rotate artwork counterclockwise',
                        child: IconButton(
                          onPressed: busy ? null : () => rotate(-1),
                          icon: const Icon(Icons.rotate_left),
                        ),
                      ),
                    ),
                    Text('${quarterTurns * 90}°'),
                    MergeSemantics(
                      child: Semantics(
                        label: 'Rotate artwork clockwise',
                        child: IconButton(
                          onPressed: busy ? null : () => rotate(1),
                          icon: const Icon(Icons.rotate_right),
                        ),
                      ),
                    ),
                  ],
                ),
                const Text('Drag to position. Pinpoint with the sliders.'),
                const Text('Zoom'),
                Slider(
                  value: zoom,
                  min: 1,
                  max: 4,
                  label: zoom.toStringAsFixed(1),
                  onChanged: busy ? null : (v) => setState(() => zoom = v),
                ),
                const Text('Horizontal position'),
                Slider(
                  value: x,
                  min: -1,
                  max: 1,
                  onChanged: busy ? null : (v) => setState(() => x = v),
                ),
                const Text('Vertical position'),
                Slider(
                  value: y,
                  min: -1,
                  max: 1,
                  onChanged: busy ? null : (v) => setState(() => y = v),
                ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy ? null : save,
              child: const Text('Use crop'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect source;
  final int quarterTurns;
  const _CropPainter(this.image, this.source, this.quarterTurns);
  @override
  void paint(Canvas canvas, Size size) =>
      _paintArtworkCrop(canvas, size, image, source, quarterTurns);
  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      image != oldDelegate.image ||
      source != oldDelegate.source ||
      quarterTurns != oldDelegate.quarterTurns;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/table_state.dart';
import '../features/board_service.dart';
import '../services/tablet_catalog.dart';
import '../services/tablet_media_store.dart';
import 'table_artwork.dart';
import 'workspace/player_keyboard.dart';

/// Native selection remains staged until crop and image decoding both succeed.
Future<String?> pickTabletArtwork(
  BuildContext context, {
  int quarterTurns = 0,
}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
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
      builder: (_) => RotatedBox(
        quarterTurns: quarterTurns,
        child: _ArtworkCrop(image: image),
      ),
    );
    return cropped == null ? null : await TabletMediaStore.save(cropped);
  } finally {
    image.dispose();
  }
}

class TabletArtworkSelection extends StatefulWidget {
  final BoardService board;
  final TabletCatalog catalog;
  final PlayerState player;
  final TokenState token;
  final int quarterTurns;
  final ValueChanged<bool>? onPreviewChanged;
  const TabletArtworkSelection({
    super.key,
    required this.board,
    required this.catalog,
    required this.player,
    required this.token,
    this.quarterTurns = 0,
    this.onPreviewChanged,
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

  Future<void> choose(Map<String, dynamic> art) async {
    await TableArtwork.validatedBytes(art['url'] as String);
    if (mounted) {
      setState(() => candidate = art);
      widget.onPreviewChanged?.call(true);
    }
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${token.name} · artwork',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Selections belong to this player and this game.'),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (busy) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected['url'] != null)
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    if (selected['url'] != null) ...[
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 160,
                          child: TableArtwork(
                            url: selected['url'] as String?,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${selected['set'] ?? ''} · ${selected['artist'] ?? ''}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Center(
                        child: Text(
                          candidate == null
                              ? 'Current artwork'
                              : 'Preview — confirm to apply',
                        ),
                      ),
                    ],
                    if (candidate != null)
                      Center(
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  final art = candidate!;
                                  await TableArtwork.validatedBytes(
                                    art['url'] as String,
                                  );
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
                      ),
                  ],
                ),
              ),
            if (selected['url'] != null) const SizedBox(width: 12),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: selected['url'] != null ? 200 : 120,
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('artwork-options-scroll'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                                      child: TableArtwork(
                                        url: art['url'] as String?,
                                      ),
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
                                  '${art['set'] ?? ''}\n${art['artist'] ?? ''}',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (options.isNotEmpty)
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
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
        PlayerField(controller: url, label: 'Artwork image URL'),
        TextButton.icon(
          onPressed: busy
              ? null
              : () => run(
                  () =>
                      choose({'url': url.text.trim(), 'artist': 'Custom URL'}),
                ),
          icon: const Icon(Icons.preview_outlined),
          label: const Text('Preview image URL'),
        ),
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Crop artwork'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                IconButton(
                  tooltip: 'Rotate artwork counterclockwise',
                  onPressed: busy ? null : () => rotate(-1),
                  icon: const Icon(Icons.rotate_left),
                ),
                Text('${quarterTurns * 90}°'),
                IconButton(
                  tooltip: 'Rotate artwork clockwise',
                  onPressed: busy ? null : () => rotate(1),
                  icon: const Icon(Icons.rotate_right),
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
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Use crop'),
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

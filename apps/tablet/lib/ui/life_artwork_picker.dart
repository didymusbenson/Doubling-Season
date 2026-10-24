import 'dart:math' as math;

import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';

import '../services/tablet_catalog.dart';
import 'artwork_selection.dart';
import 'table_artwork.dart';
import 'workspace/player_keyboard.dart';

/// A seat-facing catalog chooser, independent of board tokens/preferences.
/// The returned reference is staged: the caller owns the scoped durable commit.
Future<String?> showLifeArtworkPicker(
  BuildContext context, {
  required TabletCatalog catalog,
  required String seatName,
  required int quarterTurns,
  String? current,
}) => showDialog<String>(
  context: context,
  barrierDismissible: true,
  builder: (_) => LifeArtworkPicker(
    catalog: catalog,
    seatName: seatName,
    quarterTurns: quarterTurns,
    current: current,
  ),
);

class LifeArtworkPicker extends StatefulWidget {
  const LifeArtworkPicker({
    super.key,
    required this.catalog,
    required this.seatName,
    required this.quarterTurns,
    this.current,
    this.validate,
    this.importArtwork,
  });
  final TabletCatalog catalog;
  final String seatName;
  final int quarterTurns;
  final String? current;
  // Injectable I/O boundaries keep interaction tests independent of the network
  // and native file picker. Production uses the existing validated media paths.
  final Future<void> Function(String)? validate;
  final Future<String?> Function()? importArtwork;
  @override
  State<LifeArtworkPicker> createState() => _LifeArtworkPickerState();
}

class _LifeArtworkPickerState extends State<LifeArtworkPicker> {
  final query = TextEditingController();
  TokenDefinition? definition;
  ArtworkVariant? variant;
  String? candidate;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
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

  Future<void> _choose(ArtworkVariant art) => _run(() async {
    await _validate(art.url);
    if (!mounted) return;
    setState(() {
      candidate = art.url;
      variant = art;
    });
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final available = widget.quarterTurns.isOdd
        ? Size(size.height, size.width)
        : size;
    return Center(
      child: RotatedBox(
        quarterTurns: widget.quarterTurns,
        child: SizedBox(
          width: math.min(660, available.width - 32),
          height: math.min(650, available.height - 32),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (definition != null || candidate != null)
                        IconButton(
                          tooltip: 'Back to token art search',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  definition = null;
                                  candidate = null;
                                  variant = null;
                                }),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      Expanded(
                        child: Text(
                          '${widget.seatName} · life artwork',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close artwork search',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  SizedBox(
                    height: 4,
                    child: busy ? const LinearProgressIndicator() : null,
                  ),
                  Expanded(
                    child: PlayerKeyboardHost(
                      key: ValueKey(
                        '${definition?.id ?? 'life-art-search'}:${candidate ?? ''}',
                      ),
                      enabled: !busy,
                      canEdit: () => !busy,
                      child: Column(
                        children: [
                          if (candidate != null) ...[
                            SizedBox(
                              height: 110,
                              width: double.infinity,
                              child: TableArtwork(
                                url: candidate,
                                crop: true,
                                showLoadStatus: true,
                              ),
                            ),
                            if (variant != null)
                              Text('${variant!.set} · ${variant!.artist}'),
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _run(() async {
                                      final selected = candidate!;
                                      await _validate(selected);
                                      if (context.mounted) {
                                        Navigator.pop(context, selected);
                                      }
                                    }),
                              icon: const Icon(Icons.check),
                              label: const Text('Use artwork'),
                            ),
                          ],
                          if (definition == null && candidate == null) ...[
                            PlayerField(
                              controller: query,
                              label: 'Search token art',
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListenableBuilder(
                                listenable: Listenable.merge([
                                  query,
                                  widget.catalog,
                                ]),
                                builder: (context, _) {
                                  final results = widget.catalog
                                      .search(query.text)
                                      .where((t) => t.artwork.isNotEmpty)
                                      .toList();
                                  if (!widget.catalog.loaded &&
                                      widget.catalog.error == null) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (results.isEmpty) {
                                    return Center(
                                      child: Text(
                                        widget.catalog.error ??
                                            'No matching token art. Try another search.',
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      final token = results[index];
                                      return ListTile(
                                        leading: SizedBox(
                                          width: 54,
                                          height: 54,
                                          child: TableArtwork(
                                            url: token.artwork.first.url,
                                            crop: true,
                                            showLoadStatus: true,
                                          ),
                                        ),
                                        title: Text(token.name),
                                        subtitle: Text(
                                          '${token.pt} ${token.cleanType}'
                                              .trim(),
                                        ),
                                        onTap: busy
                                            ? null
                                            : () => setState(() {
                                                definition = token;
                                                candidate = null;
                                                variant = null;
                                              }),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ] else if (definition != null) ...[
                            Text(definition!.name),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 190,
                                      mainAxisExtent: 150,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: definition!.artwork.length,
                                itemBuilder: (context, index) {
                                  final art = definition!.artwork[index];
                                  return InkWell(
                                    onTap: busy ? null : () => _choose(art),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: TableArtwork(
                                            url: art.url,
                                            crop: true,
                                            showLoadStatus: true,
                                          ),
                                        ),
                                        Text(
                                          '${art.set} · ${art.artist}',
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ] else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import custom image'),
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                            final Future<String?> importResult;
                            if (widget.importArtwork != null) {
                              importResult = widget.importArtwork!();
                            } else {
                              importResult = pickTabletArtwork(
                                context,
                                quarterTurns: widget.quarterTurns,
                              );
                            }
                            final imported = await importResult;
                            if (!mounted || imported == null) return;
                            setState(() {
                              candidate = imported;
                              variant = null;
                            });
                          }),
                  ),
                  const Text(
                    'Device browsing follows system orientation; cropping faces you.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

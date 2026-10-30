import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';

import '../services/tablet_catalog.dart';
import 'artwork_selection.dart';
import 'table_artwork.dart';
import 'table_modal_frame.dart';
import 'artwork_credit.dart';
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
  useSafeArea: false,
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
  final _scroll = ScrollController();
  TokenDefinition? definition;
  ArtworkVariant? variant;
  String? candidate;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    query.dispose();
    _scroll.dispose();
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
      if (mounted) {
        setState(() => error = '$e');
        _revealTop();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _revealTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
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
    _revealTop();
  });

  @override
  Widget build(BuildContext context) => TableModalFrame(
    quarterTurns: widget.quarterTurns,
    surfaceKey: const ValueKey('life-artwork-modal'),
    child: PlayerKeyboardHost(
      key: ValueKey('${definition?.id}:${candidate != null}'),
      enabled: !busy,
      canEdit: () => !busy,
      onClose: () => Navigator.pop(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              children: [
                if (definition != null || candidate != null)
                  MergeSemantics(
                    child: Semantics(
                      label: 'Back to token art search',
                      child: IconButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                definition = null;
                                candidate = null;
                                variant = null;
                              }),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${widget.seatName} · life artwork',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                MergeSemantics(
                  child: Semantics(
                    label: 'Close artwork search',
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 4,
            child: busy ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([query, widget.catalog]),
              builder: (context, _) {
                final results = widget.catalog
                    .search(query.text)
                    .where((t) => t.artwork.isNotEmpty)
                    .toList();
                return ListView(
                  key: const PageStorageKey('life-artwork-content'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (candidate != null) ...[
                      const Text('Preview — not saved'),
                      SizedBox(
                        height: 140,
                        child: TableArtwork(
                          url: candidate,
                          crop: true,
                          showLoadStatus: true,
                        ),
                      ),
                      if (variant != null) Text(variant!.set),
                      TabletArtworkCredit(
                        url: candidate,
                        artist: variant?.artist,
                      ),
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
                      const Divider(height: 24),
                    ],
                    if (definition == null && candidate == null) ...[
                      PlayerField(controller: query, label: 'Search token art'),
                      const SizedBox(height: 8),
                      if (!widget.catalog.loaded &&
                          widget.catalog.error == null)
                        const Center(child: CircularProgressIndicator())
                      else if (results.isEmpty)
                        Text(
                          widget.catalog.error ??
                              'No matching token art. Try another search.',
                        )
                      else
                        for (final token in results)
                          ListTile(
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
                              '${token.pt} ${token.cleanType}'.trim(),
                            ),
                            onTap: busy
                                ? null
                                : () => setState(() {
                                    definition = token;
                                    candidate = null;
                                    variant = null;
                                  }),
                          ),
                    ] else if (definition != null) ...[
                      Text(
                        definition!.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          for (final art in definition!.artwork)
                            SizedBox(
                              width: 170,
                              child: InkWell(
                                onTap: busy ? null : () => _choose(art),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 120,
                                      child: TableArtwork(
                                        url: art.url,
                                        crop: true,
                                        showLoadStatus: true,
                                      ),
                                    ),
                                    Text(art.set),
                                    TabletArtworkCredit(
                                      url: art.url,
                                      artist: art.artist,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Import custom image'),
                      onPressed: busy
                          ? null
                          : () => _run(() async {
                              final imported =
                                  await (widget.importArtwork?.call() ??
                                      pickTabletArtwork(
                                        context,
                                        quarterTurns: widget.quarterTurns,
                                      ));
                              if (!mounted || imported == null) return;
                              setState(() {
                                candidate = imported;
                                variant = null;
                              });
                              _revealTop();
                            }),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

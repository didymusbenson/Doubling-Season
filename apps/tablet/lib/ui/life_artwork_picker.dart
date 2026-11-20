import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';

import '../services/tablet_catalog.dart';
import '../domain/input_validation.dart';
import 'artwork_selection.dart';
import 'table_artwork.dart';
import 'table_modal_frame.dart';
import 'player_input_mode.dart';
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
  TextEditingController? queryController,
  String? initialCandidate,
  ValueChanged<String?>? onCandidateChanged,
}) => showDialog<String>(
  context: context,
  barrierDismissible: true,
  useSafeArea: false,
  builder: (_) => LifeArtworkPicker(
    catalog: catalog,
    seatName: seatName,
    quarterTurns: quarterTurns,
    current: current,
    queryController: queryController,
    initialCandidate: initialCandidate,
    onCandidateChanged: onCandidateChanged,
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
    this.queryController,
    this.initialCandidate,
    this.onCandidateChanged,
  });
  final TabletCatalog catalog;
  final String seatName;
  final int quarterTurns;
  final String? current;
  final TextEditingController? queryController;
  final String? initialCandidate;
  final ValueChanged<String?>? onCandidateChanged;
  // Injectable I/O boundaries keep interaction tests independent of the network
  // and native file picker. Production uses the existing validated media paths.
  final Future<void> Function(String)? validate;
  final Future<String?> Function()? importArtwork;
  @override
  State<LifeArtworkPicker> createState() => _LifeArtworkPickerState();
}

class _LifeArtworkPickerState extends State<LifeArtworkPicker> {
  late final TextEditingController query;
  final _resultsScroll = ScrollController();
  final _detailScroll = ScrollController();
  TokenDefinition? definition;
  ArtworkVariant? variant;
  String? candidate;
  String? error;
  bool busy = false;
  late String _lastQuery;

  @override
  void initState() {
    super.initState();
    query = widget.queryController ?? TextEditingController();
    candidate = widget.initialCandidate == widget.current
        ? null
        : widget.initialCandidate;
    if (candidate != null) {
      definition = widget.catalog.tokens
          .where((token) => token.artwork.any((art) => art.url == candidate))
          .firstOrNull;
      variant = definition?.artwork
          .where((art) => art.url == candidate)
          .firstOrNull;
    }
    _lastQuery = query.text;
    query.addListener(_resetResults);
  }

  void _resetResults() {
    if (_lastQuery == query.text) return;
    _lastQuery = query.text;
    if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
  }

  @override
  void dispose() {
    query.removeListener(_resetResults);
    if (widget.queryController == null) query.dispose();
    _resultsScroll.dispose();
    _detailScroll.dispose();
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
        setState(
          () => error = inputErrorMessage(
            e,
            fallback:
                'Artwork could not be updated. Your selection is unchanged.',
          ),
        );
        _revealTop();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _revealTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scroll = _searching ? _resultsScroll : _detailScroll;
      if (scroll.hasClients) scroll.jumpTo(0);
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
      widget.onCandidateChanged?.call(candidate);
      variant = art;
    });
    _revealTop();
  });

  bool get _searching => definition == null && candidate == null;

  void _back() {
    setState(() {
      error = null;
      if (candidate != null) {
        candidate = null;
        widget.onCandidateChanged?.call(null);
        variant = null;
      } else {
        definition = null;
      }
    });
  }

  Future<void> _import() => _run(() async {
    final imported =
        await (widget.importArtwork?.call() ??
            pickTabletArtwork(context, quarterTurns: widget.quarterTurns));
    if (!mounted || imported == null) return;
    setState(() {
      candidate = imported;
      widget.onCandidateChanged?.call(candidate);
      variant = null;
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
                if (!_searching)
                  MergeSemantics(
                    child: Semantics(
                      label: candidate != null && definition != null
                          ? 'Back to artwork printings'
                          : 'Back to token art search',
                      child: IconButton(
                        onPressed: busy ? null : _back,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${widget.seatName} · life artwork',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          if (_searching) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: PlayerField(
                controller: query,
                label: 'Search token art',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            Expanded(child: _searchResults()),
            if (!usesNativePlayerInput(context) ||
                MediaQuery.viewInsetsOf(context).bottom == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton.icon(
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Import custom image'),
                  onPressed: busy ? null : _import,
                ),
              ),
          ] else
            Expanded(child: _details()),
        ],
      ),
    ),
  );

  Widget _searchResults() => ListenableBuilder(
    listenable: Listenable.merge([query, widget.catalog]),
    builder: (context, _) {
      final results = widget.catalog
          .search(query.text)
          .where((token) => token.artwork.isNotEmpty)
          .toList();
      final message = error ?? widget.catalog.error;
      final offset = message == null ? 0 : 1;
      final loading = !widget.catalog.loaded && widget.catalog.error == null;
      return ListView.builder(
        key: const PageStorageKey('life-artwork-results'),
        controller: _resultsScroll,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: (results.isEmpty || loading ? 1 : results.length) + offset,
        itemBuilder: (context, index) {
          if (offset == 1 && index == 0) return _error(message!);
          if (loading) return const Center(child: CircularProgressIndicator());
          if (results.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No matching token art. Try another search or import an image.',
              ),
            );
          }
          final token = results[index - offset];
          final title = '${token.pt} ${token.cleanType}'.trim();
          final count = token.artwork.length;
          return Card(
            child: ListTile(
              leading: _image(token.artwork.first.url, width: 54, height: 48),
              title: Text(token.name),
              subtitle: Text(
                [
                  if (title.isNotEmpty) title,
                  '$count ${count == 1 ? 'printing' : 'printings'}',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy
                  ? null
                  : () => setState(() {
                      definition = token;
                      error = null;
                    }),
            ),
          );
        },
      );
    },
  );

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );

  Widget _image(String? url, {double? width, required double height}) =>
      SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TableArtwork(
            url: url,
            crop: true,
            showLoadStatus: true,
            placeholder: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _details() => ListView(
    key: PageStorageKey(
      candidate != null ? 'life-artwork-preview' : 'life-artwork-printings',
    ),
    controller: _detailScroll,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    children: [
      if (error != null) _error(error!),
      if (candidate != null) ...[
        Text('Preview', style: Theme.of(context).textTheme.titleMedium),
        const Text('Select Use artwork to change this seat.'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, bounds) => _image(
            candidate,
            height: (bounds.maxWidth * .5).clamp(116.0, 270.0),
          ),
        ),
        const SizedBox(height: 8),
        if (definition != null) Text(definition!.name),
        if (variant != null) Text(variant!.set),
        TabletArtworkCredit(url: candidate, artist: variant?.artist),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => _run(() async {
                  final selected = candidate!;
                  await _validate(selected);
                  if (mounted) Navigator.pop(context, selected);
                }),
          icon: const Icon(Icons.check),
          label: const Text('Use artwork'),
        ),
      ] else ...[
        Text(definition!.name, style: Theme.of(context).textTheme.titleMedium),
        const Text('Choose a printing to preview.'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, bounds) {
            final columns = bounds.maxWidth >= 570
                ? 3
                : bounds.maxWidth >= 280
                ? 2
                : 1;
            final width = (bounds.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final art in definition!.artwork)
                  SizedBox(
                    width: width,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: busy ? null : () => _choose(art),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _image(art.url, height: 108),
                              const SizedBox(height: 6),
                              Text(
                                art.set,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              TabletArtworkCredit(
                                url: art.url,
                                artist: art.artist,
                              ),
                              if (art.url == widget.current)
                                const Text('Current artwork'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ],
  );
}

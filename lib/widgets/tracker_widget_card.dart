import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/tracker_widget.dart';
import '../models/token_definition.dart';
import '../controllers/expandable_card_controller.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../providers/toggle_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/token_provider.dart';
import '../providers/rules_provider.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_metadata_enricher.dart';
import '../utils/color_utils.dart';
import 'common/background_text.dart';
// Unused import was causing build warnings
// import 'cropped_artwork_widget.dart';
import 'mixins/artwork_display_mixin.dart';
import '../services/token_creation_service.dart';
import '../services/rhys_copy_planner.dart';
import '../services/brudiclad_transform_planner.dart';
import '../services/board_undo_snapshot.dart';
import '../services/token_result_artwork_resolver.dart';
import '../database/token_database.dart';
import '../database/widget_database.dart';
import 'definition_preview_card.dart';
import 'mana/mana_text.dart';
import 'artwork_selection_sheet.dart';
import 'inline_color_identity_bar.dart';
import 'inline_artwork_button.dart';

class TrackerWidgetCard extends StatefulWidget {
  final TrackerWidget tracker;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<bool> onEditingChanged;
  final ExpandableCardController? controller;

  const TrackerWidgetCard({
    super.key,
    required this.tracker,
    required this.isExpanded,
    required this.onExpand,
    required this.onCollapse,
    required this.onEditingChanged,
    this.controller,
  });

  @override
  State<TrackerWidgetCard> createState() => _TrackerWidgetCardState();
}

class _BrudicladSelection {
  final BrudicladTokenDefinition? definition;
  final bool skipped;
  final bool cancelled;

  const _BrudicladSelection.resolve(this.definition)
      : skipped = false,
        cancelled = false;

  const _BrudicladSelection.skip()
      : definition = null,
        skipped = true,
        cancelled = false;
}

class _TrackerWidgetCardState extends State<TrackerWidgetCard>
    with SingleTickerProviderStateMixin, ArtworkDisplayMixin {
  static const double _identityRailWidth = 7;
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocusNode;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late final TextEditingController _valueController;
  late final FocusNode _valueFocusNode;
  bool _editingName = false;
  bool _editingValue = false;
  bool _committingValue = false;
  int? _valueBeforeEdit;
  bool _editingDescription = false;
  Future<bool>? _nameCommit;
  Future<bool>? _descriptionCommit;
  Future<bool>? _valueCommit;
  double? _artworkRevealHeight;
  late final AnimationController _artworkCenterController;
  late final CurvedAnimation _artworkCenterProgress;

  // Cached artwork Future to prevent FutureBuilder rebuilds.
  Future<File?>? _cachedArtworkFuture;

  // Implement ArtworkDisplayMixin interface
  @override
  DateTime get createdAt => _createdAt;

  @override
  bool get artworkAnimated => _artworkAnimated;

  @override
  set artworkAnimated(bool value) => _artworkAnimated = value;

  @override
  bool get artworkCleanupAttempted => _artworkCleanupAttempted;

  @override
  set artworkCleanupAttempted(bool value) => _artworkCleanupAttempted = value;

  @override
  String? get artworkUrl => widget.tracker.artworkUrl;

  @override
  void clearArtwork() {
    widget.tracker.artworkUrl = null;
    widget.tracker.artworkSet = null;
    widget.tracker.artworkOptions = null;
    widget.tracker.save();
  }

  @override
  void initState() {
    super.initState();
    _artworkCenterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );
    _artworkCenterProgress = CurvedAnimation(
      parent: _artworkCenterController,
      curve: const Cubic(0.18, 0.89, 0.32, 1.08),
    );
    _descriptionController =
        TextEditingController(text: widget.tracker.description);
    _descriptionFocusNode = FocusNode()..addListener(_handleDescriptionFocus);
    _nameController = TextEditingController(text: widget.tracker.name);
    _nameFocusNode = FocusNode()..addListener(_handleNameFocus);
    _valueController =
        TextEditingController(text: '${widget.tracker.currentValue}');
    _valueFocusNode = FocusNode()..addListener(_handleValueFocus);
    widget.controller?.attach(_requestCollapse);
    // Cache the artwork Future on initialization
    if (widget.tracker.artworkUrl != null) {
      _cachedArtworkFuture =
          ArtworkManager.getCachedArtworkFile(widget.tracker.artworkUrl!);
    }
  }

  @override
  void didUpdateWidget(TrackerWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_requestCollapse);
      widget.controller?.attach(_requestCollapse);
    }
    if (!oldWidget.isExpanded && widget.isExpanded) {
      final renderBox = context.findRenderObject();
      if (renderBox is RenderBox && renderBox.hasSize) {
        _artworkRevealHeight = renderBox.size.height;
      }
      _artworkCenterController
        ..duration = const Duration(milliseconds: 380)
        ..forward(from: 0);
    } else if (oldWidget.isExpanded && !widget.isExpanded) {
      final renderBox = context.findRenderObject();
      if (renderBox is RenderBox && renderBox.hasSize) {
        _artworkRevealHeight = renderBox.size.height;
      }
      _artworkCenterController
        ..duration = const Duration(milliseconds: 240)
        ..forward(from: 0);
    }
    if (!_editingDescription &&
        _descriptionController.text != widget.tracker.description) {
      _descriptionController.text = widget.tracker.description;
    }
    if (!_editingName && _nameController.text != widget.tracker.name) {
      _nameController.text = widget.tracker.name;
    }
    if (!_editingValue &&
        _valueController.text != '${widget.tracker.currentValue}') {
      _valueController.text = '${widget.tracker.currentValue}';
    }
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.tracker.artworkUrl != widget.tracker.artworkUrl) {
      _artworkCleanupAttempted = false;

      // Update cached future when artwork changes
      _cachedArtworkFuture = widget.tracker.artworkUrl != null
          ? ArtworkManager.getCachedArtworkFile(widget.tracker.artworkUrl!)
          : null;
    }
  }

  @override
  void dispose() {
    _artworkCenterProgress.dispose();
    _artworkCenterController.dispose();
    widget.controller?.detach(_requestCollapse);
    _descriptionFocusNode
      ..removeListener(_handleDescriptionFocus)
      ..dispose();
    _descriptionController.dispose();
    _nameFocusNode
      ..removeListener(_handleNameFocus)
      ..dispose();
    _nameController.dispose();
    _valueFocusNode
      ..removeListener(_handleValueFocus)
      ..dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, String>(
      selector: (context, settings) => settings.artworkDisplayStyle,
      builder: (context, artworkDisplayStyle, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.isExpanded ? _collapseAfterCommit : widget.onExpand,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 380),
            reverseDuration: const Duration(milliseconds: 240),
            curve: const Cubic(0.18, 0.89, 0.32, 1.08),
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: (widget.tracker.actionType == 'academy_manufactor' &&
                      widget.tracker.currentValue <= 0)
                  ? 0.4
                  : 1.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Base card background layer (transparent to allow red swipe indicator through)
                      Container(
                        color: Colors.transparent,
                      ),

                      // Gradient background layer
                      if (widget.tracker.artworkUrl == null ||
                          widget.tracker.artworkUrl!.isEmpty)
                        _buildGradientLayer(context)
                      else
                        _buildConditionalGradient(context),

                      // Artwork layer
                      if (widget.tracker.artworkUrl != null)
                        buildArtworkLayer(
                          context: context,
                          constraints: constraints,
                          artworkDisplayStyle: artworkDisplayStyle,
                          cornerRadius: 0,
                          revealViewportHeight: _artworkRevealHeight,
                          revealProgress: _artworkCenterProgress,
                        ),

                      // Content layer
                      Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.fromLTRB(
                          UIConstants.cardPadding + _identityRailWidth,
                          UIConstants.cardPadding,
                          UIConstants.cardPadding,
                          UIConstants.cardPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top row: Name/Description and Value
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left side: Name, Description (takes remaining space)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Name
                                      _buildInlineName(context),

                                      // Description (if present)
                                      if (widget.isExpanded ||
                                          widget.tracker.description
                                              .isNotEmpty) ...[
                                        const SizedBox(
                                            height: UIConstants.mediumSpacing),
                                        _buildInlineDescription(context),
                                      ],
                                    ],
                                  ),
                                ),

                                // Right side: Value display (shrink-wraps).
                                // Action-only utilities have no tracker value.
                                if (!widget.tracker.actionOnly) ...[
                                  const SizedBox(
                                      width: UIConstants.mediumSpacing),
                                  _buildValueDisplay(context),
                                ],
                              ],
                            ),

                            const SizedBox(height: UIConstants.mediumSpacing),

                            // Bottom row: Action buttons (full width)
                            _buildActionButtons(context),
                            if (widget.isExpanded) ...[
                              const SizedBox(height: UIConstants.mediumSpacing),
                              _buildExpandedCharacteristics(context),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _identityRailWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: ColorUtils.gradientForColors(
                                widget.tracker.colorIdentity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ), // Opacity
          ),
        );
      },
    );
  }

  void _handleDescriptionFocus() {
    if (!_descriptionFocusNode.hasFocus && _editingDescription) {
      _commitDescription();
    }
  }

  void _handleNameFocus() {
    if (!_nameFocusNode.hasFocus && _editingName) _commitName();
  }

  void _handleValueFocus() {
    if (!_valueFocusNode.hasFocus && _editingValue) _commitValue();
  }

  Future<void> _beginNameEdit() async {
    if (!await _commitDescription() || !await _commitValue() || !mounted) {
      return;
    }
    setState(() => _editingName = true);
    widget.onEditingChanged(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
  }

  Future<bool> _commitName() {
    return _nameCommit ??= _commitNameOnce().whenComplete(() {
      _nameCommit = null;
    });
  }

  Future<bool> _commitNameOnce() async {
    if (!_editingName) return true;
    final previous = widget.tracker.name;
    final next = _nameController.text.trim();
    if (next.isEmpty) {
      _nameController.text = previous;
      if (mounted) setState(() => _editingName = false);
      widget.onEditingChanged(false);
      return true;
    }
    widget.tracker.name = next;
    try {
      await context.read<TrackerProvider>().updateTracker(widget.tracker);
      if (mounted) setState(() => _editingName = false);
      widget.onEditingChanged(false);
      return true;
    } catch (_) {
      widget.tracker.name = previous;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utility name could not be saved.')),
        );
      }
      return false;
    }
  }

  Widget _buildInlineName(BuildContext context) {
    if (_editingName) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 52),
        child: TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          decoration: const InputDecoration(
            isDense: true,
            filled: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitName(),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.isExpanded ? _beginNameEdit : null,
      child: BackgroundText(
        child: Text(
          widget.tracker.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Future<void> _beginDescriptionEdit() async {
    if (_editingDescription) return;
    if (!await _commitName() || !await _commitValue() || !mounted) return;
    setState(() => _editingDescription = true);
    widget.onEditingChanged(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _descriptionFocusNode.requestFocus();
    });
  }

  Future<bool> _commitDescription() {
    return _descriptionCommit ??= _commitDescriptionOnce().whenComplete(() {
      _descriptionCommit = null;
    });
  }

  Future<bool> _commitDescriptionOnce() async {
    if (!_editingDescription) return true;
    final previous = widget.tracker.description;
    widget.tracker.description = _descriptionController.text;
    try {
      await context.read<TrackerProvider>().updateTracker(widget.tracker);
      if (mounted) setState(() => _editingDescription = false);
      widget.onEditingChanged(false);
      return true;
    } catch (_) {
      widget.tracker.description = previous;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description could not be saved.')),
        );
      }
      return false;
    }
  }

  Future<bool> _requestCollapse() async {
    if (!await _commitName()) return false;
    if (!await _commitDescription()) return false;
    return _commitValue();
  }

  Future<void> _collapseAfterCommit() async {
    final approved = await (widget.controller?.requestCollapse() ??
        Future<bool>.value(true));
    if (mounted && approved) widget.onCollapse();
  }

  Widget _buildInlineDescription(BuildContext context) {
    if (_editingDescription) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 112),
        child: TextField(
          controller: _descriptionController,
          focusNode: _descriptionFocusNode,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            isDense: true,
            filled: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitDescription(),
        ),
      );
    }
    return Semantics(
      button: true,
      label: widget.tracker.description.isEmpty
          ? 'Empty utility description'
          : 'Utility description',
      hint: 'Double tap to edit',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _beginDescriptionEdit,
        child: BackgroundText(
          child: widget.tracker.description.isEmpty
              ? Text(
                  'Description',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.55),
                      ),
                )
              : ManaText(
                  widget.tracker.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
        ),
      ),
    );
  }

  Widget _buildExpandedCharacteristics(BuildContext context) => Row(
        children: [
          InlineColorIdentityBar(
            colorIdentity: widget.tracker.colorIdentity,
            onToggle: _toggleColorIdentity,
          ),
          const SizedBox(width: UIConstants.verticalSpacing),
          _buildArtworkButton(context),
        ],
      );

  Widget _buildArtworkButton(BuildContext context) => InlineArtworkButton(
        hasArtwork: widget.tracker.artworkUrl != null,
        onPressed: _showArtworkSelection,
      );

  Future<void> _toggleColorIdentity(String symbol) async {
    if (!await _requestCollapse() || !mounted) return;
    final selected = widget.tracker.colorIdentity.characters.toSet();
    selected.contains(symbol) ? selected.remove(symbol) : selected.add(symbol);
    widget.tracker.colorIdentity =
        'WUBRG'.characters.where(selected.contains).join();
    await context.read<TrackerProvider>().updateTracker(widget.tracker);
    if (mounted) setState(() {});
  }

  Future<void> _showArtworkSelection() async {
    if (!await _requestCollapse() || !mounted) return;
    final trackerProvider = context.read<TrackerProvider>();
    final options = await _artworkOptions();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: ArtworkSelectionSheet(
          artworkVariants: options,
          currentArtworkUrl: widget.tracker.artworkUrl,
          currentArtworkSet: widget.tracker.artworkSet,
          tokenName: widget.tracker.name,
          tokenIdentity: widget.tracker.widgetId,
          databaseLoadError: false,
          onArtworkSelected: (url, setCode) async {
            if (!kIsWeb && !url.startsWith('file://')) {
              final file = await ArtworkManager.downloadArtwork(url);
              if (file == null) {
                throw StateError('Artwork download failed');
              }
            }
            widget.tracker
              ..artworkUrl = url
              ..artworkSet = setCode
              ..artworkOptions = List<ArtworkVariant>.from(options);
            await trackerProvider.updateTracker(widget.tracker);
            if (mounted) {
              setState(() {
                _artworkCleanupAttempted = false;
                _cachedArtworkFuture = ArtworkManager.getCachedArtworkFile(url);
              });
            }
          },
          onRemoveArtwork: widget.tracker.artworkUrl == null
              ? null
              : () async {
                  widget.tracker
                    ..artworkUrl = null
                    ..artworkSet = null;
                  await trackerProvider.updateTracker(widget.tracker);
                  if (mounted) {
                    setState(() {
                      _artworkCleanupAttempted = false;
                      _cachedArtworkFuture = null;
                    });
                  }
                },
        ),
      ),
    );
  }

  Future<List<ArtworkVariant>> _artworkOptions() async {
    final existing = widget.tracker.artworkOptions;
    final database = WidgetDatabase();
    final match = database.filteredWidgets.where(
      (definition) => definition.name == widget.tracker.name,
    );
    if (match.isEmpty) return const <ArtworkVariant>[];
    final authoritative = List<ArtworkVariant>.from(match.first.artwork);
    if (existing != null &&
        existing.isNotEmpty &&
        !ArtworkMetadataEnricher.needsArtistMetadata(existing)) {
      return existing;
    }
    final options = ArtworkMetadataEnricher.merge(
      existing: existing ?? const <ArtworkVariant>[],
      authoritative: authoritative,
    );
    widget.tracker.artworkOptions = options;
    await context.read<TrackerProvider>().updateTracker(widget.tracker);
    return options;
  }

  Widget _buildActionButtons(BuildContext context) {
    final trackerProvider = context.read<TrackerProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Action-only utilities (e.g. Rhys the Redeemed) have no tracker value,
    // so they skip the +/- buttons entirely. The action still shrink-wraps
    // its label, matching action buttons on other utilities.
    if (widget.tracker.actionOnly) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _buildTextActionButton(
          context,
          text: widget.tracker.actionButtonText ?? 'Action',
          onTap: _performAction,
          color: primaryColor,
          spacing: 0,
        ),
      );
    }

    // Calculate button count: +/- buttons, plus optional action button(s)
    final int buttonCount = widget.tracker.actionType == 'cathars_crusade'
        ? 4 // -, +, Quick +1, Resolve All
        : (widget.tracker.hasAction ? 3 : 2); // -, +, [optional Action]

    return LayoutBuilder(
      builder: (context, constraints) {
        const double buttonInternalWidth =
            UIConstants.actionButtonInternalWidth;
        final double totalButtonWidth = buttonCount * buttonInternalWidth;
        final double availableSpacingWidth =
            constraints.maxWidth - totalButtonWidth;
        final double spacing = buttonCount > 1
            ? (availableSpacingWidth / (buttonCount - 1)).clamp(
                UIConstants.minButtonSpacing,
                UIConstants.maxButtonSpacing,
              )
            : 0.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Decrement button
            _buildActionButton(
              context,
              icon: Icons.remove,
              onTap: () async {
                if (!await _requestCollapse() || !mounted) return;
                widget.tracker.decrement(widget.tracker.tapIncrement);
                await trackerProvider.updateTracker(widget.tracker);
              },
              onLongPress: () async {
                if (!await _requestCollapse() || !mounted) return;
                widget.tracker.decrement(widget.tracker.longPressIncrement);
                await trackerProvider.updateTracker(widget.tracker);
              },
              color: primaryColor,
              spacing: spacing,
            ),

            // Increment button
            _buildActionButton(
              context,
              icon: Icons.add,
              onTap: () async {
                if (!await _requestCollapse() || !mounted) return;
                widget.tracker.increment(widget.tracker.tapIncrement);
                await trackerProvider.updateTracker(widget.tracker);
              },
              onLongPress: () async {
                if (!await _requestCollapse() || !mounted) return;
                widget.tracker.increment(widget.tracker.longPressIncrement);
                await trackerProvider.updateTracker(widget.tracker);
              },
              color: primaryColor,
              spacing: widget.tracker.hasAction
                  ? spacing
                  : 0, // Spacing if action button follows
            ),

            // Action buttons (conditional)
            if (widget.tracker.hasAction &&
                widget.tracker.actionType == 'cathars_crusade') ...[
              // Quick +1 button for Cathar's Crusade (icon + text)
              _buildIconTextActionButton(
                context,
                icon: Icons.trending_up,
                text: 'x1',
                onTap: _performQuickPlusOne,
                color: primaryColor,
                spacing: spacing,
              ),
              // Resolve All button
              _buildTextActionButton(
                context,
                text: widget.tracker.actionButtonText ?? 'Action',
                onTap: _performAction,
                color: primaryColor,
                spacing: 0, // Last button gets no spacing
              ),
            ] else if (widget.tracker.hasAction)
              _buildTextActionButton(
                context,
                text: widget.tracker.actionButtonText ?? 'Action',
                onTap: _performAction,
                color: primaryColor,
                spacing: 0, // Last button gets no spacing
              ),
          ],
        );
      },
    );
  }

  Widget _buildValueDisplay(BuildContext context) {
    if (_editingValue) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, maxWidth: 112),
        child: TextField(
          controller: _valueController,
          focusNode: _valueFocusNode,
          autofocus: false,
          keyboardType: const TextInputType.numberWithOptions(signed: false),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          decoration: const InputDecoration(
            isDense: true,
            filled: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitValue(),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.isExpanded ? _beginValueEdit : widget.onExpand,
      child: BackgroundText(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '${widget.tracker.currentValue}',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _beginValueEdit() async {
    if (_editingValue) return;
    if (!await _commitName() || !await _commitDescription() || !mounted) return;
    _valueBeforeEdit = widget.tracker.currentValue;
    _valueController.text = '${widget.tracker.currentValue}';
    setState(() => _editingValue = true);
    widget.onEditingChanged(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _valueFocusNode.requestFocus();
      _valueController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _valueController.text.length,
      );
    });
  }

  Future<bool> _commitValue() {
    return _valueCommit ??= _commitValueOnce().whenComplete(() {
      _valueCommit = null;
    });
  }

  Future<bool> _commitValueOnce() async {
    if (!_editingValue) return true;
    if (_committingValue) return false;
    final parsed = int.tryParse(_valueController.text.trim());
    if (parsed == null || parsed < 0) {
      if (mounted) {
        final original = _valueBeforeEdit ?? widget.tracker.currentValue;
        widget.tracker.currentValue = original;
        _valueController.text = '$original';
        setState(() => _editingValue = false);
        widget.onEditingChanged(false);
      }
      _valueBeforeEdit = null;
      return true;
    }
    final previous = widget.tracker.currentValue;
    _committingValue = true;
    widget.tracker.currentValue = parsed;
    try {
      await context.read<TrackerProvider>().updateTracker(widget.tracker);
      if (mounted) setState(() => _editingValue = false);
      widget.onEditingChanged(false);
      _valueBeforeEdit = null;
      return true;
    } catch (_) {
      widget.tracker.currentValue = previous;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utility value could not be saved.')),
        );
        _valueFocusNode.requestFocus();
      }
      return false;
    } finally {
      _committingValue = false;
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color color,
    required double spacing,
  }) {
    final buttonBackgroundColor =
        Theme.of(context).cardColor.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(UIConstants.actionButtonPadding),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius:
                BorderRadius.circular(UIConstants.actionButtonBorderRadius),
            border: Border.all(
              color: color,
              width: UIConstants.actionButtonBorderWidth,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: UIConstants.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildTextActionButton(
    BuildContext context, {
    required String text,
    required VoidCallback? onTap,
    required Color color,
    required double spacing,
  }) {
    final buttonBackgroundColor =
        Theme.of(context).cardColor.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.actionButtonPadding + 2,
            vertical: UIConstants.actionButtonPadding,
          ),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius:
                BorderRadius.circular(UIConstants.actionButtonBorderRadius),
            border: Border.all(
              color: color,
              width: UIConstants.actionButtonBorderWidth,
            ),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconTextActionButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
    required Color color,
    required double spacing,
  }) {
    final buttonBackgroundColor =
        Theme.of(context).cardColor.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.actionButtonPadding + 2,
            vertical: UIConstants.actionButtonPadding,
          ),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius:
                BorderRadius.circular(UIConstants.actionButtonBorderRadius),
            border: Border.all(
              color: color,
              width: UIConstants.actionButtonBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performAction() async {
    final actionContext = context;
    if (!await _requestCollapse() || !actionContext.mounted) return;
    final actionType = widget.tracker.actionType;

    if (actionType == null) return;

    switch (actionType) {
      case 'krenko_mob_boss':
        _performKrenkoMobBossAction(actionContext);
        break;
      case 'krenko_tin_street':
        _performKrenkoTinStreetAction(actionContext);
        break;
      case 'cathars_crusade':
        _performCatharsCrusadeAction(actionContext);
        break;
      case 'academy_manufactor':
        _performAcademyManufactorAction(actionContext);
        break;
      case 'hare_apparent':
        _performHareApparentAction(actionContext);
        break;
      case 'rhys_the_redeemed':
        _performRhysTheRedeemedAction(actionContext);
        break;
      case 'brudiclad_telchor_engineer':
        _performBrudicladAction(actionContext);
        break;
      default:
        break;
    }
  }

  Future<void> _performBrudicladAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final rulesProvider = context.read<RulesProvider>();
    final trackerProvider = this.context.read<TrackerProvider>();
    final toggleProvider = this.context.read<ToggleProvider>();

    final parts = GameConstants.phyrexianMyrCompositeId.split('|');
    final results = rulesProvider.evaluateRules(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      1,
    );

    final unchangedMyr = results.length == 1 &&
        results.first.compositeId == GameConstants.phyrexianMyrCompositeId &&
        results.first.quantity == 1;
    if (!unchangedMyr) {
      final continueFlow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Brudiclad, Telchor Engineer'),
          content: Text(
            'The trigger will create:\n\n'
            '${TokenCreationResult.breakdownString(results)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (continueFlow != true || !context.mounted) return;
    }

    final tokenDatabase = TokenDatabase();
    await tokenDatabase.loadTokens();
    final virtualResults = <Item>[];
    for (final result in results) {
      if (result.quantity <= 0) continue;
      final artwork = TokenResultArtworkResolver.resolve(
        result: result,
        tokenDatabase: tokenDatabase,
      );
      virtualResults.add(Item(
        name: result.name,
        pt: result.pt,
        colors: result.colors,
        type: result.type,
        abilities: result.abilities,
        amount: result.quantity,
        artworkUrl: artwork.url,
        artworkSet: artwork.set,
        artworkOptions: artwork.options,
        order: double.maxFinite,
      ));
    }
    final virtualBoard = [...tokenProvider.items, ...virtualResults];
    final definitions =
        BrudicladTransformPlanner.definitionsOnBoard(virtualBoard);
    final stepOnePickerIds = <String>{};
    for (final item in virtualResults) {
      final resultDefinitions =
          BrudicladTransformPlanner.definitionsOnBoard([item]);
      if (resultDefinitions.isNotEmpty) {
        stepOnePickerIds.add(resultDefinitions.first.pickerId);
      }
    }
    definitions.sort((a, b) {
      final aStepOne = stepOnePickerIds.contains(a.pickerId);
      final bStepOne = stepOnePickerIds.contains(b.pickerId);
      if (aStepOne == bStepOne) return 0;
      return aStepOne ? -1 : 1;
    });

    if (!context.mounted) {
      tokenDatabase.dispose();
      return;
    }
    final selection = await _showBrudicladPicker(
      context,
      definitions: definitions,
      virtualBoard: virtualBoard,
      stepOnePickerIds: stepOnePickerIds,
    );
    if (selection == null || selection.cancelled) {
      tokenDatabase.dispose();
      return;
    }

    final snapshot = BoardUndoSnapshot.capture();
    try {
      final allOrders = <double>[
        ...tokenProvider.items.map((item) => item.order),
        ...trackerProvider.trackers.map((tracker) => tracker.order),
        ...toggleProvider.toggles.map((toggle) => toggle.order),
      ];
      final maxOrder =
          allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
      await TokenCreationService.createAllFromResults(
        results: results,
        tokenProvider: tokenProvider,
        summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
        insertionOrder: maxOrder.floor() + 1.0,
        tokenDatabase: tokenDatabase,
      );

      if (selection.skipped) {
        await tokenProvider.clearCreatureTokenSickness();
      } else {
        final plan = BrudicladTransformPlanner.build(
          items: tokenProvider.items,
          chosen: selection.definition!,
        );
        await tokenProvider.performBrudicladTransform(plan);
      }
    } catch (_) {
      await snapshot.restore();
      rethrow;
    } finally {
      tokenDatabase.dispose();
    }

    if (!context.mounted || selection.skipped) return;
    final undo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tokens Modified'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Undo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (undo == true) await snapshot.restore();
  }

  Future<_BrudicladSelection?> _showBrudicladPicker(
    BuildContext context, {
    required List<BrudicladTokenDefinition> definitions,
    required List<Item> virtualBoard,
    required Set<String> stepOnePickerIds,
  }) async {
    BrudicladTokenDefinition? selected;
    for (final definition in definitions) {
      final url = definition.artworkUrl;
      if (url != null && !url.startsWith('file://')) {
        ArtworkManager.downloadArtwork(url).catchError((_) => null);
      }
    }

    return showModalBottomSheet<_BrudicladSelection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final plan = selected == null
              ? null
              : BrudicladTransformPlanner.build(
                  items: virtualBoard,
                  chosen: selected!,
                );
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.86,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Choose a token',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: definitions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final definition = definitions[index];
                        final isStepOne =
                            stepOnePickerIds.contains(definition.pickerId);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isStepOne)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('Created by this trigger',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium),
                              ),
                            DefinitionPreviewCard(
                              artworkUrl: definition.artworkUrl,
                              colorIdentity: definition.colors,
                              name:
                                  '${definition.name} ×${definition.totalTokens}',
                              subtitle: definition.abilities,
                              trailing:
                                  definition.pt.isEmpty ? null : definition.pt,
                              selected:
                                  selected?.pickerId == definition.pickerId,
                              onTap: () =>
                                  setSheetState(() => selected = definition),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (plan != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_countedNoun(plan.affectedStacks, 'stack')} '
                          '(${_countedNoun(plan.affectedTokens, 'token')}) become copies of '
                          '${plan.chosen.name}${plan.chosen.pt.isEmpty ? '' : ' ${plan.chosen.pt}'}\n'
                          '${_countedNoun(plan.separateStacks, 'stack')} with counters '
                          '${plan.separateStacks == 1 ? 'stays' : 'stay'} separate\n'
                          'Tapped status and counters are preserved',
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(
                              sheetContext, const _BrudicladSelection.skip()),
                          child: const Text('Skip'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(sheetContext,
                                  _BrudicladSelection.resolve(selected!)),
                          child: const Text('Resolve'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _countedNoun(int count, String singular) =>
      '$count ${count == 1 ? singular : '${singular}s'}';

  Future<void> _performRhysTheRedeemedAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final rulesProvider = context.read<RulesProvider>();
    final trackerProvider = this.context.read<TrackerProvider>();
    final toggleProvider = this.context.read<ToggleProvider>();

    // Rhys's second ability: "For each creature token you control, create a
    // token that's a copy of that creature." Every eligible stack is snapshot
    // and evaluated independently, so copies made by a previous activation are
    // themselves copied by the next one.
    final tokenDatabase = TokenDatabase();
    await tokenDatabase.loadTokens();

    final RhysCopyPlan plan;
    try {
      plan = RhysCopyPlanner.build(
        items: tokenProvider.items,
        boardOrders: [
          ...tokenProvider.items.map((item) => item.order),
          ...trackerProvider.trackers.map((tracker) => tracker.order),
          ...toggleProvider.toggles.map((toggle) => toggle.order),
        ],
        rulesProvider: rulesProvider,
        tokenDatabase: tokenDatabase,
      );
    } finally {
      tokenDatabase.dispose();
    }

    if (!context.mounted) return;

    // The SAME [plan] backs both the preview below and the board mutation, so
    // the confirmation cannot diverge from what is actually created.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rhys the Redeemed'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.isEmpty
                    ? 'No creature tokens on the board — nothing will be created.'
                    : 'Copying every creature token you control:',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final group in plan.groups)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${group.source.name} ×${group.source.amount}',
                                    style: Theme.of(dialogContext)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _rhysBreakdown(group.results),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(dialogContext)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Text(
                  'Total: ${plan.totalTokens} token${plan.totalTokens == 1 ? '' : 's'}',
                  style:
                      Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                ),
              ],
              if (plan.wasCapped) ...[
                const SizedBox(height: 8),
                Text(
                  'Quantity capped at ${GameConstants.maxTokenQuantity}.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Copy Tokens'),
          ),
        ],
      ),
    );

    // Confirming an empty plan is a successful no-op.
    if (confirmed != true) return;

    await tokenProvider.performRhysPopulate(
      plan,
      settingsProvider.summoningSicknessEnabled,
    );
  }

  /// Consolidates a group's results by token identity for the preview line,
  /// so companions read as "3× Elf Warrior, 3× Squirrel" rather than
  /// one fragment per rules trigger.
  String _rhysBreakdown(List<RhysCopyResult> results) {
    final order = <String>[];
    final totals = <String, int>{};
    final names = <String, String>{};

    for (final result in results) {
      final id = result.compositeId;
      if (!totals.containsKey(id)) {
        order.add(id);
        names[id] = result.name;
        totals[id] = 0;
      }
      totals[id] = totals[id]! + result.quantity;
    }

    return order.map((id) => '${totals[id]}× ${names[id]}').join(', ');
  }

  Future<void> _performHareApparentAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final rulesProvider = context.read<RulesProvider>();

    // The user controls the Hare Apparent count manually via the stepper.
    // When a new Hare Apparent enters, its ETB creates a number of 1/1 white
    // Rabbits equal to the number of *other* Hare Apparents you control.
    final hareCount = widget.tracker.currentValue;
    final rabbitsToCreate = hareCount - 1;

    if (rabbitsToCreate <= 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hare Apparent'),
          content: const Text(
            'A new Hare Apparent makes 1 Rabbit for each other Hare Apparent '
            'you control. With 1 or fewer Hare Apparents, no Rabbits are '
            'created.\n\nUse the +/\u2212 buttons to set how many Hare '
            'Apparents you control before pressing Make Rabbits.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Evaluate rules so Token Doublers / Doubling Season / Anointed Procession
    // / Chatterfang / etc. layer on via the rules engine. The SAME [results]
    // list is reused for the preview and the actual creation below so the
    // confirmation cannot diverge from what is created.
    final results = rulesProvider.evaluateRules(
      'Rabbit',
      '1/1',
      'W',
      'Creature \u2014 Rabbit',
      '',
      rabbitsToCreate,
    );
    final rabbitsAfterRules = results.first.quantity;
    // Consolidate identical token identities for the breakdown line so
    // companions (e.g. Chatterfang Squirrels) are reflected, not just the
    // primary Rabbit count (display-only \u2014 creation uses the full list).
    final displayResults = TokenCreationResult.aggregateForDisplay(results);
    final breakdownLine = displayResults.length > 1
        ? displayResults.map((r) => '${r.quantity}\u00d7 ${r.name}').join(', ')
        : '$rabbitsAfterRules rabbits';
    final confirmLabel = displayResults.length > 1
        ? 'Create Tokens'
        : 'Create $rabbitsAfterRules Rabbits';
    final wasCapped = results.any((r) => r.wasCapped);

    // Show confirmation dialog (mirrors Krenko's Make Goblins flow)
    final shouldCreate = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Rabbit Tokens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on other Hare Apparents you control ($rabbitsToCreate):',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              breakdownLine,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (wasCapped) ...[
              const SizedBox(height: 8),
              Text(
                'Quantity capped at ${GameConstants.maxTokenQuantity}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, rabbitsAfterRules),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (shouldCreate == null || !mounted) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = this.context.read<TrackerProvider>();
    final toggleProvider = this.context.read<ToggleProvider>();
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder =
        allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    final nextOrder = maxOrder.floor() + 1.0;

    // Create rabbits (plus any companions from rules) as peer results
    final tokenDatabase = TokenDatabase();
    try {
      await tokenDatabase.loadTokens();
      await TokenCreationService.createAllFromResults(
        results: results,
        tokenProvider: tokenProvider,
        summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
        insertionOrder: nextOrder,
        tokenDatabase: tokenDatabase,
      );
    } finally {
      tokenDatabase.dispose();
    }
  }

  Future<void> _performKrenkoMobBossAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final rulesProvider = context.read<RulesProvider>();

    // Count existing goblin tokens
    int tokenGoblinCount = 0;
    for (final item in tokenProvider.items) {
      final type = item.type.toLowerCase();
      if (type.contains('goblin')) {
        tokenGoblinCount += item.amount;
      }
    }

    // Calculate goblin creation amounts via rules engine
    final nontokenGoblins = widget.tracker.currentValue;
    final totalGoblins = tokenGoblinCount + nontokenGoblins;
    // Evaluate rules on goblin token creation. The SAME [results] list backs
    // both the preview here and the creation below (createKrenkoGoblins for
    // results.first + createCompanionTokens for the rest), so the confirmation
    // cannot diverge from what is actually created.
    final results = rulesProvider.evaluateRules(
        'Goblin', '1/1', 'R', 'Creature Token \u2014 Goblin', '', totalGoblins);
    final byTotalGoblins = results.first.quantity;
    // Consolidate identical token identities for the breakdown line so
    // companions (e.g. Chatterfang Squirrels) are reflected, not just the
    // primary Goblin count (display-only \u2014 creation uses the full list).
    final displayResults = TokenCreationResult.aggregateForDisplay(results);
    final breakdownLine = displayResults.length > 1
        ? displayResults.map((r) => '${r.quantity}\u00d7 ${r.name}').join(', ')
        : '$byTotalGoblins goblins';
    final confirmLabel = displayResults.length > 1
        ? 'Create Tokens'
        : 'Create $byTotalGoblins Goblins';
    final wasCapped = results.any((r) => r.wasCapped);

    // Show dialog to choose which calculation to use
    final shouldCreate = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Goblin Tokens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on all goblins controlled ($totalGoblins):',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              breakdownLine,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (wasCapped) ...[
              const SizedBox(height: 8),
              Text(
                'Quantity capped at ${GameConstants.maxTokenQuantity}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, byTotalGoblins),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (shouldCreate == null || !mounted) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = this.context.read<TrackerProvider>();
    final toggleProvider = this.context.read<ToggleProvider>();
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder =
        allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    double nextOrder = maxOrder.floor() + 1.0;

    // Create goblin tokens using TokenProvider (primary result)
    await tokenProvider.createKrenkoGoblins(
        shouldCreate, settingsProvider.summoningSicknessEnabled, nextOrder);
    nextOrder += 1.0;

    // Create companion tokens from rules via shared service
    if (results.length > 1) {
      final tokenDatabase = TokenDatabase();
      try {
        await tokenDatabase.loadTokens();
        await TokenCreationService.createCompanionTokens(
          results: results,
          tokenProvider: tokenProvider,
          summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
          insertionOrder: nextOrder,
          tokenDatabase: tokenDatabase,
        );
      } finally {
        tokenDatabase.dispose();
      }
    }
  }

  Future<void> _performKrenkoTinStreetAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final rulesProvider = context.read<RulesProvider>();

    // Calculate goblin creation amount based on Krenko's power, via rules engine
    final krenkoPower = widget.tracker.currentValue;
    final results = rulesProvider.evaluateRules(
        'Goblin', '1/1', 'R', 'Creature Token \u2014 Goblin', '', krenkoPower);
    final goblinsToCreate = results.first.quantity;

    // Show dialog
    final shouldCreate = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Goblin Tokens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Based on Krenko's power ($krenkoPower):",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$goblinsToCreate goblins',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, goblinsToCreate),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Create $goblinsToCreate Goblins'),
          ),
        ],
      ),
    );

    if (shouldCreate == null || !mounted) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = this.context.read<TrackerProvider>();
    final toggleProvider = this.context.read<ToggleProvider>();
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder =
        allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    double nextOrder = maxOrder.floor() + 1.0;

    // Create goblin tokens using TokenProvider (primary result)
    await tokenProvider.createKrenkoGoblins(
        shouldCreate, settingsProvider.summoningSicknessEnabled, nextOrder);
    nextOrder += 1.0;

    // Create companion tokens from rules via shared service
    if (results.length > 1) {
      final tokenDatabase = TokenDatabase();
      try {
        await tokenDatabase.loadTokens();
        await TokenCreationService.createCompanionTokens(
          results: results,
          tokenProvider: tokenProvider,
          summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
          insertionOrder: nextOrder,
          tokenDatabase: tokenDatabase,
        );
      } finally {
        tokenDatabase.dispose();
      }
    }
  }

  Future<void> _performCatharsCrusadeAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final rulesProvider = context.read<RulesProvider>();
    final triggerCount = widget.tracker.currentValue;

    if (triggerCount <= 0) {
      // No triggers to resolve
      return;
    }

    // Calculate final counter amount via rules engine
    final finalCounterAmount =
        rulesProvider.calculateCounterAmount(triggerCount, isPlusOne: true);

    // Show confirmation dialog
    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cathar's Crusade"),
        content: Text(
          'Pressing confirm will add $finalCounterAmount +1/+1 counter${finalCounterAmount == 1 ? '' : 's'} '
          'to all creatures.'
          '${finalCounterAmount != triggerCount ? '\n($triggerCount triggers \u00d7 counter modifiers)' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldResolve != true) return;

    // Get all tokens on board
    final allTokens = tokenProvider.items;

    // Add counters to all creatures (tokens with P/T) — finalCounterAmount already includes counter modifiers
    for (var token in allTokens) {
      if (token.hasPowerToughness) {
        token.plusOneCounters += finalCounterAmount;
        await token.save();
      }
    }

    // Reset Cathar's counter to 0
    widget.tracker.currentValue = 0;
    await widget.tracker.save();
  }

  Future<void> _performQuickPlusOne() async {
    final actionContext = context;
    if (!await _requestCollapse() || !actionContext.mounted) return;
    final tokenProvider = actionContext.read<TokenProvider>();
    final rulesProvider = actionContext.read<RulesProvider>();

    // Calculate counter amount via rules engine
    final amount = rulesProvider.calculateCounterAmount(1, isPlusOne: true);

    // Get all tokens on board
    final allTokens = tokenProvider.items;

    // Add +1/+1 counter to all creatures
    for (var token in allTokens) {
      if (token.hasPowerToughness) {
        token.plusOneCounters += amount;
        await token.save();
      }
    }

    // Note: We DON'T reset the Cathar's counter - keep accumulating triggers
  }

  Future<void> _performAcademyManufactorAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final rulesProvider = context.read<RulesProvider>();

    // Number of Academy Manufactor copies
    final manufactorCount = widget.tracker.currentValue;

    // At 0 copies, action is disabled
    if (manufactorCount <= 0) return;

    // Evaluate rules to preview what will be created from a Food token.
    // The AM utility card represents physical Academy Manufactor copies on
    // the battlefield, so it FORCES the AM expansion at its own count
    // (`forceAcademyManufactorCount`) independent of the rules-calculator AM
    // preset — pressing it must always yield the full Food + Treasure + Clue
    // set scaled by the utility's count, with any active doublers/presets/
    // custom rules layered on by the engine. The SAME [results] list is reused
    // for the preview and the actual creation below, so they cannot diverge.
    // Use the real database type 'Artifact — Food' so token_type trigger matches.
    final foodParts = GameConstants.foodCompositeId.split('|');
    final results = rulesProvider.evaluateRules(
      foodParts[0],
      foodParts[1],
      foodParts[2],
      foodParts[3],
      foodParts[4],
      1,
      forceAcademyManufactorCount: manufactorCount,
    );
    final totalPerType = results.fold<int>(0, (sum, r) => sum + r.quantity);
    // Consolidate identical token identities for the breakdown line
    // (display-only — actual creation still uses the full result list).
    final displayResults = TokenCreationResult.aggregateForDisplay(results);
    final breakdownLine = displayResults.length > 1
        ? displayResults.map((r) => '${r.quantity}× ${r.name}').join(', ')
        : '$totalPerType tokens';

    // Show confirmation dialog with breakdown
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Academy Manufactor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creating $breakdownLine',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Academy Manufactors \u2014 $manufactorCount',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldCreate != true || !mounted) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = this.context.read<TrackerProvider>();
    final toggleProvider = this.context.read<ToggleProvider>();
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder =
        allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    double nextOrder = maxOrder.floor() + 1.0;

    // Create all tokens from rules results via shared service
    // Academy Manufactor has no distinct "primary" — all results are peers
    final tokenDatabase = TokenDatabase();
    try {
      await tokenDatabase.loadTokens();
      await TokenCreationService.createAllFromResults(
        results: results,
        tokenProvider: tokenProvider,
        summoningSicknessEnabled:
            false, // Artifact tokens (Food/Treasure/Clue) have no P/T
        insertionOrder: nextOrder,
        tokenDatabase: tokenDatabase,
      );
    } finally {
      tokenDatabase.dispose();
    }
  }

  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.tracker.colorIdentity,
        isEmblem: false);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }

  Widget _buildConditionalGradient(BuildContext context) {
    return Positioned.fill(
      child: FutureBuilder<File?>(
        future:
            _cachedArtworkFuture, // Use cached Future (prevents flicker on rebuild)
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null) {
            final gradient = ColorUtils.gradientForColors(
                widget.tracker.colorIdentity,
                isEmblem: false);
            return Container(
              decoration: BoxDecoration(gradient: gradient),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

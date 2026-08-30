import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../controllers/token_edit_session.dart';
import '../controllers/expandable_card_controller.dart';
import '../database/token_database.dart';
import '../models/item.dart';
import '../models/token_definition.dart';
import '../providers/settings_provider.dart';
import '../providers/toggle_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/token_provider.dart';
import '../providers/rules_provider.dart';
import '../screens/counter_search_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_metadata_enricher.dart';
import '../utils/color_utils.dart';
import 'common/background_text.dart';
import 'counter_pill.dart';
import 'inline_token_edit_field.dart';
import 'inline_color_identity_bar.dart';
import 'artwork_selection_sheet.dart';
import 'split_stack_sheet.dart';
import 'token_counter_management_sheet.dart';
import 'token_status_sheet.dart';
// Unused import was causing build warnings
// import 'cropped_artwork_widget.dart';
import 'mixins/artwork_display_mixin.dart';
import '../services/token_creation_service.dart';
import '../services/token_merge_compatibility.dart';
import '../services/token_result_artwork_resolver.dart';
import '../services/board_order_service.dart';
import 'multiplier_view.dart';
import 'mana/mana_text.dart';
import 'mana/mana_icons.dart';

/// Animated widget that pops when P/T changes (from counter addition)
class _AnimatedPowerToughness extends StatefulWidget {
  final String powerToughness;
  final TextStyle? style;
  final EdgeInsets padding;
  final Color backgroundColor;

  const _AnimatedPowerToughness({
    required this.powerToughness,
    required this.style,
    required this.padding,
    required this.backgroundColor,
  });

  @override
  State<_AnimatedPowerToughness> createState() =>
      _AnimatedPowerToughnessState();
}

class _AnimatedPowerToughnessState extends State<_AnimatedPowerToughness>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String? _previousPowerToughness;

  @override
  void initState() {
    super.initState();
    _previousPowerToughness = widget.powerToughness;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Scale from 1.0 → 1.5 → 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_AnimatedPowerToughness oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation when P/T changes
    if (widget.powerToughness != _previousPowerToughness) {
      _previousPowerToughness = widget.powerToughness;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.powerToughness,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

class TokenCard extends StatefulWidget {
  final Item item;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<bool> onEditingChanged;
  final ExpandableCardController? controller;

  const TokenCard({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onExpand,
    required this.onCollapse,
    required this.onEditingChanged,
    this.controller,
  });

  @override
  State<TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<TokenCard>
    with SingleTickerProviderStateMixin, ArtworkDisplayMixin {
  static const double _identityRailWidth = 7;
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;
  TokenEditSession? _editSession;
  bool _reportedEditing = false;
  double? _artworkRevealHeight;
  late final AnimationController _artworkCenterController;
  late final CurvedAnimation _artworkCenterProgress;

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
    widget.controller?.attach(_requestCollapse);
  }

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
  String? get artworkUrl => widget.item.artworkUrl;

  @override
  void clearArtwork() {
    // Batch clear all artwork fields in a single Hive write
    widget.item.updateArtwork(url: null, set: null, options: null);
  }

  @override
  void didUpdateWidget(TokenCard oldWidget) {
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
    }
    // Reset cleanup flag if artwork URL changed (e.g., user removed then re-added artwork)
    if (oldWidget.item.artworkUrl != widget.item.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
    if (oldWidget.isExpanded && !widget.isExpanded) {
      final renderBox = context.findRenderObject();
      if (renderBox is RenderBox && renderBox.hasSize) {
        _artworkRevealHeight = renderBox.size.height;
      }
      _artworkCenterController
        ..duration = const Duration(milliseconds: 240)
        ..forward(from: 0);
      _editSession?.commitActive();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _editSession ??= TokenEditSession(
      item: widget.item,
      tokenProvider: context.read<TokenProvider>(),
    )..addListener(_handleEditSessionChanged);
  }

  void _handleEditSessionChanged() {
    final editing = _editSession?.isEditing ?? false;
    if (_reportedEditing == editing) return;
    _reportedEditing = editing;
    widget.onEditingChanged(editing);
  }

  @override
  void dispose() {
    _artworkCenterProgress.dispose();
    _artworkCenterController.dispose();
    widget.controller?.detach(_requestCollapse);
    _editSession
      ?..removeListener(_handleEditSessionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when summoningSicknessEnabled or artworkDisplayStyle changes
    // This prevents rebuilds when multiplier changes
    return Selector<SettingsProvider, (bool, String)>(
      selector: (context, settings) =>
          (settings.summoningSicknessEnabled, settings.artworkDisplayStyle),
      builder: (context, settingsData, child) {
        final summoningSicknessEnabled = settingsData.$1;
        final artworkDisplayStyle = settingsData.$2;
        return Semantics(
          button: true,
          expanded: widget.isExpanded,
          label: widget.isExpanded
              ? 'Expanded token details for ${widget.item.name}'
              : 'Token ${widget.item.name}',
          hint: widget.isExpanded
              ? 'Double tap blank space to collapse'
              : 'Double tap to expand details',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.isExpanded ? _collapseAfterCommit : widget.onExpand,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 380),
              reverseDuration: const Duration(milliseconds: 240),
              curve: const Cubic(0.18, 0.89, 0.32, 1.08),
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: widget.item.amount == 0 ? 0.5 : 1.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Base card background layer (ensures left side is solid in fadeout mode)
                        // Uses borderRadius - borderWidth to fit inside the gradient border
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                          ),
                        ),

                        // Gradient background layer (Custom Artwork Feature)
                        // Shows immediately as placeholder while artwork loads, or permanently for artless tokens
                        if (widget.item.artworkUrl == null ||
                            widget.item.artworkUrl!.isEmpty ||
                            widget.isExpanded)
                          _buildGradientLayer(context)
                        else
                          // Show gradient while artwork is loading
                          _buildConditionalGradient(context),

                        // Artwork layer (appears on top of gradient when file is available)
                        if (widget.item.artworkUrl != null)
                          buildArtworkLayer(
                            context: context,
                            constraints: constraints,
                            artworkDisplayStyle: artworkDisplayStyle,
                            cornerRadius: 0,
                            revealViewportHeight: _artworkRevealHeight,
                            revealProgress: _artworkCenterProgress,
                          ),

                        // Content layer (all existing UI elements)
                        Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(
                            UIConstants.cardPadding + _identityRailWidth,
                            UIConstants.cardPadding,
                            UIConstants.cardPadding,
                            UIConstants.cardPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTopRow(context, summoningSicknessEnabled),

                              // Counter pills
                              if (widget.isExpanded ||
                                  widget.item.counters.isNotEmpty ||
                                  widget.item.plusOneCounters > 0 ||
                                  widget.item.minusOneCounters > 0 ||
                                  widget.item.plusOnePowerCounters > 0 ||
                                  widget.item.plusOneToughnessCounters > 0) ...[
                                const SizedBox(
                                    height: UIConstants.mediumSpacing),
                                _buildCounterRegion(context),
                              ],

                              // Type, Abilities, and P/T - combined section (condensed layout)
                              if (widget.isExpanded ||
                                  (widget.item.type.isNotEmpty &&
                                      !widget.item.isEmblem) ||
                                  widget.item.abilities.isNotEmpty ||
                                  (!widget.item.isEmblem &&
                                      widget.item.pt.isNotEmpty)) ...[
                                const SizedBox(
                                    height: UIConstants.mediumSpacing),
                                Padding(
                                  padding:
                                      EdgeInsets.only(right: kIsWeb ? 40 : 0),
                                  // Use Column layout if formatted P/T is too long (>= 8 chars like "1000/1000")
                                  child: widget.isExpanded
                                      ? _buildExpandedDetails(
                                          context, widget.item)
                                      : (!widget.item.isEmblem &&
                                              widget.item.pt.isNotEmpty &&
                                              widget
                                                      .item
                                                      .formattedPowerToughness
                                                      .length >=
                                                  8)
                                          ? _buildStackedTypeAbilitiesAndPT(
                                              context, widget.item)
                                          : _buildInlineTypeAbilitiesAndPT(
                                              context, widget.item),
                                ),
                              ],

                              const SizedBox(height: UIConstants.mediumSpacing),

                              // Button Row (centered)
                              _buildActionButtons(
                                  context, context.read<SettingsProvider>()),
                            ],
                          ),
                        ), // Close Container (content layer)

                        // A quiet, persistent identity marker replaces the
                        // former full perimeter border. Keep it above art
                        // and content surfaces so its color is never lost.
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _identityRailWidth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: ColorUtils.gradientForColors(
                                  widget.item.colors,
                                  isEmblem: widget.item.isEmblem,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ], // Close Stack children
                    ); // Close Stack
                  }, // Close LayoutBuilder builder
                ), // Close LayoutBuilder
              ), // Close Opacity
            ), // Close AnimatedSize
          ), // Close GestureDetector
        ); // Close Semantics
      }, // Close Selector builder
    ); // Close Selector
  }

  Future<void> _collapseAfterCommit() async {
    final saved = widget.controller == null
        ? await _requestCollapse()
        : await widget.controller!.requestCollapse();
    if (mounted && saved) widget.onCollapse();
  }

  Future<bool> _requestCollapse() async {
    final saved = await _editSession?.commitActive() ?? true;
    if (!saved && mounted) {
      final message = _editSession?.lastCommitError?.toString() ??
          'The edit could not be saved.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    return saved;
  }

  Widget _buildTopRow(BuildContext context, bool summoningSicknessEnabled) {
    final nameStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        );
    final renderedName = BackgroundText(
      child: Text(
        widget.item.name,
        style: nameStyle,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        textAlign: widget.item.isEmblem ? TextAlign.center : TextAlign.left,
      ),
    );

    final name = Expanded(
      child: Align(
        alignment:
            widget.item.isEmblem ? Alignment.center : Alignment.centerLeft,
        child: widget.isExpanded
            ? InlineTokenEditField(
                session: _editSession!,
                field: TokenEditableField.name,
                semanticLabel: 'Token name: ${widget.item.name}',
                editorStyle: nameStyle,
                editorDecoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  border: OutlineInputBorder(),
                ),
                readOnlyChild: renderedName,
              )
            : renderedName,
      ),
    );
    final status = _buildStatusSummary(context, summoningSicknessEnabled);
    return Row(
      children: [
        name,
        if (!widget.item.isEmblem || widget.isExpanded) ...[
          const SizedBox(width: UIConstants.verticalSpacing),
          status,
        ],
      ],
    );
  }

  Widget _buildStatusSummary(
      BuildContext context, bool summoningSicknessEnabled) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        );
    return Semantics(
      button: widget.isExpanded,
      label: widget.item.isEmblem
          ? 'Token status. ${widget.item.amount} total'
          : 'Token status. ${widget.item.amount} total, '
              '${widget.item.amount - widget.item.tapped} ready, '
              '${widget.item.tapped} tapped',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isExpanded ? _showStatusSheet : null,
        child: BackgroundText(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: widget.item.isEmblem
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers, size: UIConstants.iconSize),
                    const SizedBox(width: UIConstants.verticalSpacing),
                    Text('${widget.item.amount}', style: style),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.item.summoningSick > 0 &&
                        summoningSicknessEnabled) ...[
                      const Icon(ManaIcons.summoningSickness,
                          size: UIConstants.iconSize),
                      const SizedBox(width: UIConstants.verticalSpacing),
                      Text('${widget.item.summoningSick}', style: style),
                      const SizedBox(width: UIConstants.mediumSpacing),
                    ],
                    const Icon(Icons.mobile_friendly,
                        size: UIConstants.iconSize),
                    const SizedBox(width: UIConstants.verticalSpacing),
                    Text('${widget.item.amount - widget.item.tapped}',
                        style: style),
                    const SizedBox(width: UIConstants.mediumSpacing),
                    const Icon(ManaIcons.tap, size: UIConstants.iconSize),
                    const SizedBox(width: UIConstants.verticalSpacing),
                    Text('${widget.item.tapped}', style: style),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildColorIdentityButton(BuildContext context) {
    return InlineColorIdentityBar(
      colorIdentity: widget.item.colors,
      onToggle: _toggleColorIdentity,
    );
  }

  Future<void> _toggleColorIdentity(String symbol) async {
    final saved = await _editSession?.commitActive() ?? true;
    if (!saved || !mounted) return;

    final selected = widget.item.colors.characters.toSet();
    selected.contains(symbol) ? selected.remove(symbol) : selected.add(symbol);
    widget.item.colors = 'WUBRG'.characters.where(selected.contains).join();
    try {
      await context.read<TokenProvider>().updateItem(widget.item);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Color identity could not be saved.')),
      );
    }
  }

  Widget _buildExpandedIndicatorSurface(
    BuildContext context, {
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(UIConstants.smallBorderRadius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkIndicator(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.item.artworkUrl == null
          ? 'Choose token artwork'
          : 'Change token artwork',
      child: _buildExpandedIndicatorSurface(
        context,
        tooltip: widget.item.artworkUrl == null
            ? 'Choose artwork'
            : 'Change artwork',
        onTap: _showArtworkSelection,
        child: const Icon(Icons.image_outlined, size: UIConstants.iconSize),
      ),
    );
  }

  Widget _buildCounterAddButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add counter',
      child: Tooltip(
        message: 'Add counter',
        child: IconButton.filledTonal(
          onPressed: () => _showCounterManagement(context),
          icon: const Icon(Icons.add),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildExpandedCounterControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildColorIdentityButton(context),
        const SizedBox(width: UIConstants.verticalSpacing),
        _buildArtworkIndicator(context),
      ],
    );
  }

  Widget _buildExpandedCounterPills(
    BuildContext context,
    List<({String name, int amount})> entries,
    double maxWidth,
  ) {
    final visible = _entriesForTwoRows(
      entries,
      maxWidth,
      Directionality.of(context),
      MediaQuery.textScalerOf(context),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: UIConstants.verticalSpacing,
          runSpacing: UIConstants.verticalSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final pill in visible)
              Semantics(
                button: true,
                label: 'Manage token counter',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showCounterManagement(context),
                  child: pill,
                ),
              ),
            _buildCounterAddButton(context),
          ],
        ),
      ),
    );
  }

  List<({String name, int amount})> _counterEntries() => [
        ...widget.item.counters
            .map((counter) => (name: counter.name, amount: counter.amount)),
        if (widget.item.plusOneCounters > 0)
          (name: '+1/+1', amount: widget.item.plusOneCounters),
        if (widget.item.minusOneCounters > 0)
          (name: '-1/-1', amount: widget.item.minusOneCounters),
        if (widget.item.plusOnePowerCounters > 0)
          (name: '+1/+0', amount: widget.item.plusOnePowerCounters),
        if (widget.item.plusOneToughnessCounters > 0)
          (name: '+0/+1', amount: widget.item.plusOneToughnessCounters),
      ];

  Widget _buildCounterRegion(BuildContext context) {
    final entries = _counterEntries();
    if (!widget.isExpanded) {
      return Wrap(
        spacing: UIConstants.verticalSpacing,
        runSpacing: UIConstants.verticalSpacing,
        children: entries
            .map((entry) =>
                CounterPillView(name: entry.name, amount: entry.amount))
            .toList(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => _buildExpandedCounterPills(
        context,
        entries,
        constraints.maxWidth,
      ),
    );
  }

  List<Widget> _entriesForTwoRows(
    List<({String name, int amount})> entries,
    double maxWidth,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final widths = entries
        .map((entry) => _counterPillWidth(entry, direction, textScaler))
        .toList();
    if (_fitsInTwoRows(widths, maxWidth)) {
      return entries
          .map((entry) =>
              CounterPillView(name: entry.name, amount: entry.amount))
          .toList();
    }

    final overflowWidth = _counterOverflowWidth(direction, textScaler);
    var prefixLength = entries.length;
    while (prefixLength > 0 &&
        !_fitsInTwoRows(
            [...widths.take(prefixLength), overflowWidth], maxWidth)) {
      prefixLength--;
    }
    return [
      ...entries.take(prefixLength).map(
          (entry) => CounterPillView(name: entry.name, amount: entry.amount)),
      _buildCounterOverflowPill(),
    ];
  }

  bool _fitsInTwoRows(List<double> widths, double maxWidth) {
    var rows = 1;
    var used = 0.0;
    for (final width in widths) {
      final required =
          used == 0 ? width : used + UIConstants.verticalSpacing + width;
      if (required <= maxWidth) {
        used = required;
      } else {
        rows++;
        used = width;
        if (rows > 2 || width > maxWidth) return false;
      }
    }
    return true;
  }

  double _counterPillWidth(
    ({String name, int amount}) entry,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final namePainter = TextPainter(
      text: TextSpan(
        text: entry.name,
        style: const TextStyle(
          fontSize: UIConstants.counterPillFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    var width =
        namePainter.width + UIConstants.counterPillHorizontalPadding * 2;
    if (entry.amount > 1) {
      final amountPainter = TextPainter(
        text: TextSpan(
          text: '${entry.amount}',
          style: const TextStyle(
            fontSize: UIConstants.counterPillAmountFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: direction,
        textScaler: textScaler,
      )..layout();
      width += UIConstants.counterPillSpacing + amountPainter.width;
    }
    return width;
  }

  double _counterOverflowWidth(TextDirection direction, TextScaler textScaler) {
    final painter = TextPainter(
      text: const TextSpan(
        text: '…',
        style: TextStyle(
          fontSize: UIConstants.counterPillAmountFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    return painter.width + UIConstants.counterPillHorizontalPadding * 2;
  }

  Widget _buildCounterOverflowPill() => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.counterPillHorizontalPadding,
          vertical: UIConstants.counterPillVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.85),
          borderRadius:
              BorderRadius.circular(UIConstants.counterPillBorderRadius),
        ),
        child: const Text(
          '…',
          style: TextStyle(
            color: Colors.white,
            fontSize: UIConstants.counterPillAmountFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _buildExpandedDetails(BuildContext context, Item item) {
    final typeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color
              ?.withValues(alpha: 0.7),
        );
    final abilityStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineTokenEditField(
            session: _editSession!,
            field: TokenEditableField.type,
            semanticLabel: item.type.isEmpty
                ? 'Empty token type'
                : 'Token type: ${item.type}',
            editorStyle: typeStyle,
            editorConstraints: BoxConstraints(
              minWidth: constraints.maxWidth * 0.4,
              maxWidth: constraints.maxWidth * 0.72,
            ),
            editorDecoration: const InputDecoration(
              isDense: true,
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              border: OutlineInputBorder(),
            ),
            readOnlyChild: BackgroundText(
              child: Text(
                item.type.isEmpty ? 'Type' : item.type,
                style: typeStyle,
              ),
            ),
          ),
          const SizedBox(height: UIConstants.verticalSpacing),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.82,
              maxHeight: 112,
            ),
            child: InlineTokenEditField(
              session: _editSession!,
              field: TokenEditableField.abilities,
              semanticLabel: item.abilities.isEmpty
                  ? 'Empty abilities field'
                  : 'Token abilities',
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              editorStyle: abilityStyle,
              editorConstraints: BoxConstraints(
                minWidth: constraints.maxWidth * 0.5,
                maxWidth: constraints.maxWidth * 0.82,
                maxHeight: 112,
              ),
              editorDecoration: const InputDecoration(
                isDense: true,
                filled: true,
                alignLabelWithHint: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              readOnlyChild: BackgroundText(
                child: SingleChildScrollView(
                  child: item.abilities.isEmpty
                      ? Text(
                          'Abilities',
                          style: abilityStyle?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: abilityStyle.color?.withValues(alpha: 0.55),
                          ),
                        )
                      : ManaText(item.abilities, style: abilityStyle),
                ),
              ),
            ),
          ),
          const SizedBox(height: UIConstants.verticalSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildExpandedCounterControls(context),
              const Spacer(),
              if (!item.isEmblem)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: InlineTokenEditField(
                    session: _editSession!,
                    field: TokenEditableField.powerToughness,
                    semanticLabel: item.pt.isEmpty
                        ? 'Empty base power and toughness'
                        : 'Base power and toughness: ${item.pt}',
                    textAlign: TextAlign.right,
                    editorConstraints:
                        const BoxConstraints(minWidth: 76, maxWidth: 120),
                    editorStyle: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    editorDecoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      border: OutlineInputBorder(),
                    ),
                    readOnlyChild: item.pt.isEmpty
                        ? BackgroundText(
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ManaIcons.power,
                                    size: 28,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.55),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: Text(
                                      '/',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.55),
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    ManaIcons.toughness,
                                    size: 28,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.55),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildPTWidget(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCounterManagement(BuildContext context) async {
    final saved = await _editSession?.commitActive() ?? true;
    if (!saved || !context.mounted) return;
    final result = await TokenCounterManagementSheet.show(context, widget.item);
    if (result == CounterSheetResult.addCounter && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CounterSearchScreen(item: widget.item),
          fullscreenDialog: true,
        ),
      );
    }
  }

  Future<void> _showArtworkSelection() async {
    final saved = await _editSession?.commitActive() ?? true;
    if (!saved || !mounted) return;
    var artwork = widget.item.artworkOptions ?? const <ArtworkVariant>[];
    var databaseLoadError = false;
    if (artwork.isEmpty ||
        ArtworkMetadataEnricher.needsArtistMetadata(artwork)) {
      final database = TokenDatabase();
      try {
        await database.loadTokens();
        database.loadCustomTokens();
        final definition = [
          ...database.allTokens,
          ...database.customTokens,
        ].firstWhereOrNull(
          (token) =>
              token.name == widget.item.name &&
              token.pt == widget.item.pt &&
              token.colors == widget.item.colors &&
              token.type == widget.item.type &&
              token.abilities == widget.item.abilities,
        );
        final authoritative = definition?.artwork ?? const <ArtworkVariant>[];
        artwork = ArtworkMetadataEnricher.merge(
          existing: artwork.toList(),
          authoritative: authoritative,
        );
        if (authoritative.isNotEmpty) {
          widget.item.updateArtwork(
            url: widget.item.artworkUrl,
            set: widget.item.artworkSet,
            options: artwork.toList(),
          );
        }
      } catch (_) {
        databaseLoadError = true;
      } finally {
        database.dispose();
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ArtworkSelectionSheet(
          artworkVariants: artwork,
          currentArtworkUrl: widget.item.artworkUrl,
          currentArtworkSet: widget.item.artworkSet,
          tokenName: widget.item.name,
          tokenIdentity:
              '${widget.item.name}|${widget.item.pt}|${widget.item.colors}|${widget.item.type}|${widget.item.abilities}',
          databaseLoadError: databaseLoadError,
          onArtworkSelected: (url, setCode) async {
            if (!kIsWeb && !url.startsWith('file://')) {
              final file = await ArtworkManager.downloadArtwork(url);
              if (file == null) {
                throw StateError('Artwork download failed');
              }
            }
            widget.item.updateArtwork(
                url: url, set: setCode, options: artwork.toList());
            if (mounted) setState(() => _artworkCleanupAttempted = false);
          },
          onRemoveArtwork: widget.item.artworkUrl == null
              ? null
              : () {
                  widget.item.updateArtwork(
                      url: null, set: null, options: artwork.toList());
                  if (mounted) setState(() {});
                },
        ),
      ),
    );
  }

  Future<void> _showStatusSheet() async {
    final saved = await _editSession?.commitActive() ?? true;
    if (saved && mounted) {
      await TokenStatusSheet.show(context, widget.item);
    }
  }

  Widget _buildActionButtons(BuildContext context, SettingsProvider settings) {
    final tokenProvider = context.read<TokenProvider>();
    // Unused variable was causing build warnings
    // final summoningSicknessEnabled = settings.summoningSicknessEnabled;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Count how many buttons will be displayed
    int buttonCount = 2; // Remove and Add are always present

    if (!widget.item.isEmblem) {
      buttonCount += 2; // Untap and Tap
      buttonCount += 1; // +1/+1 Counter
      buttonCount += 1; // Copy
      buttonCount += 1; // Split
    }

    if (widget.item.name.toLowerCase().contains(GameConstants.scuteSwarmName)) {
      buttonCount += 1; // Scute Swarm
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive spacing
        // Button internal padding, icon size, and border width
        const double buttonInternalWidth =
            UIConstants.actionButtonInternalWidth;

        // Calculate total width needed for all buttons without spacing
        final double totalButtonWidth = buttonCount * buttonInternalWidth;

        // Available width for spacing between buttons
        final double availableSpacingWidth =
            constraints.maxWidth - totalButtonWidth;

        // Spacing between buttons (n buttons need n-1 spaces)
        final double spacing = buttonCount > 1
            ? (availableSpacingWidth / (buttonCount - 1)).clamp(
                UIConstants.minButtonSpacing,
                UIConstants.maxButtonSpacing,
              )
            : 0.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Remove button
            _buildActionButton(
              context,
              icon: Icons.remove,
              onTap: () => tokenProvider.removeTokens(widget.item, 1),
              onLongPress: () =>
                  tokenProvider.removeTokens(widget.item, widget.item.amount),
              color: primaryColor,
              spacing: spacing,
            ),

            // Emblem amount display (centered between Remove and Add)
            if (widget.item.isEmblem)
              Padding(
                padding: EdgeInsets.only(right: spacing),
                child: BackgroundText(
                  padding: const EdgeInsets.all(
                      UIConstants.actionButtonPadding), // Match button padding
                  child: Text(
                    '${widget.item.amount}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: UIConstants
                              .iconSize, // Match icon size for consistent height
                        ),
                  ),
                ),
              ),

            // Add button
            _buildActionButton(
              context,
              icon: Icons.add,
              onTap: () {
                final summoningSick =
                    context.read<SettingsProvider>().summoningSicknessEnabled;
                if (widget.item.isEmblem) {
                  // Emblems always add 1 (no rules)
                  tokenProvider.addTokens(widget.item, 1, summoningSick);
                } else {
                  _addTokensViaRules(context, tokenProvider, 1, summoningSick);
                }
              },
              onLongPress: () {
                final summoningSick =
                    context.read<SettingsProvider>().summoningSicknessEnabled;
                if (widget.item.isEmblem) {
                  // Emblems add 10 on long press (no rules)
                  tokenProvider.addTokens(widget.item, 10, summoningSick);
                } else {
                  _addTokensViaRules(context, tokenProvider, 10, summoningSick);
                }
              },
              color: primaryColor,
              spacing: spacing,
            ),

            if (!widget.item.isEmblem) ...[
              // Untap button
              _buildActionButton(
                context,
                icon: Icons.mobile_friendly,
                onTap: () => tokenProvider.untapTokens(widget.item, 1),
                onLongPress: () =>
                    tokenProvider.untapTokens(widget.item, widget.item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Tap button
              _buildActionButton(
                context,
                icon: ManaIcons.tap,
                onTap: () => tokenProvider.tapTokens(widget.item, 1),
                onLongPress: () => tokenProvider.tapTokens(
                    widget.item, widget.item.amount - widget.item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // HIDDEN: Clear Summoning Sickness button - Deliberately hidden from users but preserved for future use
              // if (summoningSicknessEnabled)
              //   _buildActionButton(
              //     context,
              //     icon: Icons.adjust,
              //     onTap: widget.item.summoningSick > 0 ? () {
              //       widget.item.summoningSick = 0;
              //       tokenProvider.updateItem(widget.item);
              //     } : null,
              //     onLongPress: null,
              //     color: primaryColor,
              //     spacing: spacing,
              //     disabled: widget.item.summoningSick == 0,
              //   ),

              // +1/+1 Counter button
              _buildActionButton(
                context,
                icon: Icons.trending_up,
                onTap: () {
                  final rulesProvider = context.read<RulesProvider>();
                  final amount =
                      rulesProvider.calculateCounterAmount(1, isPlusOne: true);
                  widget.item.plusOneCounters =
                      widget.item.plusOneCounters + amount;
                  tokenProvider.updateItem(widget.item);
                },
                onLongPress: () {
                  final rulesProvider = context.read<RulesProvider>();
                  final amount =
                      rulesProvider.calculateCounterAmount(10, isPlusOne: true);
                  widget.item.plusOneCounters =
                      widget.item.plusOneCounters + amount;
                  tokenProvider.updateItem(widget.item);
                },
                color: primaryColor,
                spacing: spacing,
              ),

              // Copy button
              _buildActionButton(
                context,
                icon: Icons.content_copy,
                onTap: () {
                  final summoningSick =
                      context.read<SettingsProvider>().summoningSicknessEnabled;
                  final trackerProvider = context.read<TrackerProvider>();
                  final toggleProvider = context.read<ToggleProvider>();
                  tokenProvider.copyToken(
                    widget.item,
                    summoningSick,
                    boardOrders: [
                      ...tokenProvider.items.map((item) => item.order),
                      ...trackerProvider.trackers.map((item) => item.order),
                      ...toggleProvider.toggles.map((item) => item.order),
                    ],
                  );
                },
                onLongPress: null,
                color: primaryColor,
                spacing: spacing,
              ),

              // Split Stack button (always shown, disabled if 1 or fewer tokens)
              _buildActionButton(
                context,
                icon: Icons.call_split,
                onTap: widget.item.amount > 1
                    ? () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => SplitStackSheet(
                            item: widget.item,
                            // No onSplitCompleted callback - sheet dismisses itself
                          ),
                        );
                      }
                    : null,
                onLongPress: null,
                color: primaryColor,
                spacing: spacing,
                disabled: widget.item.amount <= 1,
              ),
            ],

            // Scute Swarm special button (last button gets 0 spacing)
            if (widget.item.name
                .toLowerCase()
                .contains(GameConstants.scuteSwarmName))
              _buildActionButton(
                context,
                icon: Icons.bug_report,
                onTap: () async {
                  final rulesProvider = context.read<RulesProvider>();
                  final summoningSick =
                      context.read<SettingsProvider>().summoningSicknessEnabled;
                  final trackerProvider = context.read<TrackerProvider>();
                  final toggleProvider = context.read<ToggleProvider>();

                  // Count all Scute Swarm tokens on the board
                  int totalScuteCount = 0;
                  for (final item in tokenProvider.items) {
                    if (item.name
                            .toLowerCase()
                            .contains(GameConstants.scuteSwarmName) &&
                        item.amount > 0) {
                      totalScuteCount += item.amount;
                    }
                  }

                  // Route through rules engine (replaces old multiplier)
                  final results = rulesProvider.evaluateRules(
                    widget.item.name,
                    widget.item.pt,
                    widget.item.colors,
                    widget.item.type,
                    widget.item.abilities,
                    totalScuteCount,
                  );
                  // Primary result quantity is the final scute count
                  final finalAmount = results.first.quantity;

                  final resultOrders = BoardOrderService.immediatelyAfter(
                    sourceOrder: widget.item.order,
                    boardOrders: [
                      ...tokenProvider.items.map((item) => item.order),
                      ...trackerProvider.trackers.map((item) => item.order),
                      ...toggleProvider.toggles.map((item) => item.order),
                    ],
                    count: results.length,
                  );
                  final insertionOrder = resultOrders.first;

                  // Pass finalAmount as 1 * finalAmount (rules already applied)
                  // Use multiplier=1 since rules already calculated the quantity
                  await tokenProvider.createScuteSwarmTokens(
                    widget.item,
                    1,
                    summoningSick,
                    insertionOrder,
                    overrideAmount: finalAmount,
                  );

                  // Route rule companions through the shared resolver so a
                  // brand-new Squirrel stack receives the same saved/default
                  // artwork as one created from token search.
                  if (results.length > 1) {
                    final tokenDatabase = TokenDatabase();
                    try {
                      await tokenDatabase.loadTokens();
                      await TokenCreationService.createCompanionTokens(
                        results: results,
                        tokenProvider: tokenProvider,
                        summoningSicknessEnabled: summoningSick,
                        insertionOrder: resultOrders[1],
                        insertionOrders: resultOrders.skip(1).toList(),
                        tokenDatabase: tokenDatabase,
                      );
                    } finally {
                      tokenDatabase.dispose();
                    }
                  }
                },
                onLongPress: null, // No long-press behavior for Scute Swarm
                color: primaryColor,
                spacing: 0, // Last button gets no trailing space
              ),
          ],
        );
      },
    );
  }

  /// Routes quick-add through the rules engine. For multiply-only rules, silently
  /// adds the modified quantity. When companion tokens are created, shows a brief
  /// notification.
  Future<void> _addTokensViaRules(BuildContext context,
      TokenProvider tokenProvider, int baseQuantity, bool summoningSick) async {
    final rulesProvider = context.read<RulesProvider>();
    final results = rulesProvider.evaluateRules(
      widget.item.name,
      widget.item.pt,
      widget.item.colors,
      widget.item.type,
      widget.item.abilities,
      baseQuantity,
    );

    final primaryResult = results.first;
    final primaryIdentityUnchanged = primaryResult.name == widget.item.name &&
        primaryResult.pt == widget.item.pt &&
        primaryResult.colors == widget.item.colors &&
        primaryResult.type == widget.item.type &&
        primaryResult.abilities == widget.item.abilities;
    var companionCount = 0;
    TokenDatabase? tokenDatabase;
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
    try {
      if (!primaryIdentityUnchanged || results.length > 1) {
        tokenDatabase = TokenDatabase();
        await tokenDatabase.loadTokens();
      }

      final resultOrders = BoardOrderService.immediatelyAfter(
        sourceOrder: widget.item.order,
        boardOrders: [
          ...tokenProvider.items.map((item) => item.order),
          ...trackerProvider.trackers.map((item) => item.order),
          ...toggleProvider.toggles.map((item) => item.order),
        ],
        count: results.length,
      );

      if (primaryIdentityUnchanged &&
          TokenMergeCompatibility.isClean(widget.item)) {
        await tokenProvider.addTokens(
          widget.item,
          primaryResult.quantity,
          summoningSick,
        );
      } else {
        final artwork = primaryIdentityUnchanged
            ? ResolvedTokenArtwork(
                url: widget.item.artworkUrl,
                set: widget.item.artworkSet,
                options: widget.item.artworkOptions,
              )
            : TokenResultArtworkResolver.resolve(
                result: primaryResult,
                tokenDatabase: tokenDatabase,
              );
        await TokenCreationService.commit(
          requests: [
            TokenCommitRequest(
              result: primaryResult,
              artwork: artwork,
              order: resultOrders.first,
              applySummoningSickness: summoningSick,
            ),
          ],
          tokenProvider: tokenProvider,
        );
      }

      if (results.length > 1) {
        companionCount = await TokenCreationService.createCompanionTokens(
          results: results,
          tokenProvider: tokenProvider,
          summoningSicknessEnabled: summoningSick,
          insertionOrder: resultOrders[1],
          insertionOrders: resultOrders.skip(1).toList(),
          tokenDatabase: tokenDatabase,
        );
      }
    } finally {
      tokenDatabase?.dispose();
    }

    if (results.length > 1) {
      // Show tooltip above rules FAB for companion tokens
      if (context.mounted) {
        final totalCreated = primaryResult.quantity + companionCount;
        MultiplierView.showTooltip(context, 'Created $totalCreated tokens');
      }
    }

    // Show cap alert if any results were capped
    if (results.any((r) => r.wasCapped) && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Woah there!'),
          content: const Text(
            'Looks like your deck is popping off. Congrats! '
            'For performance reasons, tokens have been capped at 999,999. '
            'Please win the game this turn.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color color,
    required double spacing,
    bool disabled = false,
  }) {
    final effectiveColor =
        disabled ? color.withValues(alpha: UIConstants.disabledOpacity) : color;

    // Use card background color for button backgrounds (needed for artwork or gradient)
    // Always use solid background since tokens always have either artwork or gradient background
    final buttonBackgroundColor =
        Theme.of(context).cardColor.withValues(alpha: 0.85);
    Future<void> runAfterCommit(VoidCallback? action) async {
      if (action == null) return;
      final saved = await _editSession?.commitActive() ?? true;
      if (saved && mounted) action();
    }

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: disabled || onTap == null ? null : () => runAfterCommit(onTap),
        onLongPress: disabled || onLongPress == null
            ? null
            : () => runAfterCommit(onLongPress),
        child: Container(
          padding: const EdgeInsets.all(UIConstants.actionButtonPadding),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius:
                BorderRadius.circular(UIConstants.actionButtonBorderRadius),
            border: Border.all(
              color: effectiveColor,
              width: UIConstants.actionButtonBorderWidth,
            ),
          ),
          child: Icon(
            icon,
            color: effectiveColor,
            size: UIConstants.iconSize,
          ),
        ),
      ),
    );
  }

  /// Build gradient background layer for artless tokens (Custom Artwork Feature)
  Widget _buildGradientLayer(BuildContext context) {
    // NOTE: Current gradient matches border exactly (same colors, same stops).
    // If visual appearance is unsatisfactory, explore alternatives:
    // - Modified opacity (e.g., gradient with 0.6 alpha for subtler effect)
    // - Radial gradient instead of linear
    // - Partial coverage (e.g., only bottom 50% of card)
    // - Color-shifted variants (lighter/darker hues)
    // - Different gradient direction (vertical, diagonal, etc.)

    final gradient = ColorUtils.gradientForColors(widget.item.colors,
        isEmblem: widget.item.isEmblem);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
        ),
      ),
    );
  }

  /// Build conditional gradient that only shows while artwork is loading
  Widget _buildConditionalGradient(BuildContext context) {
    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(widget.item.artworkUrl!),
        builder: (context, snapshot) {
          // Only show gradient if artwork file is NOT available yet
          if (!snapshot.hasData || snapshot.data == null) {
            final gradient = ColorUtils.gradientForColors(widget.item.colors,
                isEmblem: widget.item.isEmblem);
            return Container(
              decoration: BoxDecoration(
                gradient: gradient,
              ),
            );
          }
          // Artwork is loaded, hide gradient
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build inline layout (Row) for type, abilities, and P/T
  Widget _buildInlineTypeAbilitiesAndPT(BuildContext context, Item item) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Type and Abilities in a Column (left side)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type (if present)
                if (widget.item.type.isNotEmpty && !item.isEmblem)
                  BackgroundText(
                    child: Text(
                      widget.item.type,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                      textAlign: TextAlign.left,
                    ),
                  ),

                // Spacing between type and abilities
                if (widget.item.type.isNotEmpty &&
                    widget.item.abilities.isNotEmpty &&
                    !item.isEmblem)
                  const SizedBox(height: UIConstants.verticalSpacing),

                // Abilities (if present)
                if (widget.item.abilities.isNotEmpty)
                  BackgroundText(
                    child: ManaText(
                      widget.item.abilities,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign:
                          item.isEmblem ? TextAlign.center : TextAlign.left,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Spacing between content and P/T
          if (!item.isEmblem && item.pt.isNotEmpty)
            const SizedBox(width: UIConstants.mediumSpacing),

          // P/T (bottom-right)
          if (!item.isEmblem && item.pt.isNotEmpty)
            Align(
              alignment: Alignment.bottomRight,
              child: _buildPTWidget(context),
            ),
        ],
      ),
    );
  }

  /// Build stacked layout (Column) for type, abilities, and P/T with long P/T
  Widget _buildStackedTypeAbilitiesAndPT(BuildContext context, Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Type (if present)
        if (widget.item.type.isNotEmpty && !item.isEmblem)
          Align(
            alignment: Alignment.centerLeft,
            child: BackgroundText(
              child: Text(
                widget.item.type,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.left,
              ),
            ),
          ),

        // Spacing between type and abilities
        if (widget.item.type.isNotEmpty &&
            widget.item.abilities.isNotEmpty &&
            !item.isEmblem)
          const SizedBox(height: UIConstants.verticalSpacing),

        // Abilities (full width)
        if (widget.item.abilities.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: BackgroundText(
              child: ManaText(
                item.abilities,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: item.isEmblem ? TextAlign.center : TextAlign.left,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // Spacing before P/T
        if (item.pt.isNotEmpty &&
            (widget.item.type.isNotEmpty || widget.item.abilities.isNotEmpty))
          const SizedBox(height: UIConstants.mediumSpacing),

        // P/T (right-aligned in its own row)
        if (item.pt.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: _buildPTWidget(context),
          ),
      ],
    );
  }

  /// Build P/T widget (modified or normal styling)
  Widget _buildPTWidget(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );

    return widget.item.isPowerToughnessModified
        ? _AnimatedPowerToughness(
            powerToughness: widget.item.formattedPowerToughness,
            style: textStyle?.copyWith(color: Colors.white),
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.mediumSpacing,
              vertical: UIConstants.verticalSpacing,
            ),
            backgroundColor: Colors.orange.withValues(alpha: 0.85),
          )
        : _AnimatedPowerToughness(
            powerToughness: widget.item.formattedPowerToughness,
            style: textStyle,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            backgroundColor:
                Theme.of(context).cardColor.withValues(alpha: 0.85),
          );
  }
}

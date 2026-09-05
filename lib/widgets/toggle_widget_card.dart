import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/toggle_widget.dart';
import '../models/token_definition.dart';
import '../controllers/expandable_card_controller.dart';
import '../database/widget_database.dart';
import '../providers/settings_provider.dart';
import '../providers/toggle_provider.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_metadata_enricher.dart';
import '../utils/color_utils.dart';
import 'common/background_text.dart';
// Unused import was causing build warnings
// import 'cropped_artwork_widget.dart';
import 'mixins/artwork_display_mixin.dart';
import 'mana/mana_text.dart';
import 'artwork_selection_sheet.dart';
import 'inline_color_identity_bar.dart';
import 'inline_artwork_button.dart';

class ToggleWidgetCard extends StatefulWidget {
  final ToggleWidget toggle;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<bool> onEditingChanged;
  final ExpandableCardController? controller;

  const ToggleWidgetCard({
    super.key,
    required this.toggle,
    required this.isExpanded,
    required this.onExpand,
    required this.onCollapse,
    required this.onEditingChanged,
    this.controller,
  });

  @override
  State<ToggleWidgetCard> createState() => _ToggleWidgetCardState();
}

class _ToggleWidgetCardState extends State<ToggleWidgetCard>
    with SingleTickerProviderStateMixin, ArtworkDisplayMixin {
  static const double _identityRailWidth = 7;
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;
  late final TextEditingController _onController;
  late final TextEditingController _offController;
  late final TextEditingController _nameController;
  late final FocusNode _onFocus;
  late final FocusNode _offFocus;
  late final FocusNode _nameFocus;
  bool _editingOn = false;
  bool _editingOff = false;
  Future<bool>? _nameCommit;
  Future<bool>? _descriptionCommit;
  bool _editingName = false;
  late final dynamic _toggleKey;
  double? _artworkRevealHeight;
  late final AnimationController _artworkCenterController;
  late final CurvedAnimation _artworkCenterProgress;

  @override
  void initState() {
    super.initState();
    _toggleKey = widget.toggle.key;
    _artworkCenterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );
    _artworkCenterProgress = CurvedAnimation(
      parent: _artworkCenterController,
      curve: const Cubic(0.18, 0.89, 0.32, 1.08),
    );
    _onController = TextEditingController(text: widget.toggle.onDescription);
    _offController = TextEditingController(text: widget.toggle.offDescription);
    _nameController = TextEditingController(text: widget.toggle.name);
    _onFocus = FocusNode()..addListener(_handleFocusChange);
    _offFocus = FocusNode()..addListener(_handleFocusChange);
    _nameFocus = FocusNode()..addListener(_handleFocusChange);
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
  String? get artworkUrl => widget.toggle.currentArtworkUrl;

  @override
  void clearArtwork() {
    widget.toggle.artworkUrl = null;
    widget.toggle.artworkSet = null;
    widget.toggle.artworkOptions = null;
    widget.toggle.save();
    // FUTURE: When state-specific artwork is implemented, also clear:
    // widget.toggle.onArtworkUrl = null;
    // widget.toggle.offArtworkUrl = null;
  }

  @override
  void didUpdateWidget(ToggleWidgetCard oldWidget) {
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
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.toggle.artworkUrl != widget.toggle.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
    if (!_editingOn && _onController.text != widget.toggle.onDescription) {
      _onController.text = widget.toggle.onDescription;
    }
    if (!_editingOff && _offController.text != widget.toggle.offDescription) {
      _offController.text = widget.toggle.offDescription;
    }
    if (!_editingName && _nameController.text != widget.toggle.name) {
      _nameController.text = widget.toggle.name;
    }
  }

  @override
  void dispose() {
    _artworkCenterProgress.dispose();
    _artworkCenterController.dispose();
    widget.controller?.detach(_requestCollapse);
    _onFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    _offFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    _onController.dispose();
    _offController.dispose();
    _nameFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    _nameController.dispose();
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
              opacity:
                  1.0, // Full opacity (matching TokenCard pattern for consistent swipe behavior)
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Base card background layer (transparent to allow red swipe indicator through)
                      Container(
                        color: Colors.transparent,
                      ),

                      // Gradient background layer
                      if (_getCurrentArtworkUrl() == null ||
                          _getCurrentArtworkUrl()!.isEmpty)
                        _buildGradientLayer(context)
                      else
                        _buildConditionalGradient(context),

                      // Artwork layer
                      if (_getCurrentArtworkUrl() != null)
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left side: Name and Description (takes remaining space)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Name
                                  _buildInlineName(context),
                                  if (widget.isExpanded) ...[
                                    const SizedBox(
                                        height: UIConstants.mediumSpacing),
                                    _buildStateDescription(
                                      context,
                                      label: 'On',
                                      controller: _onController,
                                      focusNode: _onFocus,
                                      editing: _editingOn,
                                      begin: () => _beginEdit(true),
                                    ),
                                    const SizedBox(
                                        height: UIConstants.verticalSpacing),
                                    _buildStateDescription(
                                      context,
                                      label: 'Off',
                                      controller: _offController,
                                      focusNode: _offFocus,
                                      editing: _editingOff,
                                      begin: () => _beginEdit(false),
                                    ),
                                    const SizedBox(
                                        height: UIConstants.mediumSpacing),
                                    _buildExpandedCharacteristics(context),
                                  ],

                                  const SizedBox(
                                      height: UIConstants.mediumSpacing),

                                  // Current description (ON or OFF)
                                  BackgroundText(
                                    child: ManaText(
                                      widget.toggle.currentDescription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: UIConstants.mediumSpacing),

                            // Right side: Toggle button (shrink-wraps)
                            _buildToggleButton(context),
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
                                widget.toggle.colorIdentity,
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

  void _handleFocusChange() {
    if (_editingName && !_nameFocus.hasFocus) _commitName();
    if (_editingOn && !_onFocus.hasFocus) _commitDescriptions();
    if (_editingOff && !_offFocus.hasFocus) _commitDescriptions();
  }

  Future<void> _beginNameEdit() async {
    if (!await _commitDescriptions() || !mounted) return;
    setState(() => _editingName = true);
    widget.onEditingChanged(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  Future<bool> _commitName() {
    return _nameCommit ??= _commitNameOnce().whenComplete(() {
      _nameCommit = null;
    });
  }

  Future<bool> _commitNameOnce() async {
    if (!_editingName) return true;
    final toggleProvider = context.read<ToggleProvider>();
    final toggle = toggleProvider.resolveCurrentToggle(
      widget.toggle,
      capturedKey: _toggleKey,
    );
    if (toggle == null) return true;
    final previous = toggle.name;
    final next = _nameController.text.trim();
    if (next.isEmpty) {
      _nameController.text = previous;
      if (mounted) setState(() => _editingName = false);
      widget.onEditingChanged(false);
      return true;
    }
    toggle.name = next;
    try {
      await toggleProvider.updateToggle(toggle);
      if (mounted) setState(() => _editingName = false);
      widget.onEditingChanged(false);
      return true;
    } catch (_) {
      toggle.name = previous;
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
          focusNode: _nameFocus,
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
          widget.toggle.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Future<void> _beginEdit(bool onState) async {
    if (!await _commitDescriptions() || !mounted) return;
    setState(() {
      _editingOn = onState;
      _editingOff = !onState;
    });
    widget.onEditingChanged(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (onState ? _onFocus : _offFocus).requestFocus();
    });
  }

  Future<bool> _commitDescriptions() {
    return _descriptionCommit ??= _commitDescriptionsOnce().whenComplete(() {
      _descriptionCommit = null;
    });
  }

  Future<bool> _commitDescriptionsOnce() async {
    if (!_editingOn && !_editingOff) return true;
    final toggleProvider = context.read<ToggleProvider>();
    final toggle = toggleProvider.resolveCurrentToggle(
      widget.toggle,
      capturedKey: _toggleKey,
    );
    if (toggle == null) return true;
    final oldOn = toggle.onDescription;
    final oldOff = toggle.offDescription;
    toggle
      ..onDescription = _onController.text
      ..offDescription = _offController.text;
    try {
      await toggleProvider.updateToggle(toggle);
      if (mounted) {
        setState(() {
          _editingOn = false;
          _editingOff = false;
        });
        widget.onEditingChanged(false);
      }
      return true;
    } catch (_) {
      toggle
        ..onDescription = oldOn
        ..offDescription = oldOff;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utility states could not be saved.')),
        );
      }
      return false;
    }
  }

  Future<bool> _requestCollapse() async {
    if (!await _commitName()) return false;
    return _commitDescriptions();
  }

  Widget _buildStateDescription(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool editing,
    required VoidCallback begin,
  }) {
    if (editing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 96),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitDescriptions(),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '$label state description',
      hint: 'Double tap to edit',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: begin,
        child: BackgroundText(
          child: ManaText(
            '$label: ${controller.text}',
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<void> _collapseAfterCommit() async {
    final approved = await (widget.controller?.requestCollapse() ??
        Future<bool>.value(true));
    if (mounted && approved) widget.onCollapse();
  }

  Widget _buildExpandedCharacteristics(BuildContext context) => Row(
        children: [
          InlineColorIdentityBar(
            colorIdentity: widget.toggle.colorIdentity,
            onToggle: _toggleColorIdentity,
          ),
          const SizedBox(width: UIConstants.verticalSpacing),
          InlineArtworkButton(
            hasArtwork: widget.toggle.artworkUrl != null,
            onPressed: _showArtworkSelection,
          ),
        ],
      );

  Future<void> _toggleColorIdentity(String symbol) async {
    if (!await _requestCollapse() || !mounted) return;
    final selected = widget.toggle.colorIdentity.characters.toSet();
    selected.contains(symbol) ? selected.remove(symbol) : selected.add(symbol);
    widget.toggle.colorIdentity =
        'WUBRG'.characters.where(selected.contains).join();
    await context.read<ToggleProvider>().updateToggle(widget.toggle);
    if (mounted) setState(() {});
  }

  Future<void> _showArtworkSelection() async {
    if (!await _requestCollapse() || !mounted) return;
    final toggleProvider = context.read<ToggleProvider>();
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
          currentArtworkUrl: widget.toggle.artworkUrl,
          currentArtworkSet: widget.toggle.artworkSet,
          tokenName: widget.toggle.name,
          tokenIdentity: widget.toggle.widgetId,
          databaseLoadError: false,
          onArtworkSelected: (url, setCode) async {
            if (!kIsWeb && !url.startsWith('file://')) {
              final file = await ArtworkManager.downloadArtwork(url);
              if (file == null) {
                throw StateError('Artwork download failed');
              }
            }
            final toggle = toggleProvider.resolveCurrentToggle(
              widget.toggle,
              capturedKey: _toggleKey,
            );
            if (toggle == null) return;
            toggle
              ..artworkUrl = url
              ..artworkSet = setCode
              ..artworkOptions = List<ArtworkVariant>.from(options);
            await toggleProvider.updateToggle(toggle);
            if (mounted) {
              setState(() => _artworkCleanupAttempted = false);
            }
          },
          onRemoveArtwork: widget.toggle.artworkUrl == null
              ? null
              : () async {
                  final toggle = toggleProvider.resolveCurrentToggle(
                    widget.toggle,
                    capturedKey: _toggleKey,
                  );
                  if (toggle == null) return;
                  toggle
                    ..artworkUrl = null
                    ..artworkSet = null;
                  await toggleProvider.updateToggle(toggle);
                  if (mounted) {
                    setState(() => _artworkCleanupAttempted = false);
                  }
                },
        ),
      ),
    );
  }

  Future<List<ArtworkVariant>> _artworkOptions() async {
    final toggleProvider = context.read<ToggleProvider>();
    final toggle = toggleProvider.resolveCurrentToggle(
      widget.toggle,
      capturedKey: _toggleKey,
    );
    if (toggle == null) return const <ArtworkVariant>[];
    final existing = toggle.artworkOptions;
    final database = WidgetDatabase();
    final match = database.filteredWidgets.where(
      (definition) => definition.name == toggle.name,
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
    toggle.artworkOptions = options;
    await toggleProvider.updateToggle(toggle);
    return options;
  }

  Widget _buildToggleButton(BuildContext context) {
    final toggleProvider = context.read<ToggleProvider>();
    final activeColor = Colors.green;
    final inactiveColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return GestureDetector(
      onTap: () {
        widget.toggle.toggle();
        toggleProvider.updateToggle(widget.toggle);
      },
      child: BackgroundText(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          widget.toggle.isActive
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          size: 48, // Large size to match tracker value emphasis
          color: widget.toggle.isActive ? activeColor : inactiveColor,
        ),
      ),
    );
  }

  String? _getCurrentArtworkUrl() {
    // Use state-specific artwork if available, otherwise fall back to general artwork
    return widget.toggle.currentArtworkUrl;
  }

  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.toggle.colorIdentity,
        isEmblem: false);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }

  Widget _buildConditionalGradient(BuildContext context) {
    final artworkUrl = _getCurrentArtworkUrl();
    if (artworkUrl == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null) {
            final gradient = ColorUtils.gradientForColors(
                widget.toggle.colorIdentity,
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

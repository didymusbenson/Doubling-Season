import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracker_widget.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../providers/toggle_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/token_provider.dart';
import '../providers/rules_provider.dart';
import '../screens/expanded_widget_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
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
import 'definition_preview_card.dart';
import 'mana/mana_text.dart';

class TrackerWidgetCard extends StatefulWidget {
  final TrackerWidget tracker;

  const TrackerWidgetCard({super.key, required this.tracker});

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
    with ArtworkDisplayMixin {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  // Cached artwork Future to prevent FutureBuilder rebuilds (matching ExpandedTokenScreen pattern)
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
    // Cache the artwork Future on initialization
    if (widget.tracker.artworkUrl != null) {
      _cachedArtworkFuture =
          ArtworkManager.getCachedArtworkFile(widget.tracker.artworkUrl!);
    }
  }

  @override
  void didUpdateWidget(TrackerWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, String>(
      selector: (context, settings) => settings.artworkDisplayStyle,
      builder: (context, artworkDisplayStyle, child) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ExpandedWidgetScreen(
                  widget: widget.tracker,
                  isTracker: true,
                ),
              ),
            );
          },
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
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                            UIConstants.borderRadius - 3.0),
                      ),
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
                      ),

                    // Content layer
                    Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(UIConstants.cardPadding),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Name
                                    BackgroundText(
                                      child: Text(
                                        widget.tracker.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),

                                    // Description (if present)
                                    if (widget
                                        .tracker.description.isNotEmpty) ...[
                                      const SizedBox(
                                          height: UIConstants.mediumSpacing),
                                      BackgroundText(
                                        child: ManaText(
                                          widget.tracker.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 3,
                                        ),
                                      ),
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
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ), // Opacity
        );
      },
    );
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
          onTap: () => _performAction(context),
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
              onTap: () {
                widget.tracker.decrement(widget.tracker.tapIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              onLongPress: () {
                widget.tracker.decrement(widget.tracker.longPressIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              color: primaryColor,
              spacing: spacing,
            ),

            // Increment button
            _buildActionButton(
              context,
              icon: Icons.add,
              onTap: () {
                widget.tracker.increment(widget.tracker.tapIncrement);
                trackerProvider.updateTracker(widget.tracker);
              },
              onLongPress: () {
                widget.tracker.increment(widget.tracker.longPressIncrement);
                trackerProvider.updateTracker(widget.tracker);
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
                onTap: () => _performQuickPlusOne(context),
                color: primaryColor,
                spacing: spacing,
              ),
              // Resolve All button
              _buildTextActionButton(
                context,
                text: widget.tracker.actionButtonText ?? 'Action',
                onTap: () => _performAction(context),
                color: primaryColor,
                spacing: 0, // Last button gets no spacing
              ),
            ] else if (widget.tracker.hasAction)
              _buildTextActionButton(
                context,
                text: widget.tracker.actionButtonText ?? 'Action',
                onTap: () => _performAction(context),
                color: primaryColor,
                spacing: 0, // Last button gets no spacing
              ),
          ],
        );
      },
    );
  }

  Widget _buildValueDisplay(BuildContext context) {
    // Big number display - takes full vertical space
    return GestureDetector(
      onTap: () => _showValueEditDialog(context),
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

  void _showValueEditDialog(BuildContext context) {
    final trackerProvider = context.read<TrackerProvider>();
    final controller =
        TextEditingController(text: '${widget.tracker.currentValue}');
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Request focus after dialog is built (Android compatibility)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialogContext.mounted) {
            focusNode.requestFocus();
          }
        });
        return AlertDialog(
          title: Text('Set ${widget.tracker.name}'),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
            ),
            onTapOutside: (_) => FocusScope.of(dialogContext).unfocus(),
            onSubmitted: (value) {
              final newValue =
                  int.tryParse(value) ?? widget.tracker.currentValue;
              widget.tracker.currentValue =
                  newValue.clamp(0, double.maxFinite.toInt());
              trackerProvider.updateTracker(widget.tracker);
              FocusScope.of(dialogContext).unfocus();
              Navigator.of(dialogContext).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newValue = int.tryParse(controller.text) ??
                    widget.tracker.currentValue;
                widget.tracker.currentValue =
                    newValue.clamp(0, double.maxFinite.toInt());
                trackerProvider.updateTracker(widget.tracker);
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
      focusNode.dispose();
    });
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

  void _performAction(BuildContext context) {
    final actionType = widget.tracker.actionType;

    if (actionType == null) return;

    switch (actionType) {
      case 'krenko_mob_boss':
        _performKrenkoMobBossAction(context);
        break;
      case 'krenko_tin_street':
        _performKrenkoTinStreetAction(context);
        break;
      case 'cathars_crusade':
        _performCatharsCrusadeAction(context);
        break;
      case 'academy_manufactor':
        _performAcademyManufactorAction(context);
        break;
      case 'hare_apparent':
        _performHareApparentAction(context);
        break;
      case 'rhys_the_redeemed':
        _performRhysTheRedeemedAction(context);
        break;
      case 'brudiclad_telchor_engineer':
        _performBrudicladAction(context);
        break;
      default:
        break;
    }
  }

  Future<void> _performBrudicladAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final rulesProvider = context.read<RulesProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();

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
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();

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

    if (shouldCreate == null) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));
    final maxOrder =
        allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    final nextOrder = maxOrder.floor() + 1.0;

    // Create rabbits (plus any companions from rules) as peer results
    final tokenDatabase = TokenDatabase();
    await tokenDatabase.loadTokens();
    await TokenCreationService.createAllFromResults(
      results: results,
      tokenProvider: tokenProvider,
      summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
      insertionOrder: nextOrder,
      tokenDatabase: tokenDatabase,
    );
    tokenDatabase.dispose();
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

    if (shouldCreate == null) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
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
      await tokenDatabase.loadTokens();
      await TokenCreationService.createCompanionTokens(
        results: results,
        tokenProvider: tokenProvider,
        summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
        insertionOrder: nextOrder,
        tokenDatabase: tokenDatabase,
      );
      tokenDatabase.dispose();
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

    if (shouldCreate == null) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
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
      await tokenDatabase.loadTokens();
      await TokenCreationService.createCompanionTokens(
        results: results,
        tokenProvider: tokenProvider,
        summoningSicknessEnabled: settingsProvider.summoningSicknessEnabled,
        insertionOrder: nextOrder,
        tokenDatabase: tokenDatabase,
      );
      tokenDatabase.dispose();
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

  Future<void> _performQuickPlusOne(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final rulesProvider = context.read<RulesProvider>();

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

    if (shouldCreate != true) return;

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
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
    await tokenDatabase.loadTokens();
    await TokenCreationService.createAllFromResults(
      results: results,
      tokenProvider: tokenProvider,
      summoningSicknessEnabled:
          false, // Artifact tokens (Food/Treasure/Clue) have no P/T
      insertionOrder: nextOrder,
      tokenDatabase: tokenDatabase,
    );
    tokenDatabase.dispose();
  }

  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.tracker.colorIdentity,
        isEmblem: false);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
        ),
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
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius:
                    BorderRadius.circular(UIConstants.borderRadius - 3.0),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

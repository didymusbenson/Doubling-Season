import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracker_widget.dart';
import '../providers/settings_provider.dart';
import '../providers/toggle_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/token_provider.dart';
import '../screens/expanded_widget_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/color_utils.dart';
import 'common/background_text.dart';
// Unused import was causing build warnings
// import 'cropped_artwork_widget.dart';
import 'mixins/artwork_display_mixin.dart';

class TrackerWidgetCard extends StatefulWidget {
  final TrackerWidget tracker;

  const TrackerWidgetCard({super.key, required this.tracker});

  @override
  State<TrackerWidgetCard> createState() => _TrackerWidgetCardState();
}

class _TrackerWidgetCardState extends State<TrackerWidgetCard> with ArtworkDisplayMixin {
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
      _cachedArtworkFuture = ArtworkManager.getCachedArtworkFile(widget.tracker.artworkUrl!);
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
            opacity: 1.0, // Full opacity (matching TokenCard pattern for consistent swipe behavior)
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                children: [
                  // Base card background layer (transparent to allow red swipe indicator through)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
                    ),
                  ),

                  // Gradient background layer
                  if (widget.tracker.artworkUrl == null || widget.tracker.artworkUrl!.isEmpty)
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
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),

                                  // Description (if present)
                                  if (widget.tracker.description.isNotEmpty) ...[
                                    const SizedBox(height: UIConstants.mediumSpacing),
                                    BackgroundText(
                                      child: Text(
                                        widget.tracker.description,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: UIConstants.mediumSpacing),

                            // Right side: Value display (shrink-wraps)
                            _buildValueDisplay(context),
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

    // Calculate button count: +/- buttons, plus optional action button(s)
    final int buttonCount = widget.tracker.actionType == 'cathars_crusade'
        ? 4  // -, +, Quick +1, Resolve All
        : (widget.tracker.hasAction ? 3 : 2); // -, +, [optional Action]

    return LayoutBuilder(
      builder: (context, constraints) {
        const double buttonInternalWidth = UIConstants.actionButtonInternalWidth;
        final double totalButtonWidth = buttonCount * buttonInternalWidth;
        final double availableSpacingWidth = constraints.maxWidth - totalButtonWidth;
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
              spacing: widget.tracker.hasAction ? spacing : 0, // Spacing if action button follows
            ),

            // Action buttons (conditional)
            if (widget.tracker.hasAction && widget.tracker.actionType == 'cathars_crusade') ...[
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
    final controller = TextEditingController(text: '${widget.tracker.currentValue}');
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
              final newValue = int.tryParse(value) ?? widget.tracker.currentValue;
              widget.tracker.currentValue = newValue.clamp(0, double.maxFinite.toInt());
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
                final newValue = int.tryParse(controller.text) ?? widget.tracker.currentValue;
                widget.tracker.currentValue = newValue.clamp(0, double.maxFinite.toInt());
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
    final buttonBackgroundColor = Theme.of(context).cardColor.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(UIConstants.actionButtonPadding),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius: BorderRadius.circular(UIConstants.actionButtonBorderRadius),
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
    final buttonBackgroundColor = Theme.of(context).cardColor.withValues(alpha: 0.85);

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
            borderRadius: BorderRadius.circular(UIConstants.actionButtonBorderRadius),
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
    final buttonBackgroundColor = Theme.of(context).cardColor.withValues(alpha: 0.85);

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
            borderRadius: BorderRadius.circular(UIConstants.actionButtonBorderRadius),
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
      // Future action types can be added here
      default:
        break;
    }
  }

  Future<void> _performKrenkoMobBossAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final multiplier = settingsProvider.tokenMultiplier;

    // Count existing goblin tokens
    int tokenGoblinCount = 0;
    for (final item in tokenProvider.items) {
      final type = item.type.toLowerCase();
      if (type.contains('goblin')) {
        tokenGoblinCount += item.amount;
      }
    }

    // Calculate goblin creation amounts
    final nontokenGoblins = widget.tracker.currentValue;
    final totalGoblins = tokenGoblinCount + nontokenGoblins;
    final byTotalGoblins = totalGoblins * multiplier;

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
              '$byTotalGoblins goblins',
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
            onPressed: () => Navigator.pop(dialogContext, byTotalGoblins),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Create $byTotalGoblins Goblins'),
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
    final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    final newOrder = maxOrder.floor() + 1.0;

    // Create goblin tokens using TokenProvider
    await tokenProvider.createKrenkoGoblins(shouldCreate, settingsProvider.summoningSicknessEnabled, newOrder);
  }

  Future<void> _performKrenkoTinStreetAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final multiplier = settingsProvider.tokenMultiplier;

    // Calculate goblin creation amount based on Krenko's power
    final krenkoPower = widget.tracker.currentValue;
    final goblinsToCreate = krenkoPower * multiplier;

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
    final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    final newOrder = maxOrder.floor() + 1.0;

    // Create goblin tokens using TokenProvider
    await tokenProvider.createKrenkoGoblins(shouldCreate, settingsProvider.summoningSicknessEnabled, newOrder);
  }

  Future<void> _performCatharsCrusadeAction(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();
    final triggerCount = widget.tracker.currentValue;

    if (triggerCount <= 0) {
      // No triggers to resolve
      return;
    }

    // Show confirmation dialog
    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cathar's Crusade"),
        content: Text(
          'Pressing confirm will add $triggerCount +1/+1 counter${triggerCount == 1 ? '' : 's'} '
          'to all creatures.',
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

    // Add counters to all creatures (tokens with P/T)
    for (var token in allTokens) {
      if (token.hasPowerToughness) {
        token.plusOneCounters += triggerCount;
        await token.save();
      }
    }

    // Reset Cathar's counter to 0
    widget.tracker.currentValue = 0;
    await widget.tracker.save();
  }

  Future<void> _performQuickPlusOne(BuildContext context) async {
    final tokenProvider = context.read<TokenProvider>();

    // Get all tokens on board
    final allTokens = tokenProvider.items;

    // Add +1/+1 counter to all creatures
    for (var token in allTokens) {
      if (token.hasPowerToughness) {
        token.plusOneCounters += 1;
        await token.save();
      }
    }

    // Note: We DON'T reset the Cathar's counter - keep accumulating triggers
  }

  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.tracker.colorIdentity, isEmblem: false);

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
        future: _cachedArtworkFuture, // Use cached Future (prevents flicker on rebuild)
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
            final gradient = ColorUtils.gradientForColors(widget.tracker.colorIdentity, isEmblem: false);
            return Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

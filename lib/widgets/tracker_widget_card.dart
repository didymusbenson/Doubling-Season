import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracker_widget.dart';
import '../models/token_definition.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/token_provider.dart';
import '../screens/expanded_widget_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/color_utils.dart';
import 'cropped_artwork_widget.dart';

class TrackerWidgetCard extends StatefulWidget {
  final TrackerWidget tracker;

  const TrackerWidgetCard({super.key, required this.tracker});

  @override
  State<TrackerWidgetCard> createState() => _TrackerWidgetCardState();
}

class _TrackerWidgetCardState extends State<TrackerWidgetCard> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;
  Future<File?>? _cachedArtworkFuture;
  String? _cachedArtworkUrl;

  @override
  void didUpdateWidget(TrackerWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.tracker.artworkUrl != widget.tracker.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }

  Future<File?> _getArtworkFuture(String artworkUrl) {
    // Cache the future only if URL hasn't changed
    if (_cachedArtworkUrl != artworkUrl || _cachedArtworkFuture == null) {
      _cachedArtworkUrl = artworkUrl;
      _cachedArtworkFuture = ArtworkManager.getCachedArtworkFile(artworkUrl);
    }
    return _cachedArtworkFuture!;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Base card background layer
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
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
                    _buildArtworkLayer(context, constraints, artworkDisplayStyle),

                  // Content layer
                  Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(UIConstants.cardPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side: Name, Description, Buttons (takes remaining space)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Name
                              _buildTextWithBackground(
                                context: context,
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
                                _buildTextWithBackground(
                                  context: context,
                                  child: Text(
                                    widget.tracker.description,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                ),
                              ],

                              const SizedBox(height: UIConstants.mediumSpacing),

                              // Button Row (left-aligned)
                              _buildActionButtons(context),
                            ],
                          ),
                        ),

                        const SizedBox(width: UIConstants.mediumSpacing),

                        // Right side: Value display (shrink-wraps)
                        _buildValueDisplay(context),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final trackerProvider = context.read<TrackerProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    final int buttonCount = widget.tracker.hasAction ? 3 : 2; // +/- buttons, plus optional action button

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

            // Action button (conditional)
            if (widget.tracker.hasAction)
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
      child: _buildTextWithBackground(
        context: context,
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${widget.tracker.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final newValue = int.tryParse(value) ?? widget.tracker.currentValue;
            widget.tracker.currentValue = newValue.clamp(0, double.maxFinite.toInt());
            trackerProvider.updateTracker(widget.tracker);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? widget.tracker.currentValue;
              widget.tracker.currentValue = newValue.clamp(0, double.maxFinite.toInt());
              trackerProvider.updateTracker(widget.tracker);
              Navigator.of(context).pop();
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
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

    // Create goblin tokens
    await _createGoblins(context, shouldCreate);
  }

  Future<void> _performKrenkoTinStreetAction(BuildContext context) async {
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

    // Create goblin tokens
    await _createGoblins(context, shouldCreate);
  }

  Future<void> _createGoblins(BuildContext context, int amount) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // Standard goblin token definition
    final goblinDefinition = TokenDefinition(
      name: 'Goblin',
      abilities: '',
      pt: '1/1',
      colors: 'R',
      type: 'Creature — Goblin',
      popularity: 0,
    );

    // Check if matching goblin token already exists
    final existingGoblin = tokenProvider.items.where((item) {
      return item.name == 'Goblin' &&
          item.pt == '1/1' &&
          item.colors == 'R' &&
          item.type.toLowerCase().contains('goblin') &&
          item.abilities.isEmpty;
    }).firstOrNull;

    if (existingGoblin != null) {
      // Add to existing token
      existingGoblin.amount += amount;
      existingGoblin.save();
    } else {
      // Create new token
      final newGoblin = goblinDefinition.toItem(
        amount: amount,
        createTapped: false,
      );
      await tokenProvider.insertItem(newGoblin);

      // Apply summoning sickness if enabled
      if (settingsProvider.summoningSicknessEnabled &&
          newGoblin.hasPowerToughness &&
          !newGoblin.hasHaste) {
        newGoblin.summoningSick = amount;
      }
    }
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
        future: _getArtworkFuture(widget.tracker.artworkUrl!),
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

  Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints, String artworkDisplayStyle) {
    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: _getArtworkFuture(widget.tracker.artworkUrl!),
        builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == null) {
            // Cleanup: Remove invalid artwork URL (with 2-second delay to prevent interference with drag/upload operations)
            if (!_artworkCleanupAttempted) {
              _artworkCleanupAttempted = true;
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  widget.tracker.artworkUrl = null;
                  widget.tracker.save();
                }
              });
            }
            return const SizedBox.shrink();
          }

          // Determine if artwork loaded quickly (cached) or slowly (network)
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          final shouldAnimate = elapsed > 100 && !_artworkAnimated;

          if (shouldAnimate) {
            _artworkAnimated = true;
          }

          final artworkWidget = CroppedArtworkWidget(
            imageFile: snapshot.data!,
            cropLeft: 0.088,
            cropRight: 0.088,
            cropTop: 0.145,
            cropBottom: 0.368,
            fillWidth: artworkDisplayStyle == 'fullView',
          );

          if (artworkDisplayStyle == 'fadeout') {
            return ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.white],
                  stops: [0.0, 0.50],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: shouldAnimate
                  ? AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: artworkWidget,
                    )
                  : artworkWidget,
            );
          } else {
            return shouldAnimate
                ? AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: artworkWidget,
                  )
                : artworkWidget;
          }
        }

        return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTextWithBackground({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../providers/token_provider.dart';
import '../screens/expanded_token_screen.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/color_utils.dart';
import 'counter_pill.dart';
import 'split_stack_sheet.dart';
import 'cropped_artwork_widget.dart';

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
  State<_AnimatedPowerToughness> createState() => _AnimatedPowerToughnessState();
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

  const TokenCard({super.key, required this.item});

  @override
  State<TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<TokenCard> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when summoningSicknessEnabled or artworkDisplayStyle changes
    // This prevents rebuilds when multiplier changes
    return Selector<SettingsProvider, (bool, String)>(
      selector: (context, settings) => (settings.summoningSicknessEnabled, settings.artworkDisplayStyle),
      builder: (context, settingsData, child) {
        final summoningSicknessEnabled = settingsData.$1;
        final artworkDisplayStyle = settingsData.$2;
        return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ExpandedTokenScreen(item: widget.item),
          ),
        );
      },
      child: Opacity(
      opacity: widget.item.amount == 0 ? 0.5 : 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Base card background layer (ensures left side is solid in fadeout mode)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
                ),
              ),

              // Gradient background layer (Custom Artwork Feature)
              // Shows immediately as placeholder while artwork loads, or permanently for artless tokens
              if (widget.item.artworkUrl == null || widget.item.artworkUrl!.isEmpty)
                _buildGradientLayer(context)
              else
                // Show gradient while artwork is loading
                _buildConditionalGradient(context),

              // Artwork layer (appears on top of gradient when file is available)
              if (widget.item.artworkUrl != null)
                _buildArtworkLayer(context, constraints, artworkDisplayStyle),

              // Content layer (all existing UI elements)
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(UIConstants.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
            // Top row - name, summoning sickness, tapped/untapped
            Row(
              children: [
                if (!widget.item.isEmblem)
                  // Name with truncation to prevent overflow, background shrink-wraps
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildTextWithBackground(
                        context: context,
                        child: Text(
                          widget.item.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                if (widget.item.isEmblem)
                  // Emblems need to center, so use Expanded
                  Expanded(
                    child: _buildTextWithBackground(
                      context: context,
                      child: Text(
                        widget.item.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (!widget.item.isEmblem) const SizedBox(width: UIConstants.mediumSpacing),
                if (!widget.item.isEmblem)
                  // Unified background for entire tapped/untapped section
                  _buildTextWithBackground(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.item.summoningSick > 0 && summoningSicknessEnabled) ...[
                          const Icon(Icons.adjust, size: UIConstants.iconSize),
                          const SizedBox(width: UIConstants.verticalSpacing),
                          Text(
                            '${widget.item.summoningSick}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: UIConstants.mediumSpacing),
                        ],
                        const Icon(Icons.screenshot, size: UIConstants.iconSize),
                        const SizedBox(width: UIConstants.verticalSpacing),
                        Text(
                          '${widget.item.amount - widget.item.tapped}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: UIConstants.mediumSpacing),
                        const Icon(Icons.screen_rotation, size: UIConstants.iconSize),
                        const SizedBox(width: UIConstants.verticalSpacing),
                        Text(
                          '${widget.item.tapped}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Counter pills
            if (widget.item.counters.isNotEmpty ||
                widget.item.plusOneCounters > 0 ||
                widget.item.minusOneCounters > 0) ...[
              const SizedBox(height: UIConstants.mediumSpacing),
              Wrap(
                spacing: UIConstants.verticalSpacing,
                runSpacing: UIConstants.verticalSpacing,
                children: [
                  ...widget.item.counters.map(
                    (c) => CounterPillView(name: c.name, amount: c.amount),
                  ),
                  if (widget.item.plusOneCounters > 0)
                    CounterPillView(
                      name: '+1/+1',
                      amount: widget.item.plusOneCounters,
                    ),
                  if (widget.item.minusOneCounters > 0)
                    CounterPillView(
                      name: '-1/-1',
                      amount: widget.item.minusOneCounters,
                    ),
                ],
              ),
            ],

            // Type, Abilities, and P/T - combined section (condensed layout)
            if ((widget.item.type.isNotEmpty && !widget.item.isEmblem) ||
                widget.item.abilities.isNotEmpty ||
                (!widget.item.isEmblem && widget.item.pt.isNotEmpty)) ...[
              const SizedBox(height: UIConstants.mediumSpacing),
              Padding(
                padding: EdgeInsets.only(right: kIsWeb ? 40 : 0),
                // Use Column layout if formatted P/T is too long (>= 8 chars like "1000/1000")
                child: (!widget.item.isEmblem && widget.item.pt.isNotEmpty && widget.item.formattedPowerToughness.length >= 8)
                    ? _buildStackedTypeAbilitiesAndPT(context, widget.item)
                    : _buildInlineTypeAbilitiesAndPT(context, widget.item),
              ),
            ],

            const SizedBox(height: UIConstants.mediumSpacing),

            // Button Row (centered)
            _buildActionButtons(context, context.read<SettingsProvider>()),
          ],
        ),
              ), // Close Container (content layer)
            ], // Close Stack children
          ); // Close Stack
        }, // Close LayoutBuilder builder
      ), // Close LayoutBuilder
      ), // Close Opacity
        ); // Close GestureDetector
      }, // Close Selector builder
    ); // Close Selector
  }

  Widget _buildActionButtons(BuildContext context, SettingsProvider settings) {
    final tokenProvider = context.read<TokenProvider>();
    final summoningSicknessEnabled = settings.summoningSicknessEnabled;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Count how many buttons will be displayed
    int buttonCount = 2; // Remove and Add are always present

    if (!widget.item.isEmblem) {
      buttonCount += 2; // Untap and Tap
      if (summoningSicknessEnabled) {
        buttonCount += 1; // Clear SS (always shown when enabled)
      }
      buttonCount += 1; // Copy
      buttonCount += 1; // Split
    }

    if (widget.item.name.toLowerCase().contains('scute swarm')) {
      buttonCount += 1; // Scute Swarm
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive spacing
        // Button internal padding, icon size, and border width
        const double buttonInternalWidth = UIConstants.actionButtonInternalWidth;

        // Calculate total width needed for all buttons without spacing
        final double totalButtonWidth = buttonCount * buttonInternalWidth;

        // Available width for spacing between buttons
        final double availableSpacingWidth = constraints.maxWidth - totalButtonWidth;

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
              onLongPress: () => tokenProvider.removeTokens(widget.item, widget.item.amount),
              color: primaryColor,
              spacing: spacing,
            ),

            // Emblem amount display (centered between Remove and Add)
            if (widget.item.isEmblem)
              Padding(
                padding: EdgeInsets.only(right: spacing),
                child: _buildTextWithBackground(
                  context: context,
                  padding: const EdgeInsets.all(UIConstants.actionButtonPadding), // Match button padding
                  child: Text(
                    '${widget.item.amount}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: UIConstants.iconSize, // Match icon size for consistent height
                    ),
                  ),
                ),
              ),

            // Add button
            _buildActionButton(
              context,
              icon: Icons.add,
              onTap: () {
                final multiplier = context.read<SettingsProvider>().tokenMultiplier;
                final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                tokenProvider.addTokens(widget.item, multiplier, summoningSick);
              },
              onLongPress: () {
                final multiplier = context.read<SettingsProvider>().tokenMultiplier;
                final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                tokenProvider.addTokens(widget.item, multiplier * 10, summoningSick);
              },
              color: primaryColor,
              spacing: spacing,
            ),

            if (!widget.item.isEmblem) ...[
              // Untap button
              _buildActionButton(
                context,
                icon: Icons.screenshot,
                onTap: () => tokenProvider.untapTokens(widget.item, 1),
                onLongPress: () => tokenProvider.untapTokens(widget.item, widget.item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Tap button
              _buildActionButton(
                context,
                icon: Icons.screen_rotation,
                onTap: () => tokenProvider.tapTokens(widget.item, 1),
                onLongPress: () => tokenProvider.tapTokens(widget.item, widget.item.amount - widget.item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Clear Summoning Sickness button (always shown when enabled, disabled if nothing to clear)
              if (summoningSicknessEnabled)
                _buildActionButton(
                  context,
                  icon: Icons.adjust,
                  onTap: widget.item.summoningSick > 0 ? () {
                    widget.item.summoningSick = 0;
                    tokenProvider.updateItem(widget.item);
                  } : null,
                  onLongPress: null,
                  color: primaryColor,
                  spacing: spacing,
                  disabled: widget.item.summoningSick == 0,
                ),
              // Copy button
              _buildActionButton(
                context,
                icon: Icons.content_copy,
                onTap: () {
                  final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                  tokenProvider.copyToken(widget.item, summoningSick);
                },
                onLongPress: null,
                color: primaryColor,
                spacing: spacing,
              ),

              // Split Stack button (always shown, disabled if 1 or fewer tokens)
              _buildActionButton(
                context,
                icon: Icons.call_split,
                onTap: widget.item.amount > 1 ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SplitStackSheet(
                      item: widget.item,
                      // No onSplitCompleted callback - sheet dismisses itself
                    ),
                  );
                } : null,
                onLongPress: null,
                color: primaryColor,
                spacing: spacing,
                disabled: widget.item.amount <= 1,
              ),
            ],

            // Scute Swarm special button (last button gets 0 spacing)
            if (widget.item.name.toLowerCase().contains('scute swarm'))
              _buildActionButton(
                context,
                icon: Icons.bug_report,
                onTap: () {
                  final multiplier = context.read<SettingsProvider>().tokenMultiplier;
                  final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                  tokenProvider.addTokens(widget.item, widget.item.amount * multiplier, summoningSick);
                },
                onLongPress: null,
                color: primaryColor,
                spacing: 0, // Last button gets no trailing space
              ),
          ],
        );
      },
    );
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
    final effectiveColor = disabled ? color.withValues(alpha: UIConstants.disabledOpacity) : color;

    // Use card background color for button backgrounds (needed for artwork or gradient)
    // Always use solid background since tokens always have either artwork or gradient background
    final buttonBackgroundColor = Theme.of(context).cardColor.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        onLongPress: disabled ? null : onLongPress,
        child: Container(
          padding: const EdgeInsets.all(UIConstants.actionButtonPadding),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius: BorderRadius.circular(UIConstants.actionButtonBorderRadius),
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

    final gradient = ColorUtils.gradientForColors(widget.item.colors, isEmblem: widget.item.isEmblem);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
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
            final gradient = ColorUtils.gradientForColors(widget.item.colors, isEmblem: widget.item.isEmblem);
            return Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
              ),
            );
          }
          // Artwork is loaded, hide gradient
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build artwork background layer - switches between full view and fadeout
  Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints, String artworkStyle) {
    if (artworkStyle == 'fadeout') {
      return _buildFadeoutArtwork(context, constraints);
    } else {
      return _buildFullViewArtwork(context, constraints);
    }
  }

  /// Build full-width artwork background layer
  Widget _buildFullViewArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages(widget.item.artworkUrl);

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(widget.item.artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Determine if artwork should animate
            // If it appears > 100ms after card creation = downloaded (animate)
            // If it appears < 100ms after card creation = cached (no animation)
            final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
            final shouldAnimate = elapsed > 100 && !_artworkAnimated;

            if (shouldAnimate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _artworkAnimated = true;
                  });
                }
              });
            }

            return AnimatedOpacity(
              opacity: 1.0,
              duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
                child: CroppedArtworkWidget(
                  imageFile: snapshot.data!,
                  cropLeft: crop['left']!,
                  cropRight: crop['right']!,
                  cropTop: crop['top']!,
                  cropBottom: crop['bottom']!,
                  fillWidth: true,
                ),
              ),
            );
          }
          // Show empty background while loading
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build fadeout artwork layer (right-side with gradient)
  Widget _buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages(widget.item.artworkUrl);
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * 0.50;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: artworkWidth,
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(widget.item.artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Same animation logic as full view
            final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
            final shouldAnimate = elapsed > 100 && !_artworkAnimated;

            if (shouldAnimate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _artworkAnimated = true;
                  });
                }
              });
            }

            return AnimatedOpacity(
              opacity: 1.0,
              duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(UIConstants.smallBorderRadius),
                  bottomRight: Radius.circular(UIConstants.smallBorderRadius),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.50],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: CroppedArtworkWidget(
                    imageFile: snapshot.data!,
                    cropLeft: crop['left']!,
                    cropRight: crop['right']!,
                    cropTop: crop['top']!,
                    cropBottom: crop['bottom']!,
                    fillWidth: false,
                  ),
                ),
              ),
            );
          }
          // Show empty background while loading
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Wrap text with solid background for readability over artwork or gradient
  Widget _buildTextWithBackground({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  }) {
    // Text backgrounds are needed for readability over:
    // 1. Artwork (artworkUrl != null)
    // 2. Gradient backgrounds (artworkUrl == null/empty)
    // Since we always have one or the other now, always add backgrounds
    // (No longer conditional - gradient backgrounds added for artless tokens)

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.85), // Semi-transparent card color
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
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
                  _buildTextWithBackground(
                    context: context,
                    child: Text(
                      widget.item.type,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),

                // Spacing between type and abilities
                if (widget.item.type.isNotEmpty && widget.item.abilities.isNotEmpty && !item.isEmblem)
                  const SizedBox(height: UIConstants.verticalSpacing),

                // Abilities (if present)
                if (widget.item.abilities.isNotEmpty)
                  _buildTextWithBackground(
                    context: context,
                    child: Text(
                      widget.item.abilities,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: item.isEmblem ? TextAlign.center : TextAlign.left,
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
            child: _buildTextWithBackground(
              context: context,
              child: Text(
                widget.item.type,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),

        // Spacing between type and abilities
        if (widget.item.type.isNotEmpty && widget.item.abilities.isNotEmpty && !item.isEmblem)
          const SizedBox(height: UIConstants.verticalSpacing),

        // Abilities (full width)
        if (widget.item.abilities.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: _buildTextWithBackground(
              context: context,
              child: Text(
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
            style: textStyle,
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.mediumSpacing,
              vertical: UIConstants.verticalSpacing,
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.85),
          )
        : _AnimatedPowerToughness(
            powerToughness: widget.item.formattedPowerToughness,
            style: textStyle,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.85),
          );
  }
}

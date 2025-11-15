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
import 'counter_pill.dart';
import 'split_stack_sheet.dart';
import 'cropped_artwork_widget.dart';

class TokenCard extends StatelessWidget {
  final Item item;

  const TokenCard({super.key, required this.item});

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
            builder: (context) => ExpandedTokenScreen(item: item),
          ),
        );
      },
      child: Opacity(
      opacity: item.amount == 0 ? 0.5 : 1.0,
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

              // Artwork layer (background, if artwork selected)
              if (item.artworkUrl != null)
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
                if (!item.isEmblem)
                  // Name with shrink-wrap background
                  _buildTextWithBackground(
                    context: context,
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (item.isEmblem)
                  // Emblems need to center, so use Expanded
                  Expanded(
                    child: _buildTextWithBackground(
                      context: context,
                      child: Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (!item.isEmblem) const Spacer(),
                if (!item.isEmblem)
                  // Unified background for entire tapped/untapped section
                  _buildTextWithBackground(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.summoningSick > 0 && summoningSicknessEnabled) ...[
                          const Icon(Icons.adjust, size: UIConstants.iconSize),
                          const SizedBox(width: UIConstants.verticalSpacing),
                          Text(
                            '${item.summoningSick}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: UIConstants.mediumSpacing),
                        ],
                        const Icon(Icons.screenshot, size: UIConstants.iconSize),
                        const SizedBox(width: UIConstants.verticalSpacing),
                        Text(
                          '${item.amount - item.tapped}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: UIConstants.mediumSpacing),
                        const Icon(Icons.screen_rotation, size: UIConstants.iconSize),
                        const SizedBox(width: UIConstants.verticalSpacing),
                        Text(
                          '${item.tapped}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Type (hidden for emblems)
            if (item.type.isNotEmpty && !item.isEmblem) ...[
              const SizedBox(height: UIConstants.verticalSpacing),
              Padding(
                padding: EdgeInsets.only(right: kIsWeb ? 40 : 0),
                child: _buildTextWithBackground(
                  context: context,
                  child: Text(
                    item.type,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ],

            // Counter pills
            if (item.counters.isNotEmpty ||
                item.plusOneCounters > 0 ||
                item.minusOneCounters > 0) ...[
              const SizedBox(height: UIConstants.mediumSpacing),
              Wrap(
                spacing: UIConstants.verticalSpacing,
                runSpacing: UIConstants.verticalSpacing,
                children: [
                  ...item.counters.map(
                    (c) => CounterPillView(name: c.name, amount: c.amount),
                  ),
                  if (item.plusOneCounters > 0)
                    CounterPillView(
                      name: '+1/+1',
                      amount: item.plusOneCounters,
                    ),
                  if (item.minusOneCounters > 0)
                    CounterPillView(
                      name: '-1/-1',
                      amount: item.minusOneCounters,
                    ),
                ],
              ),
            ],

            // Abilities and P/T combined row
            if (item.abilities.isNotEmpty || (!item.isEmblem && item.pt.isNotEmpty)) ...[
              const SizedBox(height: UIConstants.mediumSpacing),
              Padding(
                padding: EdgeInsets.only(right: kIsWeb ? 40 : 0, bottom: UIConstants.mediumSpacing),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Abilities (top-left)
                      if (item.abilities.isNotEmpty)
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
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
                        ),

                      // Spacer when no abilities (pushes P/T to the right)
                      if (item.abilities.isEmpty && !item.isEmblem && item.pt.isNotEmpty)
                        const Spacer(),

                      // Spacing between abilities and P/T
                      if (item.abilities.isNotEmpty && !item.isEmblem && item.pt.isNotEmpty)
                        const SizedBox(width: UIConstants.mediumSpacing),

                      // P/T (bottom-right)
                      if (!item.isEmblem && item.pt.isNotEmpty)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: item.isPowerToughnessModified
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: UIConstants.mediumSpacing,
                                    vertical: UIConstants.verticalSpacing,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.formattedPowerToughness,
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                )
                              : _buildTextWithBackground(
                                  context: context,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    item.formattedPowerToughness,
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: UIConstants.largeSpacing),

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

    if (!item.isEmblem) {
      buttonCount += 2; // Untap and Tap
      if (summoningSicknessEnabled) {
        buttonCount += 1; // Clear SS (always shown when enabled)
      }
      buttonCount += 1; // Copy
      buttonCount += 1; // Split
    }

    if (item.name.toLowerCase().contains('scute swarm')) {
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
              onTap: () => tokenProvider.removeTokens(item, 1),
              onLongPress: () => tokenProvider.removeTokens(item, item.amount),
              color: primaryColor,
              spacing: spacing,
            ),

            // Emblem amount display (centered between Remove and Add)
            if (item.isEmblem)
              Padding(
                padding: EdgeInsets.only(right: spacing),
                child: _buildTextWithBackground(
                  context: context,
                  padding: const EdgeInsets.all(UIConstants.actionButtonPadding), // Match button padding
                  child: Text(
                    '${item.amount}',
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
                tokenProvider.addTokens(item, multiplier, summoningSick);
              },
              onLongPress: () {
                final multiplier = context.read<SettingsProvider>().tokenMultiplier;
                final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                tokenProvider.addTokens(item, multiplier * 10, summoningSick);
              },
              color: primaryColor,
              spacing: spacing,
            ),

            if (!item.isEmblem) ...[
              // Untap button
              _buildActionButton(
                context,
                icon: Icons.screenshot,
                onTap: () => tokenProvider.untapTokens(item, 1),
                onLongPress: () => tokenProvider.untapTokens(item, item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Tap button
              _buildActionButton(
                context,
                icon: Icons.screen_rotation,
                onTap: () => tokenProvider.tapTokens(item, 1),
                onLongPress: () => tokenProvider.tapTokens(item, item.amount - item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Clear Summoning Sickness button (always shown when enabled, disabled if nothing to clear)
              if (summoningSicknessEnabled)
                _buildActionButton(
                  context,
                  icon: Icons.adjust,
                  onTap: item.summoningSick > 0 ? () {
                    item.summoningSick = 0;
                    tokenProvider.updateItem(item);
                  } : null,
                  onLongPress: null,
                  color: primaryColor,
                  spacing: spacing,
                  disabled: item.summoningSick == 0,
                ),
              // Copy button
              _buildActionButton(
                context,
                icon: Icons.content_copy,
                onTap: () {
                  final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                  tokenProvider.copyToken(item, summoningSick);
                },
                onLongPress: null,
                color: primaryColor,
                spacing: spacing,
              ),

              // Split Stack button (always shown, disabled if 1 or fewer tokens)
              _buildActionButton(
                context,
                icon: Icons.call_split,
                onTap: item.amount > 1 ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SplitStackSheet(
                      item: item,
                      // No onSplitCompleted callback - sheet dismisses itself
                    ),
                  );
                } : null,
                onLongPress: null,
                color: primaryColor,
                spacing: spacing,
                disabled: item.amount <= 1,
              ),
            ],

            // Scute Swarm special button (last button gets 0 spacing)
            if (item.name.toLowerCase().contains('scute swarm'))
              _buildActionButton(
                context,
                icon: Icons.bug_report,
                onTap: () {
                  final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                  tokenProvider.addTokens(item, item.amount, summoningSick);
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

    // Use card background color for button backgrounds (only when artwork exists)
    final buttonBackgroundColor = item.artworkUrl != null
        ? Theme.of(context).cardColor.withValues(alpha: 0.85)
        : effectiveColor.withValues(alpha: 0.15); // Original transparent style when no artwork

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
    final crop = ArtworkManager.getCropPercentages();

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius), // 8px to fit inside 4px border
              child: CroppedArtworkWidget(
                imageFile: snapshot.data!,
                cropLeft: crop['left']!,
                cropRight: crop['right']!,
                cropTop: crop['top']!,
                cropBottom: crop['bottom']!,
                fillWidth: true,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build fadeout artwork layer (right-side with gradient)
  Widget _buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages();
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * 0.50;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: artworkWidth,
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return ClipRRect(
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
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build semi-transparent overlay layer
  ///
  /// NOTE: This method is currently UNUSED but preserved for potential future use.
  /// It provides a way to dim the entire artwork with a semi-transparent overlay
  /// if text contrast becomes insufficient. Currently, text background boxes
  /// provide adequate readability without needing this global dimming effect.
  ///
  /// To enable: Add to Stack between artwork layer and content layer:
  /// ```dart
  /// if (item.artworkUrl != null && artworkStyle == 'fullView')
  ///   _buildOverlayLayer(context),
  /// ```
  Widget _buildOverlayLayer(BuildContext context) {
    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.5), // 0.5 alpha overlay
          borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius), // 8px to match artwork layer
        ),
      ),
    );
  }

  /// Wrap text with solid background for readability over artwork
  Widget _buildTextWithBackground({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  }) {
    // Only add background if artwork exists
    if (item.artworkUrl == null) {
      return child;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.85), // Semi-transparent card color
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

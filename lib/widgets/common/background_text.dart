import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// A widget that displays text with a semi-transparent background for readability.
///
/// Used across all card types (TokenCard, TrackerWidgetCard, ToggleWidgetCard)
/// to ensure text is readable over:
/// - Artwork backgrounds (artworkUrl != null)
/// - Gradient backgrounds (artworkUrl == null/empty)
///
/// The background opacity is controlled by UIConstants.textBackgroundOpacity.
class BackgroundText extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const BackgroundText({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: UIConstants.textBackgroundOpacity),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

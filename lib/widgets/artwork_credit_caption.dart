import 'package:flutter/material.dart';
import 'mana/mana_icons.dart';

class ArtworkCreditCaption extends StatelessWidget {
  final String artist;
  final WrapAlignment alignment;
  final TextStyle? style;

  const ArtworkCreditCaption({
    super.key,
    required this.artist,
    this.alignment = WrapAlignment.start,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final semanticsLabel =
        artist == 'Artist unknown' ? artist : 'Artist $artist';
    final effectiveStyle = style ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.85),
            );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [
            Icon(
              ManaIcons.artistNib,
              size: effectiveStyle?.fontSize ?? 14,
              color: effectiveStyle?.color,
            ),
            Text(artist, style: effectiveStyle),
          ],
        ),
      ),
    );
  }
}

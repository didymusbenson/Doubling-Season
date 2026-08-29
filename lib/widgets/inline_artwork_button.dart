import 'package:flutter/material.dart';

import '../utils/constants.dart';

class InlineArtworkButton extends StatelessWidget {
  const InlineArtworkButton({
    super.key,
    required this.hasArtwork,
    required this.onPressed,
  });

  final bool hasArtwork;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = hasArtwork ? 'Change artwork' : 'Choose artwork';
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(UIConstants.smallBorderRadius),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: UIConstants.iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

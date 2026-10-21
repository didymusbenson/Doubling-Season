import 'package:flutter/material.dart';

import '../controllers/token_edit_session.dart';

/// Presentation-neutral inline editor used inside an expanded token card.
class InlineTokenEditField extends StatelessWidget {
  const InlineTokenEditField({
    super.key,
    required this.session,
    required this.field,
    required this.readOnlyChild,
    required this.semanticLabel,
    this.maxLines = 1,
    this.textAlign = TextAlign.left,
    this.textCapitalization = TextCapitalization.none,
    this.editorStyle,
    this.editorDecoration,
    this.editorConstraints,
  });

  final TokenEditSession session;
  final TokenEditableField field;
  final Widget readOnlyChild;
  final String semanticLabel;
  final int? maxLines;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final TextStyle? editorStyle;
  final InputDecoration? editorDecoration;
  final BoxConstraints? editorConstraints;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final editing = session.activeField == field;
        if (!editing) {
          return Semantics(
            button: true,
            label: semanticLabel,
            hint: 'Double tap to edit',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final began = await session.begin(field);
                if (!began || !context.mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 180),
                      alignmentPolicy:
                          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                    );
                  }
                });
                // The first pass runs before keyboard insets settle on some
                // devices. Repeat after the keyboard animation so the cursor
                // cannot end up hidden at the bottom of the board.
                await Future<void>.delayed(const Duration(milliseconds: 350));
                if (context.mounted && session.activeField == field) {
                  await Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 180),
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                  );
                }
              },
              child: readOnlyChild,
            ),
          );
        }
        final editor = TextField(
          controller: session.controllers[field],
          focusNode: session.focusNodes[field],
          maxLines: maxLines,
          textAlign: textAlign,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.done,
          style: editorStyle,
          decoration: editorDecoration ??
              const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
          onSubmitted: (_) => session.commit(field),
        );
        return editorConstraints == null
            ? editor
            : ConstrainedBox(constraints: editorConstraints!, child: editor);
      },
    );
  }
}

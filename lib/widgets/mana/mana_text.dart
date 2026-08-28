import 'package:flutter/material.dart';

import '../../utils/mana_symbol_parser.dart';

class ManaText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const ManaText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final baseSize = effectiveStyle.fontSize ?? 14;
    final symbolSize = MediaQuery.textScalerOf(context).scale(baseSize) * 1.1;

    return Semantics(
      label: ManaSymbolParser.semanticText(text),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: ManaSymbolParser.buildSpans(
            text: text,
            symbolSize: symbolSize,
            textColor: effectiveStyle.color,
          ),
        ),
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

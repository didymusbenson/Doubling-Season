import 'package:flutter/widgets.dart';

import '../widgets/mana/mana_symbol.dart';

class ManaSymbolParser {
  ManaSymbolParser._();

  static final RegExp _symbolPattern = RegExp(r'\{([^{}]+)\}');

  static List<InlineSpan> buildSpans({
    required String text,
    required double symbolSize,
    required Color? textColor,
  }) {
    if (!text.contains('{')) return <InlineSpan>[TextSpan(text: text)];

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _symbolPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final code = match.group(1)!;
      if (ManaSymbol.supports(code)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ManaSymbol(
              code: code,
              size: symbolSize,
              textColor: textColor,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: match.group(0)!));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  static String semanticText(String text) {
    if (!text.contains('{')) return text;
    return text.replaceAllMapped(_symbolPattern, (match) {
      final code = match.group(1)!;
      return ManaSymbol.supports(code)
          ? ManaSymbol.spokenLabel(code)
          : match.group(0)!;
    });
  }
}

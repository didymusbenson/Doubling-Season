import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds the explicit accessible name on a control, independent of the
/// accessibility pipeline being enabled for this widget test. Token actions
/// include their player/token context before the local action name.
Finder byControlLabel(Pattern label) => find.byWidgetPredicate((widget) {
  if (widget is! Semantics) return false;
  final name = widget.properties.label;
  if (name == null) return false;
  if (label is String) return name == label || name.endsWith(', $label');
  return label.allMatches(name).isNotEmpty;
}, description: 'control with accessible name $label');

/// Compact drawer actions retain their full accessible name; standalone
/// workspace hosts still paint that name as the button's text.
Finder byActionNamePrefix(String prefix) => find.byWidgetPredicate((widget) {
  final name = widget is Semantics
      ? widget.properties.label
      : widget is Text
      ? widget.data
      : null;
  return name?.startsWith(prefix) == true;
}, description: 'action with name starting $prefix');

/// Reveal every adaptive seat's Utilities view before utility-only assertions.
/// Wide seats have no tab and remain unchanged.
Future<void> showAdaptiveUtilities(
  WidgetTester tester, {
  String? playerId,
}) async {
  final tabs = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        (playerId == null
            ? key.value.endsWith('-utilities-tab')
            : key.value == '$playerId-utilities-tab');
  });
  for (final element in tabs.evaluate().toList()) {
    await tester.tap(find.byWidget(element.widget));
    await tester.pumpAndSettle();
  }
}

/// Open the player-facing utilities/customization menu from its lane FAB.
Future<void> openPlayerTools(
  WidgetTester tester, {
  required String playerId,
}) async {
  await showAdaptiveUtilities(tester, playerId: playerId);
  await tester.tap(find.byKey(ValueKey('$playerId-utility-tools')));
  await tester.pumpAndSettle();
}

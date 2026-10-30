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

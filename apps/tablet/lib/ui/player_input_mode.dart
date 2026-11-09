import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Follow the physical phone presentation, not a narrow tablet window.
/// The explicit web phone preview uses its window to emulate that presentation.
bool usesNativePlayerInput(BuildContext context) {
  if (kIsWeb) {
    const preview =
        bool.fromEnvironment('TABLE_PHONE_PREVIEW') ||
        String.fromEnvironment('TABLE_STORAGE_NAMESPACE') == 'phone_preview_v1';
    return preview && MediaQuery.sizeOf(context).shortestSide < 600;
  }
  final display = View.of(context).display;
  return (display.size / display.devicePixelRatio).shortestSide < 600;
}

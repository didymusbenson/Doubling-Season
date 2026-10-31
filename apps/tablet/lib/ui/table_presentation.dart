import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/table_controller.dart';
import 'table_screen.dart';

/// A phone shows Player 1; the session always remains its configured N players.
/// Physical display size prevents a narrow tablet window becoming phone mode.
class TablePresentation extends StatelessWidget {
  const TablePresentation({super.key, required this.controller});
  final TableController controller;

  static bool compact({
    required Size display,
    required Size window,
    required bool web,
    required bool webPhonePreview,
  }) {
    if (web) return webPhonePreview && window.shortestSide < 600;
    return display.shortestSide < 600;
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final display = view.display.size / view.display.devicePixelRatio;
    final phone = compact(
      display: display,
      window: MediaQuery.sizeOf(context),
      web: kIsWeb,
      webPhonePreview:
          const bool.fromEnvironment('TABLE_PHONE_PREVIEW') ||
          const String.fromEnvironment('TABLE_STORAGE_NAMESPACE') ==
              'phone_preview_v1',
    );
    return TableScreen(
      controller: controller,
      enablePhonePresentation: true,
      compactPlayerOne: phone,
    );
  }
}

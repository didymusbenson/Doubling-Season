import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Owns fullscreen presentation only while the loaded table is in the foreground.
/// This never changes notification permissions, Focus, or Do Not Disturb.
class GameSystemUi extends StatefulWidget {
  const GameSystemUi({super.key, required this.child});

  final Widget child;

  @override
  State<GameSystemUi> createState() => _GameSystemUiState();
}

class _GameSystemUiState extends State<GameSystemUi>
    with WidgetsBindingObserver {
  static const _android = MethodChannel('com.loosetie.triplingtable/system_ui');
  Timer? _keyboardRestore;
  bool _keyboardVisible = false;
  bool _active = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    if (_active) _apply(true);
  }

  void _apply(bool immersive) {
    if (!_supported) return;
    unawaited(_setMode(immersive));
  }

  Future<void> _setMode(bool immersive) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Flutter's legacy immersive flags are ignored by newer target SDKs.
        // The native host uses WindowInsetsController without opting out of
        // edge-to-edge or lowering the target SDK.
        await _android.invokeMethod<void>('setImmersive', immersive);
      } else {
        await SystemChrome.setEnabledSystemUIMode(
          immersive ? SystemUiMode.immersiveSticky : SystemUiMode.manual,
          overlays: immersive ? null : SystemUiOverlay.values,
        );
      }
    } on PlatformException catch (error) {
      debugPrint('Could not update table system bars: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Table system bars are unavailable: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _keyboardRestore?.cancel();
    final active = state == AppLifecycleState.resumed;
    if (_active == active) return;
    _active = active;
    _apply(active);
  }

  @override
  void didChangeMetrics() {
    final keyboardVisible = WidgetsBinding.instance.platformDispatcher.views
        .any((view) => view.viewInsets.bottom > 0);
    if (keyboardVisible == _keyboardVisible) return;
    _keyboardVisible = keyboardVisible;
    _keyboardRestore?.cancel();
    if (!keyboardVisible && _active) {
      // Android prevents hiding system bars for one second after IME dismissal.
      _keyboardRestore = Timer(const Duration(milliseconds: 1100), () {
        if (mounted && _active && !_keyboardVisible) _apply(true);
      });
    }
  }

  @override
  void dispose() {
    _keyboardRestore?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _apply(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

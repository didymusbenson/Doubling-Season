import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rules_provider.dart';
import 'rules_sheet.dart';

class MultiplierView extends StatefulWidget {
  const MultiplierView({super.key});

  /// Show a tooltip above the rules FAB from anywhere in the widget tree.
  /// Call this after companion tokens are created by rules.
  static void showTooltip(BuildContext context, String message) {
    _MultiplierViewState._activeState?.showTooltip(message);
  }

  @override
  State<MultiplierView> createState() => _MultiplierViewState();
}

class _MultiplierViewState extends State<MultiplierView>
    with SingleTickerProviderStateMixin {
  static _MultiplierViewState? _activeState;

  late AnimationController _tooltipController;
  late Animation<double> _tooltipOpacity;
  late Animation<Offset> _tooltipSlide;
  String _tooltipMessage = '';
  OverlayEntry? _tooltipOverlay;

  @override
  void initState() {
    super.initState();
    _activeState = this;
    _tooltipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Fade up+in for first 300ms, hold, then fade down+out for last 300ms
    _tooltipOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_tooltipController);

    // Slide up slightly on enter, back down on exit
    _tooltipSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0.3), end: Offset.zero),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 70),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, 0.3)),
        weight: 15,
      ),
    ]).animate(_tooltipController);

    _tooltipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _removeTooltipOverlay();
      }
    });
  }

  @override
  void dispose() {
    if (_activeState == this) _activeState = null;
    _tooltipController.dispose();
    _removeTooltipOverlay();
    super.dispose();
  }

  void _removeTooltipOverlay() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void showTooltip(String message) {
    // Reset if already showing
    _removeTooltipOverlay();
    _tooltipController.reset();
    _tooltipMessage = message;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final fabPosition = renderBox.localToGlobal(Offset.zero);
    final fabSize = renderBox.size;

    _tooltipOverlay = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _tooltipController,
        builder: (context, child) {
          return Positioned(
            left: fabPosition.dx,
            bottom: MediaQuery.of(context).size.height -
                fabPosition.dy +
                8, // 8px gap above FAB
            child: SlideTransition(
              position: _tooltipSlide,
              child: Opacity(
                opacity: _tooltipOpacity.value,
                child: Container(
                  width: fabSize.width + 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _tooltipMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    overlay.insert(_tooltipOverlay!);
    _tooltipController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RulesProvider>(
      builder: (context, rulesProvider, child) {
        final hasActive = rulesProvider.hasActiveRules;
        final label = _buildLabel(rulesProvider);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton.extended(
              onPressed: () => RulesSheet.show(context),
              heroTag: 'multiplier_fab',
              icon: const Icon(Icons.calculate, size: 24),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              extendedPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            if (hasActive)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _buildLabel(RulesProvider rulesProvider) {
    if (!rulesProvider.hasActiveRules) return 'Rules';

    final results = rulesProvider.evaluateRules(
        'Generic', '1/1', '', 'Token Creature', '', 1);

    if (results.length == 1 && results.first.quantity > 1) {
      return '\u00d7${results.first.quantity}';
    }

    return 'Rules';
  }
}

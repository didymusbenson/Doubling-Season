import 'dart:async';

import 'package:flutter/material.dart';

/// Two complete, player-local hit regions. The display never intercepts a tap;
/// editing, when offered, has its own target outside the stepped area.
class HalfStepper extends StatelessWidget {
  final String label, value;
  final VoidCallback? onDecrease, onIncrease;
  final VoidCallback? onDecreaseHold, onIncreaseHold, onEdit;

  /// Numeric holds await each update before scheduling another, preventing a
  /// backlog of persisted changes after the finger lifts. Amount is unsigned.
  final FutureOr<void> Function(int amount)? onDecreaseHoldStep,
      onIncreaseHoldStep;
  final int holdStep;
  final Duration? holdRepeatInterval;
  final int interactionEpoch;
  final double height;
  final double iconSize, iconPadding, iconY, displayPadding;
  final Color? foregroundColor;
  final TextStyle? valueStyle;
  final Widget? valueWidget;

  /// A read-only full-surface display, used for the life name/total overlay.
  final Widget? displayOverlay;

  /// Rectangles in the full stepped area's local coordinates that ink must
  /// leave clear. This clips painting only; both halves keep rectangular hits.
  final List<Rect> inkExclusions;
  final Key? decreaseKey, increaseKey, editKey;
  final String? decreaseLabel, increaseLabel;
  final String? decreaseHint, increaseHint, editLabel, editHint;

  const HalfStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    this.onDecreaseHold,
    this.onIncreaseHold,
    this.onEdit,
    this.onDecreaseHoldStep,
    this.onIncreaseHoldStep,
    this.holdStep = 5,
    this.holdRepeatInterval = const Duration(milliseconds: 300),
    this.interactionEpoch = 0,
    this.height = 44,
    this.iconSize = 19,
    this.iconPadding = 8,
    this.iconY = 0,
    this.displayPadding = 27,
    this.foregroundColor,
    this.valueStyle,
    this.valueWidget,
    this.displayOverlay,
    this.inkExclusions = const [],
    this.decreaseKey,
    this.increaseKey,
    this.decreaseLabel,
    this.increaseLabel,
    this.decreaseHint,
    this.increaseHint,
    this.editKey,
    this.editLabel,
    this.editHint,
  });

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: height,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Expanded(
                        child: _StepHalf(
                          key: decreaseKey,
                          label: decreaseLabel ?? '$label, decrease',
                          hint: decreaseHint,
                          inkExclusions: inkExclusions,
                          value: value,
                          onTap: onDecrease,
                          onHold: onDecrease == null ? null : onDecreaseHold,
                          onHoldStep: onDecrease == null
                              ? null
                              : onDecreaseHoldStep,
                          holdStep: holdStep,
                          repeatInterval: holdRepeatInterval,
                          epoch: interactionEpoch,
                          color: color,
                          iconSize: iconSize,
                          iconPadding: iconPadding,
                          iconY: iconY,
                          increase: false,
                        ),
                      ),
                      Expanded(
                        child: _StepHalf(
                          key: increaseKey,
                          label: increaseLabel ?? '$label, increase',
                          hint: increaseHint,
                          inkExclusions: inkExclusions,
                          value: value,
                          onTap: onIncrease,
                          onHold: onIncrease == null ? null : onIncreaseHold,
                          onHoldStep: onIncrease == null
                              ? null
                              : onIncreaseHoldStep,
                          holdStep: holdStep,
                          repeatInterval: holdRepeatInterval,
                          epoch: interactionEpoch,
                          color: color,
                          iconSize: iconSize,
                          iconPadding: iconPadding,
                          iconY: iconY,
                          increase: true,
                        ),
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child:
                          displayOverlay ??
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: displayPadding,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child:
                                    valueWidget ??
                                    Text(
                                      value,
                                      style:
                                          valueStyle ??
                                          Theme.of(context).textTheme.titleLarge
                                              ?.copyWith(color: color),
                                    ),
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onEdit != null)
            SizedBox(
              width: 44,
              height: height,
              child: Semantics(
                key: editKey,
                label: editLabel ?? 'Edit $label',
                hint: editHint,
                button: true,
                onTap: onEdit,
                excludeSemantics: true,
                child: IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 19, color: color),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reuse the numeric hold policy for a compact single +/- button.
class NumericHoldRegion extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback? onTap;
  final FutureOr<void> Function(int)? onStep;
  final int step, interactionEpoch;
  const NumericHoldRegion({
    super.key,
    required this.child,
    required this.label,
    required this.onTap,
    required this.onStep,
    this.step = 5,
    this.interactionEpoch = 0,
  });
  @override
  Widget build(BuildContext context) => _StepHalf(
    label: label,
    value: '',
    onTap: onTap,
    onHold: null,
    onHoldStep: onStep,
    holdStep: step,
    repeatInterval: null,
    epoch: interactionEpoch,
    color: Theme.of(context).colorScheme.onSurface,
    increase: true,
    iconSize: 19,
    iconPadding: 0,
    iconY: 0,
    customChild: child,
  );
}

class _StepHalf extends StatefulWidget {
  final String label, value;
  final String? hint;
  final List<Rect> inkExclusions;
  final VoidCallback? onTap, onHold;
  final FutureOr<void> Function(int)? onHoldStep;
  final int holdStep;
  final Duration? repeatInterval;
  final int epoch;
  final Color color;
  final bool increase;
  final double iconSize, iconPadding, iconY;
  final Widget? customChild;
  const _StepHalf({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onHold,
    required this.onHoldStep,
    required this.holdStep,
    required this.repeatInterval,
    required this.epoch,
    required this.color,
    required this.increase,
    required this.iconSize,
    required this.iconPadding,
    required this.iconY,
    this.customChild,
    this.hint,
    this.inkExclusions = const [],
  });

  @override
  State<_StepHalf> createState() => _StepHalfState();
}

class _StepHalfState extends State<_StepHalf> with WidgetsBindingObserver {
  Timer? _repeat, _accelerate, _fast;
  int _gesture = 0, _phase = 0;
  void _stop() {
    _gesture++;
    _repeat?.cancel();
    _accelerate?.cancel();
    _fast?.cancel();
    _repeat = _accelerate = _fast = null;
    _phase = 0;
  }

  int get _amount => _phase == 0
      ? widget.holdStep
      : (_phase == 1 ? 10 : 25).clamp(widget.holdStep, 1000000);
  Duration get _interval =>
      Duration(milliseconds: _phase == 0 ? 300 : (_phase == 1 ? 150 : 80));

  Future<void> _numericTick(int gesture) async {
    if (!mounted || gesture != _gesture) return;
    try {
      await widget.onHoldStep?.call(_amount);
    } catch (_) {
      // The action owns presentation of persistence/validation errors.
      if (gesture == _gesture) _stop();
      return;
    }
    if (!mounted || gesture != _gesture) return;
    _repeat = Timer(_interval, () => _numericTick(gesture));
  }

  void _hold() {
    _stop();
    if (widget.onHoldStep != null) {
      final gesture = _gesture;
      _accelerate = Timer(const Duration(seconds: 2), () => _phase = 1);
      _fast = Timer(const Duration(seconds: 5), () => _phase = 2);
      unawaited(_numericTick(gesture));
    } else {
      widget.onHold?.call();
      final interval = widget.repeatInterval;
      if (interval != null) {
        _repeat = Timer.periodic(interval, (_) => widget.onHold?.call());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _StepHalf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.epoch != widget.epoch ||
        widget.onTap == null ||
        (widget.onHold == null && widget.onHoldStep == null)) {
      _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    hint: widget.hint,
    value: widget.value,
    button: true,
    enabled: widget.onTap != null,
    onTap: widget.onTap,
    onLongPress: widget.onTap == null
        ? null
        : widget.onHoldStep != null
        ? () => widget.onHoldStep!(widget.holdStep)
        : widget.onHold,
    excludeSemantics: true,
    child: Listener(
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: InkWell(
        customBorder: widget.inkExclusions.isEmpty
            ? null
            : _StepperInkBorder(
                exclusions: widget.inkExclusions,
                increase: widget.increase,
              ),
        // A disabled half still owns its gesture so a surrounding card cannot
        // expand or run another action when the zero decrement is tapped.
        onTap: widget.onTap ?? () {},
        onLongPress: widget.onTap == null
            ? () {}
            : widget.onHold == null && widget.onHoldStep == null
            ? null
            : _hold,
        canRequestFocus: widget.onTap != null,
        enableFeedback: widget.onTap != null,
        overlayColor: widget.onTap == null
            ? const WidgetStatePropertyAll(Colors.transparent)
            : null,
        splashFactory: widget.onTap == null ? NoSplash.splashFactory : null,
        excludeFromSemantics: true,
        child:
            widget.customChild ??
            Align(
              alignment: Alignment(widget.increase ? 1 : -1, widget.iconY),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.iconPadding),
                child: Icon(
                  widget.increase ? Icons.add : Icons.remove,
                  size: widget.iconSize,
                  color: widget.onTap == null
                      ? widget.color.withValues(alpha: .38)
                      : widget.color,
                ),
              ),
            ),
      ),
    ),
  );
}

/// InkWell uses this border for splash, hover and focus painting, independently
/// of its rectangular GestureDetector. The right half shares the same surface
/// geometry as the left, translated by exactly one half width.
class _StepperInkBorder extends ShapeBorder {
  final List<Rect> exclusions;
  final bool increase;
  const _StepperInkBorder({required this.exclusions, required this.increase});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final offset = Offset(rect.left - (increase ? rect.width : 0), rect.top);
    final holes = Path();
    for (final area in exclusions) {
      holes.addRect(area.shift(offset));
    }
    return Path.combine(PathOperation.difference, Path()..addRect(rect), holes);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _StepperInkBorder(
    exclusions: exclusions
        .map(
          (area) => Rect.fromLTRB(
            area.left * t,
            area.top * t,
            area.right * t,
            area.bottom * t,
          ),
        )
        .toList(),
    increase: increase,
  );
}

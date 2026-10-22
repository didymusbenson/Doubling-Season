import 'dart:async';

import 'package:flutter/material.dart';

/// Two complete, player-local hit regions. The display never intercepts a tap;
/// editing, when offered, has its own target outside the stepped area.
class HalfStepper extends StatelessWidget {
  final String label, value;
  final VoidCallback? onDecrease, onIncrease;
  final VoidCallback? onDecreaseHold, onIncreaseHold, onEdit;
  final Duration? holdRepeatInterval;
  final int interactionEpoch;
  final double height;
  final Color? foregroundColor;
  final TextStyle? valueStyle;
  final Widget? valueWidget;
  final Key? decreaseKey, increaseKey, editKey;
  final String? decreaseLabel, increaseLabel;
  final String? decreaseTooltip, increaseTooltip, editLabel, editTooltip;

  const HalfStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    this.onDecreaseHold,
    this.onIncreaseHold,
    this.onEdit,
    this.holdRepeatInterval = const Duration(milliseconds: 300),
    this.interactionEpoch = 0,
    this.height = 44,
    this.foregroundColor,
    this.valueStyle,
    this.valueWidget,
    this.decreaseKey,
    this.increaseKey,
    this.decreaseLabel,
    this.increaseLabel,
    this.decreaseTooltip,
    this.increaseTooltip,
    this.editKey,
    this.editLabel,
    this.editTooltip,
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
                          tooltip:
                              decreaseTooltip ??
                              decreaseLabel ??
                              '$label, decrease',
                          value: value,
                          onTap: onDecrease,
                          onHold: onDecrease == null ? null : onDecreaseHold,
                          repeatInterval: holdRepeatInterval,
                          epoch: interactionEpoch,
                          color: color,
                          increase: false,
                        ),
                      ),
                      Expanded(
                        child: _StepHalf(
                          key: increaseKey,
                          label: increaseLabel ?? '$label, increase',
                          tooltip:
                              increaseTooltip ??
                              increaseLabel ??
                              '$label, increase',
                          value: value,
                          onTap: onIncrease,
                          onHold: onIncrease == null ? null : onIncreaseHold,
                          repeatInterval: holdRepeatInterval,
                          epoch: interactionEpoch,
                          color: color,
                          increase: true,
                        ),
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 27),
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
                label: editLabel ?? editTooltip ?? 'Edit $label',
                button: true,
                onTap: onEdit,
                excludeSemantics: true,
                child: IconButton(
                  tooltip: editTooltip ?? editLabel ?? 'Edit $label',
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

class _StepHalf extends StatefulWidget {
  final String label, tooltip, value;
  final VoidCallback? onTap, onHold;
  final Duration? repeatInterval;
  final int epoch;
  final Color color;
  final bool increase;
  const _StepHalf({
    super.key,
    required this.label,
    required this.tooltip,
    required this.value,
    required this.onTap,
    required this.onHold,
    required this.repeatInterval,
    required this.epoch,
    required this.color,
    required this.increase,
  });

  @override
  State<_StepHalf> createState() => _StepHalfState();
}

class _StepHalfState extends State<_StepHalf> with WidgetsBindingObserver {
  Timer? _repeat;
  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _hold() {
    _stop();
    widget.onHold?.call();
    final interval = widget.repeatInterval;
    if (interval != null) {
      _repeat = Timer.periodic(interval, (_) => widget.onHold?.call());
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
        widget.onHold == null) {
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
    value: widget.value,
    button: true,
    enabled: widget.onTap != null,
    onTap: widget.onTap,
    onLongPress: widget.onTap == null ? null : widget.onHold,
    excludeSemantics: true,
    child: Tooltip(
      message: widget.tooltip,
      child: Listener(
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: InkWell(
          // A disabled half still owns its gesture so a surrounding card cannot
          // expand or run another action when the zero decrement is tapped.
          onTap: widget.onTap ?? () {},
          onLongPress: widget.onTap == null
              ? () {}
              : widget.onHold == null
              ? null
              : _hold,
          canRequestFocus: widget.onTap != null,
          enableFeedback: widget.onTap != null,
          overlayColor: widget.onTap == null
              ? const WidgetStatePropertyAll(Colors.transparent)
              : null,
          splashFactory: widget.onTap == null ? NoSplash.splashFactory : null,
          excludeFromSemantics: true,
          child: Align(
            alignment: widget.increase
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                widget.increase ? Icons.add : Icons.remove,
                size: 19,
                color: widget.onTap == null
                    ? widget.color.withValues(alpha: .38)
                    : widget.color,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

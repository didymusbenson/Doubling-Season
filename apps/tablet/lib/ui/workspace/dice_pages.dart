part of 'table_workspace.dart';

bool _prefersReducedDiceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    // Flutter 3.41 exposes iOS Reduce Motion only through the engine feature;
    // it is separate from Android disableAnimations and VoiceOver navigation.
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion ||
    platformPrefersReducedDiceMotion();

extension _DicePages on _TableWorkspaceState {
  Future<void> _rollSelectedDice({bool again = false}) async {
    if (_diceRolling || _working || _closing || _navigating || !_validScope) {
      return;
    }
    // Lock before navigation yields: repeated taps accept just one roll.
    _update(() => _diceRolling = true);
    if (!again) await _go(WorkspacePage.diceResults);
    if (!mounted) return;
    if (_closing || _page != WorkspacePage.diceResults || !_validScope) {
      _update(() => _diceRolling = false);
      return;
    }
    // Only this immutable snapshot uses randomness. Animation never rerolls it.
    final roll = DiceRoll.generate(_diceCounts);
    _update(() {
      _diceRoll = roll;
      _diceRollSerial++;
      _diceRolling =
          roll.groups.isNotEmpty && !_prefersReducedDiceMotion(context);
    });
  }

  Widget _diceBody({required Widget child, required Key scrollKey}) => _embedded
      ? GameDrawerBody(
          centered: true,
          scrollKey: scrollKey,
          wideMaxContentWidth: 760,
          child: child,
        )
      : SingleChildScrollView(
          key: scrollKey,
          // Both selector silhouettes and result headings clear the standalone
          // top-right controls (6px offset +44px targets +6px breathing room).
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Center(child: child),
        );

  Widget _dicePage() => _diceBody(
    scrollKey: const PageStorageKey('dice-scroll'),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final gap = _embedded ? 8.0 : 12.0;
        // Each card owns two full-height halves, at least 48px wide each.
        // Reduce columns rather than shrinking the tappable card regions.
        const minimumTileWidth = 104.0;
        final columns = constraints.maxWidth >= 6 * minimumTileWidth + 5 * gap
            ? 6
            : constraints.maxWidth >= 3 * minimumTileWidth + 2 * gap
            ? 3
            : constraints.maxWidth >= 2 * minimumTileWidth + gap
            ? 2
            : 1;
        final tileWidth = min(
          140.0,
          (constraints.maxWidth - (columns - 1) * gap) / columns,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const ValueKey('dice-selector'),
              width: tileWidth * columns + gap * (columns - 1),
              child: Wrap(
                spacing: gap,
                runSpacing: _embedded ? 12 : 16,
                children: [
                  for (final entry in _diceCounts.entries)
                    SizedBox(
                      key: ValueKey('dice-selection-d${entry.key}'),
                      width: tileWidth,
                      child: _diceCard(entry.key, entry.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('dice-roll-button'),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: _diceRolling || _working || _navigating
                  ? null
                  : _rollSelectedDice,
              icon: const Icon(Icons.casino_outlined),
              label: Text(_diceRollLabel, textAlign: TextAlign.center),
            ),
          ],
        );
      },
    ),
  );

  String get _diceRollLabel {
    final count = _diceCounts.values.fold(0, (sum, value) => sum + value);
    return count == 0
        ? 'Roll dice'
        : 'Roll $count ${count == 1 ? 'die' : 'dice'}';
  }

  Widget _diceCard(int sides, int count) {
    final enabled =
        !_working && !_diceRolling && !_closing && !_navigating && _validScope;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('dice-card-d$sides'),
      color: count > 0
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: HalfStepper(
        label: 'D$sides quantity',
        value: '$count',
        height: 128,
        iconSize: 22,
        iconPadding: 8,
        iconY: .7,
        foregroundColor: count > 0
            ? scheme.onSecondaryContainer
            : scheme.onSurface,
        decreaseKey: ValueKey('dice-decrease-d$sides'),
        increaseKey: ValueKey('dice-increase-d$sides'),
        decreaseLabel: 'Decrease d$sides',
        increaseLabel: 'Increase d$sides',
        onDecrease: enabled && count > 0
            ? () => _changeDiceCount(sides, -1)
            : null,
        onIncrease: enabled && count < 20
            ? () => _changeDiceCount(sides, 1)
            : null,
        onDecreaseHoldStep: (amount) => _changeDiceCount(sides, -amount),
        onIncreaseHoldStep: (amount) => _changeDiceCount(sides, amount),
        interactionEpoch: Object.hash(
          _sessionId,
          _sessionGeneration,
          _closing,
          _navigating,
          _page,
        ),
        displayOverlay: Center(
          child: DieOutline(
            key: ValueKey('dice-count-d$sides'),
            sides: sides,
            value: count,
            selected: count > 0,
            size: 64,
            semanticsLabel: 'D$sides quantity: $count',
          ),
        ),
      ),
    );
  }

  void _changeDiceCount(int sides, int delta) {
    if (_diceRolling || _working || _closing || _navigating || !_validScope) {
      return;
    }
    _update(
      () => _diceCounts[sides] = (_diceCounts[sides]! + delta).clamp(0, 20),
    );
  }

  Widget _diceResultsPage() {
    final serial = _diceRollSerial;
    return _DiceRollAnimation(
      key: ValueKey('dice-animation-$serial'),
      animate: _diceRolling,
      onFinished: () {
        if (mounted && serial == _diceRollSerial && _diceRolling) {
          // Unlock even if navigation is waiting on unrelated work.
          _diceRolling = false;
          _refresh();
        }
      },
      builder: (context, progress) => _diceResultsBody(progress),
    );
  }

  Widget _diceResultsBody(double progress) => _diceBody(
    scrollKey: const PageStorageKey('dice-results-scroll'),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final roll = _diceRoll;
        final rolling = progress < 1;
        final rolledCount =
            roll?.groups.fold(0, (count, group) => count + group.count) ?? 0;
        final gridWidth = min(
          _embedded || constraints.maxWidth + 40 >= 800 ? 612.0 : 264.0,
          constraints.maxWidth,
        );
        return Column(
          key: const ValueKey('dice-results'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (roll == null || roll.groups.isEmpty)
              const Text(
                'Select at least one die.',
                textAlign: TextAlign.center,
              ),
            if (roll != null && roll.groups.isNotEmpty)
              ExcludeSemantics(
                excluding: rolling,
                child: SizedBox(
                  width: gridWidth,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 20,
                    children: [
                      for (final group in roll.groups)
                        SizedBox(
                          width: min(
                            gridWidth,
                            group.faces.length * 80.0 +
                                max(0, group.faces.length - 1) * 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _diceGroupLabel(group),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (
                                    var face = 0;
                                    face < group.faces.length;
                                    face++
                                  )
                                    SizedBox(
                                      width: 80,
                                      child: Transform.rotate(
                                        angle: rolling
                                            ? sin(
                                                    progress * pi * 8 +
                                                        face * .7,
                                                  ) *
                                                  .10 *
                                                  (1 - progress)
                                            : 0,
                                        child: Transform.scale(
                                          scale: rolling
                                              ? .94 + .06 * progress
                                              : 1,
                                          child: DieOutline(
                                            key: ValueKey(
                                              'dice-result-d${group.sides}-$face',
                                            ),
                                            sides: group.sides,
                                            value: rolling
                                                ? 1 +
                                                      ((progress * 12).floor() +
                                                              face * 3) %
                                                          group.sides
                                                : group.faces[face],
                                            selected: true,
                                            size: 72,
                                            showDenomination: false,
                                            semanticsLabel:
                                                'D${group.sides} result ${face + 1}: ${group.faces[face]}',
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (group.faces.length > 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                  rolling
                                      ? 'Subtotal: —'
                                      : 'Subtotal: ${group.total}',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                rolling ? 'Rolling…' : 'Total: ${roll?.total ?? 0}',
                key: const ValueKey('dice-summary'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Text(
              '$rolledCount ${rolledCount == 1 ? 'die' : 'dice'} ${rolling ? 'rolling' : 'rolled'}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('dice-reroll-button'),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: _diceRolling || _working || _navigating
                  ? null
                  : () => _rollSelectedDice(again: true),
              icon: const Icon(Icons.refresh),
              label: Text(rolling ? 'Rolling…' : 'Roll again'),
            ),
          ],
        );
      },
    ),
  );

  Widget _diceGroupLabel(DiceRollGroup group) => Text(
    '${group.faces.length} × D${group.sides}',
    key: ValueKey('dice-group-d${group.sides}'),
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.titleMedium,
  );
}

/// Motion belongs to the current result surface, never to the saved game.
/// Disposing or interrupting the surface releases the repeat-tap lock.
class _DiceRollAnimation extends StatefulWidget {
  const _DiceRollAnimation({
    super.key,
    required this.animate,
    required this.onFinished,
    required this.builder,
  });

  final bool animate;
  final VoidCallback onFinished;
  final Widget Function(BuildContext, double) builder;

  @override
  State<_DiceRollAnimation> createState() => _DiceRollAnimationState();
}

class _DiceRollAnimationState extends State<_DiceRollAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 375),
      )..addListener(() {
        if (_animation.value == 1) _finish();
      });
  bool _started = false;
  bool _finished = false;
  late final void Function() _removeMotionListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _removeMotionListener = listenToPlatformReducedDiceMotion((reduced) {
      if (mounted && reduced) _settle();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    // Completion can happen during a rebuild or disposal; never mutate the
    // workspace until that frame has finished, and let it check roll identity.
    final notify = widget.onFinished;
    WidgetsBinding.instance.addPostFrameCallback((_) => notify());
  }

  void _settle() {
    _animation.value = 1;
    _finish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || _prefersReducedDiceMotion(context)) {
      _settle();
    } else if (!_started) {
      _started = true;
      _animation.forward();
    }
  }

  @override
  void didUpdateWidget(_DiceRollAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) _settle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _settle();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (_prefersReducedDiceMotion(context)) _settle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeMotionListener();
    _finish();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) => widget.builder(context, _animation.value),
  );
}

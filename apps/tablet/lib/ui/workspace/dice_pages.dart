part of 'table_workspace.dart';

extension _DicePages on _TableWorkspaceState {
  Future<void> _rollSelectedDice({bool again = false}) async {
    if (_working || _closing || _navigating || !_validScope) return;
    if (!again) await _go(WorkspacePage.diceResults);
    if (!mounted || _page != WorkspacePage.diceResults || !_validScope) return;
    _update(() => _diceRoll = DiceRoll.generate(_diceCounts));
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
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          child: Center(child: child),
        );

  Widget _dicePage() => _diceBody(
    scrollKey: const PageStorageKey('dice-scroll'),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final gap = _embedded ? 8.0 : 12.0;
        // The standalone host retains its existing corner-control clearance.
        // Drawer halves remain at least44px, including the184px body.
        final columns = !_embedded
            ? (constraints.maxWidth + 40 >= 800
                  ? 6
                  : constraints.maxWidth + 40 >= 400
                  ? 3
                  : 2)
            : constraints.maxWidth >= 6 * 88 + 5 * gap
            ? 6
            : constraints.maxWidth >= 3 * 88 + 2 * gap
            ? 3
            : constraints.maxWidth >= 2 * 88 + gap
            ? 2
            : 1;
        final tileWidth = min(
          116.0,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DieOutline(
                            key: ValueKey('dice-count-d${entry.key}'),
                            sides: entry.key,
                            value: entry.value,
                            selected: entry.value > 0,
                            semanticsLabel:
                                'D${entry.key} quantity: ${entry.value}',
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                _diceStep(entry.key, entry.value, false),
                                _diceStep(entry.key, entry.value, true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('dice-roll-button'),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: _working || _navigating ? null : _rollSelectedDice,
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

  Widget _diceStep(int sides, int count, bool increase) {
    final enabled =
        !_working &&
        !_closing &&
        !_navigating &&
        (increase ? count < 20 : count > 0);
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: NumericHoldRegion(
        label: '${increase ? 'Increase' : 'Decrease'} d$sides',
        onTap: enabled
            ? () => _changeDiceCount(sides, increase ? 1 : -1)
            : null,
        onStep: enabled
            ? (amount) => _changeDiceCount(sides, increase ? amount : -amount)
            : null,
        step: 5,
        interactionEpoch: Object.hash(
          _sessionId,
          _sessionGeneration,
          _closing,
          _navigating,
          _page,
        ),
        child: Center(
          child: Icon(
            increase ? Icons.add : Icons.remove,
            color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _changeDiceCount(int sides, int delta) {
    if (_working || _closing || _navigating || !_validScope) return;
    _update(
      () => _diceCounts[sides] = (_diceCounts[sides]! + delta).clamp(0, 20),
    );
  }

  Widget _diceResultsPage() => _diceBody(
    scrollKey: const PageStorageKey('dice-results-scroll'),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final roll = _diceRoll;
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
              SizedBox(
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
                                    child: DieOutline(
                                      key: ValueKey(
                                        'dice-result-d${group.sides}-$face',
                                      ),
                                      sides: group.sides,
                                      value: group.faces[face],
                                      selected: true,
                                      size: 72,
                                      showDenomination: false,
                                      semanticsLabel:
                                          'D${group.sides} result ${face + 1}: ${group.faces[face]}',
                                    ),
                                  ),
                              ],
                            ),
                            if (group.faces.length > 1) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Subtotal: ${group.total}',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Total: ${roll?.total ?? 0}',
              key: const ValueKey('dice-summary'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '$rolledCount ${rolledCount == 1 ? 'die' : 'dice'} rolled',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('dice-reroll-button'),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: _working || _navigating
                  ? null
                  : () => _rollSelectedDice(again: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Roll again'),
            ),
          ],
        );
      },
    ),
  );

  Widget _diceGroupLabel(DiceRollGroup group) => Text(
    '${group.faces.length} × D${group.sides}',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.titleMedium,
  );
}

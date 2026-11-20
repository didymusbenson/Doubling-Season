part of 'table_workspace.dart';

// Visual reference: Disa’s Diary ManaTile / MtgColors (bb8f79d).
// State and mutations remain Tripling Table’s seat-local controller.
extension _ManaPoolPanel on _TableWorkspaceState {
  Widget _compactManaPool(
    UtilityState utility,
    WidgetDefinition? definition,
    PlayerState player,
  ) => Padding(
    key: const ValueKey('utility-detail-mana_pool'),
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: LayoutBuilder(
      builder: (context, bounds) {
        const tap = 44.0;
        const gap = 6.0;
        const tileBorder = 5.0; // Both edges of the 2.5px lock border.
        const rowActionWidth = tap * 4 + tileBorder;
        final textScale = MediaQuery.textScalerOf(context);
        // Keep the Disa WU / BR / GC grid when it fits. When height is scarce,
        // prefer more columns to shrinking any target below 44 logical pixels.
        final footerHeight = 48.0 + max(0.0, textScale.scale(14) - 14);
        (int, double, double) grid(int count) {
          final rows = (6 / count).ceil();
          final width = (bounds.maxWidth - gap * (count - 1)) / count;
          final actions = width >= rowActionWidth ? tap : 2 * tap;
          return (rows, width, actions);
        }

        double minimum(int count) {
          final (rows, _, actions) = grid(count);
          return rows * (tap + actions + tileBorder) +
              (rows - 1) * gap +
              footerHeight +
              gap;
        }

        var columns = grid(2).$2 >= 2 * tap + tileBorder ? 2 : 1;
        if (bounds.maxHeight < minimum(columns)) {
          for (final candidate in [3, 6]) {
            if (grid(candidate).$2 >= 2 * tap + tileBorder &&
                minimum(candidate) < minimum(columns)) {
              columns = candidate;
              if (bounds.maxHeight >= minimum(columns)) break;
            }
          }
        }
        final (rows, width, actions) = grid(columns);
        final availableTileHeight =
            (bounds.maxHeight - footerHeight - rows * gap) / rows;
        final mainHeight = (availableTileHeight - actions - tileBorder).clamp(
          tap,
          98.0,
        );
        final denseFooter = bounds.maxWidth < textScale.scale(310);
        final empty = OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(tap, tap),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: _working || _closing || _navigating
              ? null
              : () => _confirm(
                  'Empty mana pool?',
                  'Set all unlocked colors to zero for $_seatName. Locked colors keep their values. This is undoable in game history.',
                  () => c.emptyMana(player.id),
                  button: 'Empty unlocked mana',
                ),
          child: denseFooter
              ? Semantics(
                  label: 'Empty unlocked mana',
                  excludeSemantics: true,
                  child: const Text('Empty'),
                )
              : const Text('Empty unlocked mana', textAlign: TextAlign.center),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row != 0) const SizedBox(height: gap),
              Row(
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column != 0) const SizedBox(width: gap),
                    SizedBox(
                      width: width,
                      child: _manaControl(
                        player,
                        PlayerState.manaColors[row * columns + column],
                        height: mainHeight,
                        actionsOnOneRow: actions == tap,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: gap),
            SizedBox(
              height: footerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _utilityArtFooter(
                      utility,
                      definition,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: gap),
                  if (denseFooter) empty else Flexible(child: empty),
                ],
              ),
            ),
          ],
        );
        // Ultra-short split windows or exceptionally large text may not
        // physically fit the minimum targets. Don't clip any action there.
        return bounds.maxHeight < minimum(columns)
            ? SingleChildScrollView(
                key: const ValueKey('mana-pool-extreme-viewport-scroll'),
                child: content,
              )
            : content;
      },
    ),
  );

  Widget _manaControl(
    PlayerState player,
    String color, {
    required double height,
    required bool actionsOnOneRow,
  }) {
    final name = const {
      'W': 'White',
      'U': 'Blue',
      'B': 'Black',
      'R': 'Red',
      'G': 'Green',
      'C': 'Colorless',
    }[color]!;
    final locked = player.manaLocks.contains(color);
    final palette = const {
      'W': (Color(0xFFF9FAF4), Color(0xFFD4D0B0), ManaIcons.white),
      'U': (Color(0xFFAAE0FA), Color(0xFF7BB5D4), ManaIcons.blue),
      'B': (Color(0xFFA8A29E), Color(0xFF7A7572), ManaIcons.black),
      'R': (Color(0xFFF9AA8F), Color(0xFFD08A70), ManaIcons.red),
      'G': (Color(0xFF9BD3AE), Color(0xFF6AA07A), ManaIcons.green),
      'C': (Color(0xFFCBC2BF), Color(0xFFDED8D5), ManaIcons.colorless),
    }[color]!;
    final value = player.mana[color] ?? 0;
    final epoch = Object.hash(
      _sessionId,
      _sessionGeneration,
      _closing,
      _navigating,
      _page,
      _itemId,
      _directFailureEpoch,
    );
    return Container(
      key: ValueKey('utility-mana-$color'),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: locked ? Colors.amber.shade700 : Colors.black26,
          width: locked ? 2.5 : 1,
        ),
        boxShadow: [
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
          if (locked)
            const BoxShadow(
              color: Color(0x66FFC107),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          HalfStepper(
            height: height,
            label: '$name mana',
            value: '$value',
            decreaseLabel: 'Decrease $name mana',
            increaseLabel: 'Increase $name mana',
            onDecrease: _working || (_directPending == 0 && value == 0)
                ? null
                : () => _runDirect(() => c.adjustMana(player.id, color, -1)),
            onIncrease: _working
                ? null
                : () => _runDirect(() => c.adjustMana(player.id, color, 1)),
            onDecreaseHoldStep: (amount) =>
                _runDirect(() => c.adjustMana(player.id, color, -amount)),
            onIncreaseHoldStep: (amount) =>
                _runDirect(() => c.adjustMana(player.id, color, amount)),
            holdStep: 10,
            interactionEpoch: epoch,
            foregroundColor: Colors.black87,
            iconSize: 16,
            iconPadding: 5,
            displayOverlay: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: FittedBox(child: Icon(palette.$3, color: palette.$2)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontSize: height * .52,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Preserve explicit tens, locks and conversion without competing
          // with the reference’s main symbol/number hierarchy.
          Container(
            decoration: const BoxDecoration(color: Color(0x30FFFFFF)),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final tens = SizedBox(
                  width: actionsOnOneRow
                      ? bounds.maxWidth - 88
                      : bounds.maxWidth,
                  child: HalfStepper(
                    height: 44,
                    label: '$name mana by ten',
                    value: '10',
                    decreaseLabel: 'Decrease $name mana by ten',
                    increaseLabel: 'Increase $name mana by ten',
                    onDecrease:
                        _working ||
                            (_directPending == 0 &&
                                (player.mana[color] ?? 0) == 0)
                        ? null
                        : () => _runDirect(
                            () => c.adjustMana(player.id, color, -10),
                          ),
                    onIncrease: _working
                        ? null
                        : () => _runDirect(
                            () => c.adjustMana(player.id, color, 10),
                          ),
                    onDecreaseHoldStep: (amount) => _runDirect(
                      () => c.adjustMana(player.id, color, -amount),
                    ),
                    onIncreaseHoldStep: (amount) => _runDirect(
                      () => c.adjustMana(player.id, color, amount),
                    ),
                    holdStep: 10,
                    interactionEpoch: Object.hash(
                      _sessionId,
                      _sessionGeneration,
                      _closing,
                      _navigating,
                      _page,
                      _itemId,
                      _directFailureEpoch,
                    ),
                    foregroundColor: Colors.black87,
                    valueStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
                final lock = SizedBox.square(
                  dimension: 44,
                  child: MergeSemantics(
                    child: Semantics(
                      label:
                          '${locked ? 'Unlock' : 'Lock'} $name mana for Empty',
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        color: Colors.black87,
                        isSelected: locked,
                        onPressed: _working
                            ? null
                            : () => _run(
                                () => c.toggleManaLock(player.id, color),
                              ),
                        icon: const Icon(Icons.lock_open),
                        selectedIcon: const Icon(Icons.lock),
                      ),
                    ),
                  ),
                );
                final convert = SizedBox.square(
                  dimension: 44,
                  child: MergeSemantics(
                    child: Semantics(
                      label: 'Convert all mana to $name',
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        color: Colors.black87,
                        onPressed: _working
                            ? null
                            : () => _run(() => c.convertMana(player.id, color)),
                        icon: const Icon(Icons.compare_arrows),
                      ),
                    ),
                  ),
                );
                return actionsOnOneRow
                    ? Row(children: [tens, lock, convert])
                    : Column(
                        children: [
                          tens,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [lock, convert],
                          ),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

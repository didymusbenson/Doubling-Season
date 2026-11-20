part of 'table_workspace.dart';

// Visual reference: Disa’s Diary ManaTile / MtgColors (bb8f79d).
// State and mutations remain Tripling Table’s seat-local controller.
extension _ManaPoolPanel on _TableWorkspaceState {
  List<Widget> _manaControls(PlayerState player) => [
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text('Tap either half for ±1; hold for ±10.'),
    ),
    LayoutBuilder(
      builder: (context, constraints) {
        // Keep Disa’s WU / BR / GC reading order at every size.
        const columns = 2;
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in PlayerState.manaColors)
              SizedBox(width: width, child: _manaControl(player, color)),
          ],
        );
      },
    ),
    Align(
      alignment: Alignment.center,
      child: _button(
        'Empty unlocked mana',
        () => _confirm(
          'Empty mana pool?',
          'Set all unlocked colors to zero for $_seatName. Locked colors keep their values. This is undoable in game history.',
          () => c.emptyMana(player.id),
          button: 'Empty unlocked mana',
        ),
        icon: Icons.delete_outline,
      ),
    ),
  ];

  Widget _manaControl(PlayerState player, String color) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 180 ? 104.0 : 140.0;
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
                    : () =>
                          _runDirect(() => c.adjustMana(player.id, color, -1)),
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
                      child: FittedBox(
                        child: Icon(palette.$3, color: palette.$2),
                      ),
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
                decoration: const BoxDecoration(
                  color: Color(0x30FFFFFF),
                  border: Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 210
                          ? constraints.maxWidth
                          : constraints.maxWidth - 104,
                      child: HalfStepper(
                        height: 48,
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
                    ),
                    MergeSemantics(
                      child: Semantics(
                        label:
                            '${locked ? 'Unlock' : 'Lock'} $name mana for Empty',
                        child: IconButton(
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
                    MergeSemantics(
                      child: Semantics(
                        label: 'Convert all mana to $name',
                        child: IconButton(
                          color: Colors.black87,
                          onPressed: _working
                              ? null
                              : () =>
                                    _run(() => c.convertMana(player.id, color)),
                          icon: const Icon(Icons.compare_arrows),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

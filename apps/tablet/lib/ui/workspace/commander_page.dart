part of 'table_workspace.dart';

/// Damage and counters share one compact, player-facing popup. Owner positions
/// remain table-relative; additional sources grow their owner's row, not a form.
extension _FocusedCommanderPage on _TableWorkspaceState {
  int _largestCommanderGroup() => c.session.players
      .map(
        (owner) => c.session.commanderTrackingSources
            .where((source) => source.ownerPlayerId == owner.id)
            .length,
      )
      .fold<int>(1, max);

  double _commanderRowHeight(double ownerWidth) {
    final count = _largestCommanderGroup();
    return (ownerWidth < count * 88 ? count : 1) * (count > 1 ? 128.0 : 108.0);
  }

  double _combinedContentHeight(double width) {
    final rows = CommanderSeatLayout.rowsFor(
      c.session.players,
      widget.quarterTurns,
    );
    final ownerWidth =
        (width - 24 - (rows.first.length - 1) * 8) / rows.first.length;
    final counterColumns = _counterColumns(width - 24);
    final counterRows =
        ((p == null ? 0 : _editablePlayerCounters(p!).length) / counterColumns)
            .ceil();
    // Progress strip (2), outer padding (12), header (44), and counter gap (4).
    return 62 +
        rows.length * _commanderRowHeight(ownerWidth) +
        (rows.length - 1) * 6 +
        12 +
        _playerStatusHeight +
        8 +
        counterRows * _playerCounterHeight +
        max(0, counterRows - 1) * 8 +
        ((p?.warnings.isNotEmpty ?? false) ? 32 : 0);
  }

  Widget _focusedCommanderPage() {
    final recipient = p;
    if (recipient == null) return const Center(child: Text('Select a player.'));
    final disabled = _working || _closing || _navigating || !_validScope;
    final sources = c.session.commanderTrackingSources;
    final rows = CommanderSeatLayout.rowsFor(
      c.session.players,
      widget.quarterTurns,
    );
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_seatName · ${recipient.life} life',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_navigation.isNotEmpty)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: MergeSemantics(
                      child: Semantics(
                        label: 'Back',
                        child: IconButton(
                          onPressed: disabled ? null : _back,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: MergeSemantics(
                    child: Semantics(
                      label: 'Close workspace',
                      child: IconButton(
                        onPressed: disabled ? null : _requestClose,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _counterScroll,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final ownerWidth =
                      (bounds.maxWidth - (rows.first.length - 1) * 8) /
                      rows.first.length;
                  final stackPartners =
                      ownerWidth < _largestCommanderGroup() * 88;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        key: const ValueKey('focused-commander-grid'),
                        children: [
                          for (var r = 0; r < rows.length; r++) ...[
                            if (r > 0) const SizedBox(height: 6),
                            SizedBox(
                              height: _commanderRowHeight(ownerWidth),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var col = 0;
                                    col < rows[r].length;
                                    col++
                                  ) ...[
                                    if (col > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child: rows[r][col] == null
                                          ? const SizedBox.shrink()
                                          : _focusedCommanderOwner(
                                              recipient,
                                              rows[r][col]!,
                                              sources,
                                              disabled,
                                              stackPartners,
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._counterContent(recipient),
                      if (recipient.warnings.isNotEmpty)
                        Text(recipient.warnings.join(' · ')),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _focusedCommanderRole(CommanderSource source) {
    final siblings = c.session.commanderTrackingSources
        .where((item) => item.ownerPlayerId == source.ownerPlayerId)
        .toList();
    final index = siblings.indexWhere((item) => item.id == source.id);
    return index == 0
        ? 'Commander'
        : index == 1
        ? 'Partner'
        : 'Commander ${index + 1}';
  }

  Widget _focusedCommanderOwner(
    PlayerState recipient,
    PlayerState owner,
    List<CommanderSource> sources,
    bool disabled,
    bool stackPartners,
  ) {
    final identity = c.profile(owner.seatId);
    final owned = sources.where((s) => s.ownerPlayerId == owner.id).toList();
    final body = <Widget>[
      for (var index = 0; index < owned.length; index++) ...[
        if (index > 0)
          stackPartners
              ? const Divider(height: 1, thickness: 1, color: Colors.white24)
              : const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.white24,
                ),
        Expanded(
          child: _focusedCommanderTracker(
            recipient,
            owner,
            owned[index],
            disabled,
            partnerIndex: owned.length > 1 ? index : null,
          ),
        ),
      ],
    ];
    return DecoratedBox(
      key: ValueKey('commander-owner-${owner.id}'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(identity.color).withValues(alpha: .6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Color.alphaBlend(
                const Color(0x88000000),
                Color(identity.color),
              ),
            ),
            if (identity.artworkUrl != null) ...[
              TableArtwork(url: identity.artworkUrl, crop: true),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xAA000000),
                      Color(0x8A000000),
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
            ],
            stackPartners
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _focusedCommanderTracker(
    PlayerState recipient,
    PlayerState owner,
    CommanderSource source,
    bool disabled, {
    int? partnerIndex,
  }) {
    final identity = c.profile(owner.seatId);
    final label = _commanderSourceLabel(source);
    final damage = recipient.commanderDamage[source.id] ?? 0;
    return Semantics(
      key: ValueKey('commander-tracker-${source.id}'),
      identifier: 'commander-tracker-${source.id}',
      container: true,
      explicitChildNodes: true,
      child: LayoutBuilder(
        builder: (context, bounds) => HalfStepper(
          height: bounds.maxHeight,
          label: '$label commander damage from ${identity.name}',
          value: '$damage',
          displayOverlay: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
                child: Text(
                  '${identity.name}${owner.id == recipient.id ? ' · me' : ''}',
                  key: ValueKey('commander-source-owner-label-${source.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    color: Color(0xEEFFFFFF),
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                  ),
                ),
              ),
              if (partnerIndex != null)
                Text(
                  _focusedCommanderRole(source),
                  key: ValueKey('commander-source-role-${source.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$damage',
                      style: TextStyle(
                        fontSize: ((bounds.maxHeight - 24) * .65).clamp(
                          28,
                          100,
                        ),
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: damage >= 21
                            ? const Color(0xFFFFB485)
                            : Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          foregroundColor: Colors.white,
          iconSize: 19,
          iconPadding: 9,
          iconY: .2,
          displayPadding: 30,
          decreaseKey: ValueKey('commander-decrease-${source.id}'),
          increaseKey: ValueKey('commander-increase-${source.id}'),
          decreaseLabel:
              'Decrease $label damage from ${identity.name}; restore one life',
          increaseLabel:
              'Increase $label damage from ${identity.name}; lose one life',
          onDecrease: disabled
              ? null
              : () => _stepCommander(recipient, source, -1),
          onIncrease: disabled
              ? null
              : () => _stepCommander(recipient, source, 1),
          onDecreaseHoldStep: disabled
              ? null
              : (amount) => _stepCommander(recipient, source, -amount),
          onIncreaseHoldStep: disabled
              ? null
              : (amount) => _stepCommander(recipient, source, amount),
          interactionEpoch: Object.hash(
            _sessionId,
            _sessionGeneration,
            _closing,
            _navigating,
            _directFailureEpoch,
          ),
        ),
      ),
    );
  }
}

part of 'table_workspace.dart';

/// Direct commander tracking: bounded owner slots, never a scrolling ledger.
extension _FocusedCommanderPage on _TableWorkspaceState {
  Widget _focusedCommanderPage() {
    final recipient = p;
    if (recipient == null) return const Center(child: Text('Select a player.'));
    final editing = c.session.commanderTrackingSources
        .where((source) => source.id == _editingCommanderId)
        .firstOrNull;
    final disabled = _working || _closing || _navigating || !_validScope;
    Widget action(String label, IconData icon, VoidCallback? callback) =>
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: label,
            padding: EdgeInsets.zero,
            onPressed: callback,
            icon: Icon(icon, size: 21),
          ),
        );
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
                if (editing != null)
                  action('Back', Icons.arrow_back, disabled ? null : _back),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_seatName · ${recipient.life} life',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (editing != null)
                        const Text(
                          'Correct damage; life stays unchanged.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, height: 1.1),
                        ),
                    ],
                  ),
                ),
                if (editing == null) ...[
                  action(
                    'Undo latest action',
                    Icons.undo,
                    disabled || !c.canUndo ? null : () => _run(() => c.undo()),
                  ),
                  action(
                    'Correct life separately',
                    Icons.edit_note,
                    disabled ? null : () => _go(WorkspacePage.lifeCorrection),
                  ),
                ],
                action('Close workspace', Icons.close, _requestClose),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: editing != null
                ? _focusedCommanderEditor(recipient, editing)
                : LayoutBuilder(
                    builder: (context, bounds) {
                      final columns = rows.first.length;
                      final ownerWidth =
                          (bounds.maxWidth - (columns - 1) * 8) / columns;
                      final ownerHeight =
                          (bounds.maxHeight - (rows.length - 1) * 6) /
                          rows.length;
                      final largestGroup = c.session.players
                          .map(
                            (owner) => sources
                                .where((s) => s.ownerPlayerId == owner.id)
                                .length,
                          )
                          .fold<int>(1, max);
                      // Fill the available owner slots rather than parking
                      // small numeric controls above an empty modal. Partners
                      // share one artwork surface, splitting only its controls.
                      final stackPartners = ownerWidth < largestGroup * 88;
                      final sourceWidth = stackPartners
                          ? ownerWidth
                          : (ownerWidth - (largestGroup - 1)) / largestGroup;
                      final sourceHeight = stackPartners
                          ? (ownerHeight - 20 - (largestGroup - 1)) /
                                largestGroup
                          : ownerHeight - 20;
                      if (largestGroup > 2 ||
                          sourceWidth < 88 ||
                          sourceHeight < 88) {
                        return ListView(
                          key: const ValueKey('commander-density-fallback'),
                          children: [
                            const Text(
                              'More commander sources than this grid can fit. All sources remain available below.',
                            ),
                            for (final source in sources)
                              ListTile(
                                title: Text(
                                  '${_nameForPlayer(source.ownerPlayerId)} · ${_focusedCommanderRole(source)}',
                                ),
                                subtitle: Text(
                                  '${recipient.commanderDamage[source.id] ?? 0} damage',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: disabled
                                    ? null
                                    : () => _editCommander(recipient, source),
                              ),
                          ],
                        );
                      }
                      return Column(
                        key: const ValueKey('focused-commander-grid'),
                        children: [
                          for (var r = 0; r < rows.length; r++) ...[
                            if (r > 0) const SizedBox(height: 6),
                            SizedBox(
                              height: ownerHeight,
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
                      );
                    },
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

  Widget _focusedCommanderEditor(
    PlayerState recipient,
    CommanderSource source,
  ) => _list([
    _section(
      '${_nameForPlayer(source.ownerPlayerId)} · ${_focusedCommanderRole(source)}',
    ),
    _input(
      'damageCorrection.${source.id}',
      'Set damage total',
      initial: '${recipient.commanderDamage[source.id] ?? 0}',
      numeric: true,
    ),
    _button(
      'Correct ledger only',
      () => _run(
        () => c.setCommanderDamage(
          recipient.id,
          source.id,
          _integer('damageCorrection.${source.id}', min: 0),
        ),
      ),
      primary: true,
    ),
  ]);

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: Text(
                        '${identity.name}${owner.id == recipient.id ? ' · me' : ''}',
                        key: ValueKey('commander-owner-label-${owner.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          color: Color(0xDDFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: stackPartners
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: body,
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: body,
                        ),
                ),
              ],
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
    final ownerLabel =
        '${identity.name}${owner.id == recipient.id ? ' · self' : ''}';
    final damage = recipient.commanderDamage[source.id] ?? 0;
    return Column(
      key: ValueKey('commander-tracker-${source.id}'),
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label:
                      '$ownerLabel, $label${damage >= 21 ? ', 21 damage warning' : ''}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      partnerIndex == null
                          ? ''
                          : (partnerIndex == 0 ? 'A' : 'B'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: ValueKey('commander-edit-${source.id}'),
                  tooltip:
                      'Correct $label damage from ${identity.name}; life unchanged',
                  padding: EdgeInsets.zero,
                  onPressed: disabled
                      ? null
                      : () => _editCommander(recipient, source),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) => HalfStepper(
              height: bounds.maxHeight,
              label: '$label commander damage from ${identity.name}',
              value: '$damage',
              valueStyle: TextStyle(
                fontSize: (bounds.maxHeight * .65).clamp(28, 100),
                height: 1,
                fontWeight: FontWeight.w500,
                color: damage >= 21 ? const Color(0xFFFFB485) : Colors.white,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
              foregroundColor: Colors.white,
              iconSize: 19,
              iconPadding: 9,
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
                _editingCommanderId,
                _directFailureEpoch,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

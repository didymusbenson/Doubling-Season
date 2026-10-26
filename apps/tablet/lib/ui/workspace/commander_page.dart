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
                      Text(
                        editing == null
                            ? '±: life + damage · Edit: damage only'
                            : 'Correct damage; life stays unchanged.',
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
                      final stackPartners =
                          ownerWidth < 260 && ownerHeight >= 200;
                      final rowHeight = min(
                        ownerHeight,
                        stackPartners
                            ? largestGroup * 104.0 + (largestGroup - 1) * 4
                            : 110.0,
                      );
                      final sourceWidth = stackPartners
                          ? ownerWidth
                          : (ownerWidth - (largestGroup - 1) * 4) /
                                largestGroup;
                      if (largestGroup > 2 ||
                          sourceWidth < 88 ||
                          ownerHeight < 108) {
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
                              height: rowHeight,
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
                                              rowHeight,
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
    double rowHeight,
  ) {
    final owned = sources.where((s) => s.ownerPlayerId == owner.id).toList();
    final bodyHeight = rowHeight - 20;
    final body = stackPartners
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < owned.length; index++) ...[
                if (index > 0) const SizedBox(height: 4),
                SizedBox(
                  height: min(
                    104.0,
                    (bodyHeight - (owned.length - 1) * 4) / owned.length,
                  ),
                  child: _focusedCommanderTracker(
                    recipient,
                    owner,
                    owned[index],
                    disabled,
                  ),
                ),
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < owned.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: _focusedCommanderTracker(
                    recipient,
                    owner,
                    owned[index],
                    disabled,
                  ),
                ),
              ],
            ],
          );
    return Column(
      key: ValueKey('commander-owner-${owner.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 20,
          child: Text(
            '${_nameForPlayer(owner.id)}${owner.id == recipient.id ? ' · self' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.1),
          ),
        ),
        Expanded(
          child: owned.length == 1
              ? Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 220,
                    height: min(bodyHeight, 110.0),
                    child: body,
                  ),
                )
              : body,
        ),
      ],
    );
  }

  Widget _focusedCommanderTracker(
    PlayerState recipient,
    PlayerState owner,
    CommanderSource source,
    bool disabled,
  ) {
    final identity = c.profile(owner.seatId);
    final label = _commanderSourceLabel(source);
    final displayLabel = _focusedCommanderRole(source);
    final ownerLabel =
        '${identity.name}${owner.id == recipient.id ? ' · self' : ''}';
    final damage = recipient.commanderDamage[source.id] ?? 0;
    return Card(
      key: ValueKey('commander-tracker-${source.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(identity.color), width: 2),
      ),
      child: TableArtworkSurface(
        url: identity.artworkUrl,
        child: ColoredBox(
          color: Color(identity.color).withValues(alpha: .16),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Semantics(
                          label:
                              '$ownerLabel, $label${damage >= 21 ? ', 21 damage warning' : ''}',
                          excludeSemantics: true,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final text in [displayLabel])
                                Text(
                                  text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.1,
                                    color: identity.artworkUrl == null
                                        ? null
                                        : Colors.white,
                                  ),
                                ),
                            ],
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
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: identity.artworkUrl == null
                              ? null
                              : Colors.white,
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
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: damage >= 21 ? const Color(0xFFFFB485) : null,
                    ),
                    foregroundColor: identity.artworkUrl == null
                        ? null
                        : Colors.white,
                    iconSize: 16,
                    iconPadding: 4,
                    displayPadding: 20,
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
                        : (amount) =>
                              _stepCommander(recipient, source, -amount),
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
          ),
        ),
      ),
    );
  }
}

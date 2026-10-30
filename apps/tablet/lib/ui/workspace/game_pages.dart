part of 'table_workspace.dart';

extension _GamePages on _TableWorkspaceState {
  Widget _playerPage() {
    final player = p;
    if (player == null) return _list([const Text('Select a player first.')]);
    return _list([
      ..._playerCommanderContent(player),
      const SizedBox(height: 12),
      ..._playerAppearanceContent(player),
      const SizedBox(height: 16),
      _button(
        'Saved setups',
        () => _go(WorkspacePage.presets),
        icon: Icons.save_outlined,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Summoning sickness'),
        value: player.summoningSicknessEnabled,
        onChanged: _working
            ? null
            : (value) => _run(
                () => c.updateState(
                  'Summoning sickness setting',
                  (state) =>
                      state.session.player(player.id).summoningSicknessEnabled =
                          value,
                  recordHistory: true,
                ),
              ),
      ),
    ], controller: _playerScroll);
  }

  Widget _tableHubPage() => _list([
    LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 480
            ? 3
            : constraints.maxWidth >= 256
            ? 2
            : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          key: const ValueKey('drawer-menu-grid'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, page, icon) in [
              ('Dice', WorkspacePage.dice, Icons.casino_outlined),
              ('History', WorkspacePage.history, Icons.history),
              ('New game', WorkspacePage.reset, Icons.restart_alt),
              ('Archives', WorkspacePage.archives, Icons.archive_outlined),
              (
                'Board wipes',
                WorkspacePage.boardWipes,
                Icons.delete_sweep_outlined,
              ),
              ('Settings', WorkspacePage.settings, Icons.settings_outlined),
            ])
              SizedBox(
                width: width,
                child: OutlinedButton(
                  key: ValueKey('drawer-menu-${page.name}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(width, columns == 1 ? 56 : 92),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _go(page),
                  child: columns == 1
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 22),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(label, textAlign: TextAlign.center),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 26),
                            const SizedBox(height: 8),
                            Text(label, textAlign: TextAlign.center),
                          ],
                        ),
                ),
              ),
          ],
        );
      },
    ),
  ], centered: true);

  double get _playerStatusHeight =>
      max(72.0, MediaQuery.textScalerOf(context).scale(72));

  Widget _playerStatusBadges(PlayerState player) {
    final monarch = c.session.monarchPlayerId == player.id;
    final initiative = _board.hasInitiative(player.id);
    Widget status(
      String label,
      Widget icon,
      bool active,
      Future<dynamic> Function() action, {
      Future<dynamic> Function()? clear,
    }) {
      final color = active
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest;
      return Expanded(
        child: Semantics(
          label: '$label, ${active ? 'On' : 'Off'}',
          button: true,
          enabled: true,
          toggled: active,
          excludeSemantics: true,
          onTap: () => _runDirect(action),
          onLongPress: clear == null ? null : () => _runDirect(clear),
          hint: clear == null ? null : 'Hold to clear $label',
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _runDirect(action),
              onLongPress: clear == null ? null : () => _runDirect(clear),
              child: SizedBox(
                height: _playerStatusHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        color: active
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 26,
                      ),
                      child: icon,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        status(
          'Monarch',
          const MonarchCrown(),
          monarch,
          () => c.setMonarch(
            c.session.monarchPlayerId == player.id ? null : player.id,
          ),
          clear: monarch ? () => c.setMonarch(null) : null,
        ),
        const SizedBox(width: 8),
        status(
          'City’s blessing',
          const Icon(TableManaIcons.ascend),
          player.citysBlessing,
          () =>
              c.setCitysBlessing(player.id, !c.player(player.id).citysBlessing),
        ),
        const SizedBox(width: 8),
        status(
          'Initiative',
          const Icon(Icons.explore_outlined),
          initiative,
          () => _board.setInitiative(
            _board.hasInitiative(player.id) ? null : player.id,
          ),
          clear: initiative ? () => _board.setInitiative(null) : null,
        ),
      ],
    );
  }

  Widget _gamePanel(String title, List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _gameGrid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 590 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );

  Widget _gameFieldAction(Widget field, Widget action) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: field),
      const SizedBox(width: 8),
      action,
    ],
  );

  List<Widget> _playerAppearanceContent(PlayerState player) {
    final profile = c.profile(player.seatId);
    return [
      _gameGrid([
        _gamePanel('Name & color', [
          _input(
            'profile.name',
            'Player name',
            initial: profile.name,
            live: true,
            onCommitWithOriginal: (value, original) async {
              final name = value.trim();
              if (name.isEmpty) {
                throw const FormatException('Enter a player name.');
              }
              return c.updateState('Rename seat', (state) {
                final target = state.profiles.firstWhere(
                  (s) => s.id == player.seatId,
                );
                if (target.name != original.trim() && target.name != name) {
                  throw StateError(
                    'This name changed in another view. Edit your retained draft to confirm it before saving.',
                  );
                }
                target.name = name;
              });
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in [
                0xffd7bd78,
                0xff83b7ce,
                0xffb498ca,
                0xff92bc91,
                0xffd28f80,
                0xffb2b5c1,
                0xffe6ba89,
                0xff8bc8bf,
              ])
                Semantics(
                  label: 'Seat color ${color.toRadixString(16)}',
                  button: true,
                  selected: profile.color == color,
                  child: InkWell(
                    onTap: () => _run(
                      () => c.updateState(
                        'Change seat color',
                        (state) =>
                            state.profiles
                                    .firstWhere((s) => s.id == player.seatId)
                                    .color =
                                color,
                      ),
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: profile.color == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]),
        _gamePanel('Life artwork', [
          const SizedBox(height: 12),
          if (profile.artworkUrl != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _art(profile.artworkUrl, width: 180, height: 110),
            ),
          Wrap(
            spacing: 8,
            children: [
              _button(
                'Search token art',
                () => _run(() async {
                  final art = await showLifeArtworkPicker(
                    context,
                    catalog: catalog,
                    seatName: profile.name,
                    quarterTurns: widget.quarterTurns,
                    current: profile.artworkUrl,
                    queryController: _field('life-art.query'),
                    initialCandidate: _field('life-art.candidate').text.isEmpty
                        ? null
                        : _field('life-art.candidate').text,
                    onCandidateChanged: (value) =>
                        _field('life-art.candidate').text = value ?? '',
                  );
                  if (!mounted || !_validScope) return null;
                  if (art != null) {
                    return c.updateState(
                      'Change seat artwork',
                      (state) =>
                          state.profiles
                                  .firstWhere((s) => s.id == player.seatId)
                                  .artworkUrl =
                              art,
                    );
                  }
                }),
                icon: Icons.image_outlined,
              ),
              if (profile.artworkUrl != null)
                _button(
                  'Remove life artwork',
                  () => _run(
                    () => c.updateState(
                      'Remove seat artwork',
                      (state) =>
                          state.profiles
                                  .firstWhere((s) => s.id == player.seatId)
                                  .artworkUrl =
                              null,
                    ),
                  ),
                  icon: Icons.hide_image_outlined,
                ),
            ],
          ),
        ]),
      ]),
    ];
  }

  List<Widget> _playerCommanderContent(PlayerState player) => [
    _PartnerToggle(
      enabled: c.session.hasPartner(player.id),
      busy: _working || _closing || _navigating,
      blockReason: () => c.partnerToggleBlockReason(player.id),
      onChange: (value, showGuidance) => _run(() async {
        String? blocked;
        final saved = await c.setHasPartner(
          player.id,
          value,
          onBlocked: (reason) {
            blocked = reason;
            showGuidance(reason);
          },
        );
        // Only the typed, expected guard is local. Storage/scope failures still
        // return false to the existing workspace/global error handling.
        return blocked == null ? saved : null;
      }),
    ),
  ];

  String _nameForPlayer(String id) {
    for (final player in c.session.players) {
      if (player.id == id) return c.profile(player.seatId).name;
    }
    return 'Previous player';
  }

  // Project supported zero counters into the editor without changing persisted
  // maps on open. Retain every legacy/custom key, including saved zero values.
  Map<String, int> _editablePlayerCounters(PlayerState player) => {
    'energy': 0,
    'poison': 0,
    'experience': 0,
    'radiation': 0,
    ...player.counters,
  };

  int _counterColumns(double width) {
    final wideValues =
        p != null &&
        _editablePlayerCounters(p!).values.any((value) => '$value'.length > 6);
    if (wideValues) return width >= 488 ? 2 : 1;
    return width >= 584 ? 4 : (width >= 288 ? 2 : 1);
  }

  double get _playerCounterHeight =>
      max(64.0, MediaQuery.textScalerOf(context).scale(58));

  String _counterLabel(String key) =>
      key.isEmpty ? 'Counter' : '${key[0].toUpperCase()}${key.substring(1)}';

  String _counterActionLabel(String key) =>
      key.isEmpty ? 'unnamed counter' : key;

  List<Widget> _counterContent(PlayerState player) {
    final counters = _editablePlayerCounters(player);
    final editing = _editingPlayerCounter;
    final disabled = _working || _closing || _navigating || !_validScope;
    return [
      Semantics(
        identifier: 'player-status-chips',
        container: true,
        explicitChildNodes: true,
        child: _playerStatusBadges(player),
      ),
      const SizedBox(height: 8),
      Semantics(
        identifier: 'player-counter-chips',
        label: 'Player counters',
        container: true,
        explicitChildNodes: true,
        child: _counterGrid(
          [
            for (final counter in counters.entries)
              Semantics(
                key: ValueKey('player-counter-${counter.key}'),
                identifier: 'player-counter-${counter.key}',
                container: true,
                explicitChildNodes: true,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Expanded(
                        child: HalfStepper(
                          height: _playerCounterHeight,
                          label: _counterActionLabel(counter.key),
                          value: '${counter.value}',
                          displayPadding: 22,
                          iconPadding: 5,
                          iconSize: 17,
                          displayOverlay: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(switch (counter.key) {
                                        'energy' => Icons.bolt,
                                        'poison' => Icons.science_outlined,
                                        'experience' => Icons.auto_awesome,
                                        'radiation' => Icons.blur_circular,
                                        _ => Icons.hexagon_outlined,
                                      }, size: 18),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${counter.value}',
                                        key: ValueKey(
                                          'player-counter-value-${counter.key}',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Text(
                                  _counterLabel(counter.key),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                          decreaseLabel:
                              'Decrease ${_counterActionLabel(counter.key)}',
                          increaseLabel:
                              'Increase ${_counterActionLabel(counter.key)}',
                          onDecrease:
                              disabled ||
                                  (_directPending == 0 && counter.value == 0)
                              ? null
                              : () => _runDirect(
                                  () => c.adjustPlayerCounter(
                                    player.id,
                                    counter.key,
                                    -1,
                                  ),
                                ),
                          onIncrease: disabled
                              ? null
                              : () => _runDirect(
                                  () => c.adjustPlayerCounter(
                                    player.id,
                                    counter.key,
                                    1,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: _playerCounterHeight,
                        child: MergeSemantics(
                          child: Semantics(
                            label:
                                'Set ${_counterActionLabel(counter.key)} total',
                            child: IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              onPressed: disabled
                                  ? null
                                  : () => _editPlayerCounter(
                                      player.id,
                                      counter.key,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          correctionIndex: editing == null
              ? null
              : counters.keys.toList().indexOf(editing),
          correction: editing == null
              ? null
              : Row(
                  key: _counterCorrectionKey,
                  children: [
                    Expanded(
                      child: _input(
                        'counter.$editing',
                        'Set total',
                        initial: '${counters[editing]}',
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _button(
                      'Set',
                      () => _run(
                        () => c.setPlayerCounter(
                          player.id,
                          editing,
                          _integer('counter.$editing', min: 0),
                        ),
                        after: () => _editingPlayerCounter = null,
                      ),
                    ),
                    MergeSemantics(
                      child: Semantics(
                        label: 'Cancel counter correction',
                        child: IconButton(
                          onPressed: () =>
                              _update(() => _editingPlayerCounter = null),
                          icon: const Icon(Icons.close, size: 19),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ];
  }

  Widget _counterGrid(
    List<Widget> children, {
    int? correctionIndex,
    Widget? correction,
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = _counterColumns(bounds.maxWidth);
      final width = (bounds.maxWidth - (columns - 1) * 8) / columns;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (
                  var index = start;
                  index < min(start + columns, children.length);
                  index++
                ) ...[
                  if (index > start) const SizedBox(width: 8),
                  SizedBox(width: width, child: children[index]),
                ],
              ],
            ),
            if (correction != null &&
                correctionIndex != null &&
                correctionIndex >= start &&
                correctionIndex < start + columns) ...[
              const SizedBox(height: 8),
              correction,
            ],
          ],
        ],
      );
    },
  );

  String _commanderSourceLabel(CommanderSource source) {
    final siblings = c.session.commanderTrackingSources
        .where((s) => s.ownerPlayerId == source.ownerPlayerId)
        .toList();
    return '${source.name}${siblings.length > 1 ? ' #${siblings.indexWhere((s) => s.id == source.id) + 1}' : ''}';
  }

  Widget _historyPage() {
    final entries = c.session.history.reversed.toList();
    if (entries.isEmpty) {
      return _list([
        const Icon(Icons.history, size: 40),
        const SizedBox(height: 12),
        const Text(
          'This game has no actions yet.',
          textAlign: TextAlign.center,
        ),
      ], centered: true);
    }
    final canUndo = c.canUndo;
    final undoLabel = canUndo
        ? 'Undo latest: ${c.session.history.lastWhere((entry) => !entry.undone).summary}'
        : '';
    Widget row(BuildContext context, int index) {
      if (canUndo && index == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _button(
            undoLabel,
            () => _run(() => c.undo()),
            icon: Icons.undo,
            primary: true,
            compactLabel: 'Undo latest',
          ),
        );
      }
      final entry = entries[index - (canUndo ? 1 : 0)];
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: .6),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.undone ? 'Undone · ' : ''}${entry.summary}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: entry.undone ? scheme.outline : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.playerLabel ?? 'Table'} · ${_date(entry.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (entry.affectedPlayerIds.isNotEmpty)
                  Text(
                    'Affected: ${entry.affectedPlayerIds.map(_nameForPlayer).join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (entry.tokenSummary.isNotEmpty &&
                    entry.tokenSummary != entry.summary)
                  Text(
                    entry.tokenSummary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (entry.undoNote != null)
                  Text(
                    entry.undoNote!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final count = entries.length + (canUndo ? 1 : 0);
    return _embedded
        ? _drawerList(itemCount: count, itemBuilder: row)
        : _list([
            for (var index = 0; index < count; index++) row(context, index),
          ]);
  }

  String _date(DateTime date) {
    final d = date.toLocal();
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _archivesPage() {
    final archives = c.state.archives.reversed.toList();
    if (archives.isEmpty) {
      return _list([
        const Icon(Icons.archive_outlined, size: 40),
        const SizedBox(height: 12),
        const Text('No archived games yet.', textAlign: TextAlign.center),
      ], centered: true);
    }
    Widget row(BuildContext context, int index) {
      final archive = archives[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _confirm(
              'Restore ${archive.label}?',
              'Archive the current game, then restore this saved board, life, damage, rules and timeline. Saved setups and player appearances stay unchanged.',
              () => c.restoreArchive(archive.id),
              button: 'Save current & restore',
              compactButton: 'Restore',
              closeOnSuccess: true,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          archive.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.restore, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _date(archive.savedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${archive.session.players.length} players · ${archive.session.history.length} history entries',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _embedded
        ? _drawerList(itemCount: archives.length, itemBuilder: row)
        : _list([for (var i = 0; i < archives.length; i++) row(context, i)]);
  }

  Widget _boardWipesPage() => _list([
    _wipeScope(),
    for (final player in c.session.players) ...[
      const SizedBox(height: 12),
      _wipeScope(player: player),
    ],
  ], centered: true);

  Widget _wipeScope({PlayerState? player}) {
    final profile = player == null ? null : c.profile(player.seatId);
    final name = player == null ? 'Everyone' : _nameForPlayer(player.id);
    final scheme = Theme.of(context).colorScheme;
    final color = profile == null ? scheme.primary : Color(profile.color);
    Widget action(String action, String visible, String full) {
      void press() => _confirm(
        player == null
            ? '$full for everyone?'
            : 'Wipe $name’s ${action == 'wipe_all' ? 'tokens' : 'creatures'}?',
        player == null
            ? 'Remove ${action == 'wipe_all' ? 'all tokens, including emblems' : 'creature tokens'} from everyone. Utilities and other state remain. Restore the whole wipe from History.'
            : 'Remove ${action == 'wipe_all' ? 'all tokens' : 'creature tokens'} from $name only. Utilities and other state remain. Restore from History.',
        () => player == null
            ? _board.wipeEveryone(action)
            : _board.bulk(player.id, action, gameOrigin: true),
        button: full,
        compactButton: 'Wipe',
      );
      return Expanded(
        child: Semantics(
          label:
              '$name, ${action == 'wipe_creatures' ? 'Wipe creatures' : 'Wipe all tokens'}',
          button: true,
          enabled: !_working,
          onTap: _working ? null : press,
          excludeSemantics: true,
          child: OutlinedButton(
            onPressed: _working ? null : press,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            ),
            child: Text(visible, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Column(
      key: ValueKey('wipe-scope-${player?.id ?? 'everyone'}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: player == null ? .18 : .08),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                if (profile?.artworkUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: _art(profile!.artworkUrl, width: 28, height: 28),
                  )
                else
                  Icon(
                    player == null
                        ? Icons.groups_outlined
                        : Icons.person_outline,
                    color: color,
                    size: 24,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            action(
              'wipe_creatures',
              'Creatures',
              player == null ? 'Wipe all creatures' : 'Wipe creatures',
            ),
            const SizedBox(width: 8),
            action('wipe_all', 'All tokens', 'Wipe all tokens'),
          ],
        ),
      ],
    );
  }

  Widget _setupChoice(
    String label,
    String visible,
    bool selected,
    VoidCallback action,
  ) => Semantics(
    label: label,
    button: true,
    selected: selected,
    enabled: !_working,
    onTap: _working ? null : action,
    excludeSemantics: true,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : null,
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _working ? null : action,
      child: Text(visible, textAlign: TextAlign.center),
    ),
  );

  Widget _emptySeatChoices() {
    const names = ['Bottom left', 'Top left', 'Top right', 'Bottom right'];
    return Column(
      key: const ValueKey('reset-empty-seat'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final slots in [
          [1, 2],
          [0, 3],
        ]) ...[
          if (slots.first == 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final slot in slots) ...[
                if (slot == slots.last) const SizedBox(width: 8),
                Expanded(
                  child: _setupChoice(
                    names[slot],
                    names[slot],
                    _emptySlot == slot,
                    () => _update(() => _emptySlot = slot),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _resetPage() => _list([
    Text('Players', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    Row(
      key: const ValueKey('reset-configuration'),
      children: [
        for (final count in [2, 3, 4]) ...[
          if (count != 2) const SizedBox(width: 8),
          Expanded(
            child: _setupChoice(
              '$count players',
              '$count',
              _resetCount == count,
              () => _update(() => _resetCount = count),
            ),
          ),
        ],
      ],
    ),
    const SizedBox(height: 20),
    _input(
      'reset.life',
      'Starting life',
      initial: '${c.session.startingLife}',
      numeric: true,
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        for (final life in [20, 40]) ...[
          if (life == 40) const SizedBox(width: 8),
          Expanded(
            child: _button(
              '$life life',
              () => _field('reset.life').text = '$life',
              compactLabel: '$life',
              icon: Icons.favorite_outline,
            ),
          ),
        ],
      ],
    ),
    if (_resetCount == 3) ...[
      const SizedBox(height: 20),
      Text('Empty seat', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      _emptySeatChoices(),
    ],
    const SizedBox(height: 20),
    const Text(
      'The current game is archived first. Player appearances and saved setups are preserved.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 16),
    _balancedActions([
      _button(
        'Reset with current configuration',
        () => _confirm(
          'Reset with board?',
          'Archive the current game, then start with $_resetCount players. Keep remaining players’ token entries at zero and utility selections. Clear counters, damage and utility values; restore starting life and disable modifiers and custom rules. Removed seats lose their live boards. Appearances and saved setups remain.',
          () => c.resetGame(
            keepBoard: true,
            playerCount: _resetCount,
            startingLife: _integer('reset.life', min: 1, max: 1000000),
            emptySlot: _emptySlot,
          ),
          button: 'Archive & reset with board',
          compactButton: 'Start game',
          closeOnSuccess: true,
        ),
        icon: Icons.restart_alt,
        compactLabel: 'Keep board',
      ),
      _button(
        'Complete reset',
        () => _confirm(
          'Clear boards & restart?',
          'Archive the current game, then start with $_resetCount players. Clear token lanes, damage, counters and statuses; restore starting life and default Storm and Mana utilities. Disable modifiers and custom rules. Player appearances and saved setups remain.',
          () => c.resetGame(
            keepBoard: false,
            playerCount: _resetCount,
            startingLife: _integer('reset.life', min: 1, max: 1000000),
            emptySlot: _emptySlot,
          ),
          button: 'Archive & complete reset',
          compactButton: 'Start game',
          closeOnSuccess: true,
        ),
        icon: Icons.delete_sweep_outlined,
        compactLabel: 'Clear board',
      ),
    ]),
  ], centered: true);

  Widget _settingsPage() => _list([
    Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    Semantics(
      label: 'Appearance theme',
      child: Wrap(
        spacing: 8,
        children: [
          for (final theme in ['system', 'light', 'dark'])
            ChoiceChip(
              label: Text(theme[0].toUpperCase() + theme.substring(1)),
              selected: (c.state.settings['theme'] ?? 'dark') == theme,
              onSelected: (_) => _run(
                () => c.updateState(
                  'Change theme',
                  (state) => state.settings['theme'] = theme,
                ),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    _gameGrid([
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Day / Night'),
              Wrap(
                spacing: 8,
                children: [
                  for (final state in ['neither', 'day', 'night'])
                    ChoiceChip(
                      label: Text(
                        state == 'neither'
                            ? 'Neither'
                            : state[0].toUpperCase() + state.substring(1),
                      ),
                      selected: c.session.dayNight == state,
                      onSelected: (_) => _run(() => c.setDayNight(state)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                'Token catalog',
                detail:
                    '${catalog.tokens.length} definitions · database version ${catalog.version}. Catalog updates preserve current artwork and custom token selections.',
              ),
              _button(
                'Check for catalog updates',
                () => _run(() async {
                  final update = await catalog.checkForUpdate();
                  if (!mounted || !_validScope) return;
                  if (update.error != null) throw StateError(update.error!);
                  if (update.version <= catalog.version) {
                    return;
                  }
                  _confirm(
                    'Update token catalog?',
                    'Download database version ${update.version}. The download will be checked before it replaces the current catalog.',
                    () => catalog.applyUpdate(update),
                    button: 'Download & verify',
                  );
                }),
                icon: Icons.download,
                compactLabel: 'Check updates',
              ),
              _button(
                'Use bundled catalog',
                () => _confirm(
                  'Restore the bundled catalog?',
                  'Remove the downloaded catalog update. Custom definitions and artwork choices remain.',
                  () => catalog.revertToBundled(),
                ),
                compactLabel: 'Use bundled',
              ),
            ],
          ),
        ),
      ),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                'Player appearance reset',
                detail:
                    'This separate reset clears saved player names, colors and life artwork only. It does not delete the current game or setups.',
              ),
              _button(
                'Reset saved seat appearance',
                () => _confirm(
                  'Reset all saved player appearances?',
                  'Replace all saved names and colors with defaults and remove life artwork, including hidden seats. This cannot be undone through game history.',
                  () => c.updateState('Reset seat appearances', (state) {
                    const colors = [
                      0xffd7bd78,
                      0xff83b7ce,
                      0xffb498ca,
                      0xff92bc91,
                    ];
                    for (
                      var index = 0;
                      index < state.profiles.length;
                      index++
                    ) {
                      state.profiles[index].name = 'Player ${index + 1}';
                      state.profiles[index].color =
                          colors[index % colors.length];
                      state.profiles[index].artworkUrl = null;
                    }
                  }),
                  button: 'Reset appearances',
                ),
                icon: Icons.person_off_outlined,
                compactLabel: 'Reset appearance',
              ),
            ],
          ),
        ),
      ),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                'Tripling Season · Tablet edition',
                detail:
                    'Free to play, with no ads. Optional supporter cosmetics never gate game features.',
              ),
              _button(
                'Support this app',
                () => _go(WorkspacePage.support),
                icon: Icons.favorite_outline,
                compactLabel: 'Support',
              ),
            ],
          ),
        ),
      ),
    ]),
  ]);
}

/// Expected partner constraints belong beside their toggle, not in global errors.
class _PartnerToggle extends StatefulWidget {
  const _PartnerToggle({
    required this.enabled,
    required this.busy,
    required this.blockReason,
    required this.onChange,
  });
  final bool enabled, busy;
  final String? Function() blockReason;
  final Future<void> Function(bool, ValueChanged<String>) onChange;
  @override
  State<_PartnerToggle> createState() => _PartnerToggleState();
}

class _PartnerToggleState extends State<_PartnerToggle> {
  String? _guidance;
  @override
  void didUpdateWidget(covariant _PartnerToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blockReason() == null) _guidance = null;
  }

  void _showGuidance(String reason) {
    if (mounted) setState(() => _guidance = reason);
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Has partner'),
    subtitle: _guidance == null
        ? null
        : Text(_guidance!, key: const ValueKey('partner-toggle-guidance')),
    value: widget.enabled,
    onChanged: widget.busy
        ? null
        : (value) async {
            final reason = value ? null : widget.blockReason();
            if (reason != null) {
              _showGuidance(reason);
              return;
            }
            setState(() => _guidance = null);
            await widget.onChange(value, _showGuidance);
          },
  );
}

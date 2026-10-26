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

  Widget _countersPage() {
    final player = p;
    if (player == null) return _list([const Text('Select a player first.')]);
    return _list([
      ..._counterContent(player),
      if (player.warnings.isNotEmpty) Text(player.warnings.join(' · ')),
      const SizedBox(height: 12),
      _button(
        'Correct life',
        () => _go(WorkspacePage.lifeCorrection),
        icon: Icons.edit_outlined,
      ),
    ], controller: _counterScroll);
  }

  Widget _tableHubPage() => _list([
    for (final (label, page, icon) in [
      ('Dice', WorkspacePage.dice, Icons.casino_outlined),
      ('History', WorkspacePage.history, Icons.history),
      ('New game', WorkspacePage.reset, Icons.restart_alt),
      ('Archives', WorkspacePage.archives, Icons.archive_outlined),
      ('Board wipes', WorkspacePage.boardWipes, Icons.delete_sweep_outlined),
      ('Settings', WorkspacePage.settings, Icons.settings_outlined),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 280,
            height: 48,
            child: _button(label, () => _go(page), icon: icon),
          ),
        ),
      ),
  ]);

  Widget _lifeCorrectionPage() {
    final player = p;
    if (player == null) return _list([const Text('Select a player first.')]);
    return _list([
      _gameFieldAction(
        _input('life.delta', 'Change life by', initial: '-1', numeric: true),
        _button(
          'Apply',
          () => _run(() => c.adjustLife(player.id, _integer('life.delta'))),
          primary: true,
        ),
      ),
      _gameFieldAction(
        _input(
          'life.set',
          'Set life total to',
          initial: '${player.life}',
          numeric: true,
        ),
        _button(
          'Set',
          () => _run(() => c.setLife(player.id, _integer('life.set'))),
        ),
      ),
      _button(
        'Reset life to ${c.session.startingLife}',
        () => _confirm(
          'Reset $_seatName’s life?',
          'Only life changes. Commander damage, counters, tokens and other players remain.',
          () => c.setLife(player.id, c.session.startingLife),
        ),
        icon: Icons.restart_alt,
      ),
    ]);
  }

  Widget _playerStatusBadges(PlayerState player) {
    final monarch = c.session.monarchPlayerId == player.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(TableManaIcons.ascend, size: 18),
              label: Text(
                'City’s blessing · ${player.citysBlessing ? 'On' : 'Off'}',
              ),
              selected: player.citysBlessing,
              onSelected: _working
                  ? null
                  : (value) => _run(() => c.setCitysBlessing(player.id, value)),
            ),
            FilterChip(
              avatar: const MonarchCrown(),
              label: Text('Monarch · ${monarch ? 'On' : 'Off'}'),
              selected: monarch,
              onSelected: _working
                  ? null
                  : (_) => _run(() => c.setMonarch(monarch ? null : player.id)),
            ),
          ],
        ),
        if (c.session.monarchPlayerId != null) ...[
          const SizedBox(height: 6),
          Text(
            'Monarch: ${_nameForPlayer(c.session.monarchPlayerId!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
            onCommit: (value) async {
              final name = value.trim();
              if (name.isEmpty) {
                throw const FormatException('Enter a player name.');
              }
              return c.updateState(
                'Rename seat',
                (state) =>
                    state.profiles
                            .firstWhere((s) => s.id == player.seatId)
                            .name =
                        name,
              );
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
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Has partner'),
      value: c.session.hasPartner(player.id),
      onChanged: _working
          ? null
          : (value) => _run(() => c.setHasPartner(player.id, value)),
    ),
  ];

  String _nameForPlayer(String id) {
    for (final player in c.session.players) {
      if (player.id == id) return c.profile(player.seatId).name;
    }
    return 'Previous player';
  }

  List<Widget> _counterContent(PlayerState player) {
    final counters = {
      'energy': 0,
      'poison': 0,
      'experience': 0,
      'radiation': 0,
      ...player.counters,
    };
    return [
      _playerStatusBadges(player),
      const SizedBox(height: 12),
      _section('Player counters'),
      _gameGrid([
        for (final counter in counters.entries)
          Card(
            key: ValueKey('player-counter-${counter.key}'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: HalfStepper(
                          height: 48,
                          label: counter.key,
                          value: '${counter.value}',
                          valueWidget: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${counter.key[0].toUpperCase()}${counter.key.substring(1)}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              Text(
                                '${counter.value}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                          decreaseLabel: 'Decrease ${counter.key}',
                          increaseLabel: 'Increase ${counter.key}',
                          onDecrease: _working || counter.value == 0
                              ? null
                              : () => _run(
                                  () => c.adjustPlayerCounter(
                                    player.id,
                                    counter.key,
                                    -1,
                                  ),
                                ),
                          onIncrease: _working
                              ? null
                              : () => _run(
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
                        height: 48,
                        child: IconButton(
                          tooltip: 'Set ${counter.key} total',
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: _working
                              ? null
                              : () => _update(() {
                                  _editingPlayerCounter = counter.key;
                                  _field('counter.${counter.key}').text =
                                      '${counter.value}';
                                }),
                        ),
                      ),
                    ],
                  ),
                  if (counter.key == 'poison' && counter.value >= 10)
                    const Text('Poison threshold reached.'),
                  if (_editingPlayerCounter == counter.key)
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            'counter.${counter.key}',
                            'Set total',
                            initial: '${counter.value}',
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _button(
                          'Set',
                          () => _run(
                            () => c.setPlayerCounter(
                              player.id,
                              counter.key,
                              _integer('counter.${counter.key}', min: 0),
                            ),
                            after: () => _editingPlayerCounter = null,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel counter correction',
                          onPressed: () =>
                              _update(() => _editingPlayerCounter = null),
                          icon: const Icon(Icons.close, size: 19),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ]),
    ];
  }

  String _commanderSourceLabel(CommanderSource source) {
    final siblings = c.session.commanderTrackingSources
        .where((s) => s.ownerPlayerId == source.ownerPlayerId)
        .toList();
    return '${source.name}${siblings.length > 1 ? ' #${siblings.indexWhere((s) => s.id == source.id) + 1}' : ''}';
  }

  Widget _historyPage() => _list([
    if (c.canUndo)
      _button(
        'Undo latest: ${c.session.history.lastWhere((entry) => !entry.undone).summary}',
        () => _run(() => c.undo(), success: 'Latest action undone.'),
        icon: Icons.undo,
        primary: true,
      ),
    if (c.session.history.isEmpty)
      const Padding(
        padding: EdgeInsets.all(20),
        child: Text('This game has no actions yet.'),
      ),
    for (final entry in c.session.history.reversed)
      Card(
        child: ListTile(
          leading: Icon(
            entry.playerId == null
                ? Icons.table_restaurant
                : Icons.person_outline,
          ),
          title: Text(
            '${entry.undone ? 'Undone · ' : ''}${entry.summary}',
            style: entry.undone
                ? TextStyle(color: Theme.of(context).colorScheme.outline)
                : null,
          ),
          subtitle: Text(
            [
              '${entry.playerLabel ?? 'Table'} · ${_date(entry.updatedAt)}',
              if (entry.affectedPlayerIds.isNotEmpty)
                'Affected: ${entry.affectedPlayerIds.map(_nameForPlayer).join(', ')}',
              if (entry.tokenSummary.isNotEmpty &&
                  entry.tokenSummary != entry.summary)
                entry.tokenSummary,
              if (entry.undoNote != null) entry.undoNote!,
            ].join('\n'),
          ),
        ),
      ),
  ]);

  String _date(DateTime date) {
    final d = date.toLocal();
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _archivesPage() => _list([
    if (c.state.archives.isEmpty) const Text('No archived games yet.'),
    for (final archive in c.state.archives.reversed)
      Card(
        child: ListTile(
          title: Text(archive.label),
          subtitle: Text(
            '${_date(archive.savedAt)} · ${archive.session.players.length} players · ${archive.session.history.length} history entries',
          ),
          trailing: const Icon(Icons.restore),
          onTap: () => _confirm(
            'Restore ${archive.label}?',
            'Save the current game first, then restore this archive’s board, life, damage, rules and full timeline. Saved setups and permanent player customization will not be overwritten.',
            () => c.restoreArchive(archive.id),
            button: 'Save current & restore',
            closeOnSuccess: true,
          ),
        ),
      ),
  ]);

  Widget _boardWipesPage() => _list([
    _gamePanel('Everyone', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (action, label) in [
            ('wipe_creatures', 'Wipe all creatures'),
            ('wipe_all', 'Wipe all tokens'),
          ])
            _button(
              label,
              () => _confirm(
                '$label for everyone?',
                'Remove ${action == 'wipe_all' ? 'every token, including emblems' : 'creature tokens'} from all active players. Utilities and non-token state remain. One Undo restores the whole wipe.',
                () => _board.wipeEveryone(action),
                button: label,
              ),
              icon: Icons.delete_outline,
            ),
        ],
      ),
    ]),
    for (final player in c.session.players)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_nameForPlayer(player.id)),
            _button(
              'Wipe creatures',
              () => _confirm(
                'Wipe ${_nameForPlayer(player.id)}’s creatures?',
                'Remove creature tokens from this player only. Undo is available in game history.',
                () =>
                    _board.bulk(player.id, 'wipe_creatures', gameOrigin: true),
                button: 'Wipe creatures',
              ),
              icon: Icons.delete_outline,
            ),
            _button(
              'Wipe all tokens',
              () => _confirm(
                'Wipe ${_nameForPlayer(player.id)}’s tokens?',
                'Remove every token from this player only. Utilities and all non-token state remain. Undo is available in game history.',
                () => _board.bulk(player.id, 'wipe_all', gameOrigin: true),
                button: 'Wipe all tokens',
              ),
              icon: Icons.delete_outline,
            ),
          ],
        ),
      ),
  ]);

  Widget _resetPage() => _list([
    Wrap(
      key: const ValueKey('reset-configuration'),
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final count in [2, 3, 4])
          ChoiceChip(
            label: Text('$count players'),
            selected: _resetCount == count,
            onSelected: (_) => _update(() => _resetCount = count),
          ),
      ],
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _input(
          'reset.life',
          'Starting life',
          initial: '${c.session.startingLife}',
          numeric: true,
        ),
      ),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final life in [20, 40])
          _button('$life life', () => _field('reset.life').text = '$life'),
      ],
    ),
    const SizedBox(height: 12),
    const Text(
      'The current game is archived first. Player appearances and saved setups are preserved.',
    ),
    if (_resetCount == 3) ...[
      _section('Empty control slot'),
      Wrap(
        spacing: 8,
        children: [
          for (var slot = 0; slot < 4; slot++)
            ChoiceChip(
              label: Text(
                ['Bottom left', 'Top left', 'Top right', 'Bottom right'][slot],
              ),
              selected: _emptySlot == slot,
              onSelected: (_) => _update(() => _emptySlot = slot),
            ),
        ],
      ),
    ],
    const SizedBox(height: 18),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _button(
          'Reset with current configuration',
          () => _confirm(
            'Reset with board?',
            'Start a $_resetCount-player game. Keep remaining players’ token entries at zero and enabled utility selections; clear token counters, utility runtime values, damage and player counters. Restore starting life. Disable all modifier sources/custom rules. Removed seats lose their live boards. Save the current game to archives first.',
            () => c.resetGame(
              keepBoard: true,
              playerCount: _resetCount,
              startingLife: _integer('reset.life', min: 1, max: 1000000),
              emptySlot: _emptySlot,
            ),
            button: 'Archive & reset with board',
            closeOnSuccess: true,
          ),
          icon: Icons.restart_alt,
        ),
        _button(
          'Complete reset',
          () => _confirm(
            'Clear boards & restart?',
            'Start a $_resetCount-player game with empty token lanes, fresh default Storm and Mana utilities, starting life, cleared damage/counters/statuses, and disabled modifier sources/custom rules. Permanent seat appearances and saved setups remain. Archive the current game first.',
            () => c.resetGame(
              keepBoard: false,
              playerCount: _resetCount,
              startingLife: _integer('reset.life', min: 1, max: 1000000),
              emptySlot: _emptySlot,
            ),
            button: 'Archive & complete reset',
            closeOnSuccess: true,
          ),
          icon: Icons.delete_sweep_outlined,
        ),
      ],
    ),
  ]);

  Widget _dicePage() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 800 ? 3 : 2;
      final width = (constraints.maxWidth - 40 - (columns - 1) * 12) / columns;
      return SingleChildScrollView(
        key: const PageStorageKey('dice-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _contentTop(
              Align(
                alignment: Alignment.centerLeft,
                child: _button(
                  'Roll selected dice',
                  () => _update(() {
                    final random = Random.secure();
                    _diceResults.clear();
                    _diceTotal = 0;
                    for (final entry in _diceCounts.entries) {
                      if (entry.value == 0) continue;
                      final rolls = List.generate(
                        entry.value,
                        (_) => random.nextInt(entry.key) + 1,
                      );
                      _diceResults.add(
                        '${entry.value}d${entry.key}: ${rolls.join(' · ')}',
                      );
                      _diceTotal =
                          _diceTotal! +
                          rolls.fold(0, (sum, value) => sum + value);
                    }
                  }),
                  icon: Icons.casino,
                  primary: true,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final entry in _diceCounts.entries)
                  SizedBox(
                    width: width,
                    child: IconButtonTheme(
                      data: IconButtonThemeData(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                      child: _stepper(
                        'd${entry.key}',
                        entry.value,
                        () => _update(
                          () => _diceCounts[entry.key] = max(
                            0,
                            _diceCounts[entry.key]! - 1,
                          ),
                        ),
                        () => _update(
                          () => _diceCounts[entry.key] = min(
                            20,
                            _diceCounts[entry.key]! + 1,
                          ),
                        ),
                        holdMinusStep: (amount) => _update(
                          () => _diceCounts[entry.key] = max(
                            0,
                            _diceCounts[entry.key]! - amount,
                          ),
                        ),
                        holdPlusStep: (amount) => _update(
                          () => _diceCounts[entry.key] = min(
                            20,
                            _diceCounts[entry.key]! + amount,
                          ),
                        ),
                        maximum: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_diceTotal != null) ...[
              _section('Total: $_diceTotal'),
              Column(
                key: const ValueKey('dice-results'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final result in _diceResults)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        result,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  if (_diceResults.isEmpty)
                    const Text('Select at least one die.'),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _settingsPage() => _list([
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
              _section('Shared game state'),
              Wrap(
                spacing: 8,
                children: [
                  for (final state in ['neither', 'day', 'night'])
                    ChoiceChip(
                      label: Text(
                        state == 'neither'
                            ? 'Neither day nor night'
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
                    _update(() => _status = 'Your token database is current.');
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
              ),
              _button(
                'Use bundled catalog',
                () => _confirm(
                  'Restore the bundled catalog?',
                  'Remove the downloaded catalog update. Custom definitions and artwork choices remain.',
                  () => catalog.revertToBundled(),
                ),
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
                () => showTableSupport(
                  context,
                  quarterTurns: widget.quarterTurns,
                ),
                icon: Icons.favorite_outline,
              ),
            ],
          ),
        ),
      ),
    ]),
  ]);
}

part of 'table_workspace.dart';

extension _GamePages on _TableWorkspaceState {
  Widget _playerPage() {
    final player = p;
    if (player == null) return _list([const Text('Open a player’s menu to edit their life and appearance.')]);
    final profile = c.profile(player.seatId);
    return _list([
      _section('$_seatName · ${player.life} life', detail: player.warnings.isEmpty ? null : player.warnings.join(' · ')),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final delta in [-10, -5, -1, 1, 5, 10]) _button('${delta > 0 ? '+' : ''}$delta life', () => _run(() => c.adjustLife(player.id, delta)), icon: delta < 0 ? Icons.remove : Icons.add)]),
      _input('life.delta', 'Change life by', initial: '-1', numeric: true, helper: 'A negative number loses life; a positive number gains life.'),
      _button('Apply life change', () => _run(() => c.adjustLife(player.id, _integer('life.delta')), success: 'Life changed.'), primary: true),
      _input('life.set', 'Set life total to', initial: '${player.life}', numeric: true),
      _button('Set life total', () => _run(() => c.setLife(player.id, _integer('life.set')), success: 'Life total set.')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _button('Commander damage', () => _go(WorkspacePage.commanderDamage), icon: Icons.shield_outlined),
        _button('Player counters', () => _go(WorkspacePage.counters), icon: Icons.hexagon_outlined),
        _button('Reset only this life total', () => _confirm('Reset $_seatName’s life?', 'Set life to ${c.session.startingLife}. Commander damage, player counters, tokens, and other players remain as they are.', () => c.setLife(player.id, c.session.startingLife))),
      ]),
      _section('Statuses'),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('City’s blessing'), subtitle: const Text('Independent of every other player.'), value: player.citysBlessing, onChanged: (value) => _run(() => c.setCitysBlessing(player.id, value))),
      ListTile(contentPadding: EdgeInsets.zero, title: Text(c.session.monarchPlayerId == player.id ? 'You are the monarch' : 'Monarch'), subtitle: Text(c.session.monarchPlayerId == null ? 'No monarch yet' : 'Current holder: ${_nameForPlayer(c.session.monarchPlayerId!)}'), trailing: _button(c.session.monarchPlayerId == player.id ? 'Clear' : 'Claim', () => _run(() => c.setMonarch(c.session.monarchPlayerId == player.id ? null : player.id)), icon: Icons.workspace_premium_outlined)),
      _section('Saved player appearance', detail: 'Name, color and life artwork persist between games.'),
      _input('profile.name', 'Player name', initial: profile.name),
      _button('Save name', () => _run(() async {
        final name = _field('profile.name').text.trim();
        if (name.isEmpty) throw const FormatException('Enter a player name.');
        return c.updateState('Rename seat', (state) => state.profiles.firstWhere((s) => s.id == player.seatId).name = name);
      }, success: 'Player name saved.'), primary: true),
      Wrap(spacing: 12, runSpacing: 12, children: [for (final color in [0xffd7bd78, 0xff83b7ce, 0xffb498ca, 0xff92bc91, 0xffd28f80, 0xffb2b5c1, 0xffe6ba89, 0xff8bc8bf]) Semantics(label: 'Seat color ${color.toRadixString(16)}', button: true, selected: profile.color == color, child: InkWell(onTap: () => _run(() => c.updateState('Change seat color', (state) => state.profiles.firstWhere((s) => s.id == player.seatId).color = color)), child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle, border: Border.all(color: profile.color == color ? Colors.white : Colors.transparent, width: 4))))) ]),
      const SizedBox(height: 12),
      if (profile.artworkUrl != null) Align(alignment: Alignment.centerLeft, child: _art(profile.artworkUrl, width: 180, height: 110)),
      Wrap(spacing: 8, children: [
        _button('Choose life artwork', () => _run(() async { final art = await _pickArtwork(); if (art != null) return c.updateState('Change seat artwork', (state) => state.profiles.firstWhere((s) => s.id == player.seatId).artworkUrl = art); }), icon: Icons.image_outlined),
        if (profile.artworkUrl != null) _button('Remove life artwork', () => _run(() => c.updateState('Remove seat artwork', (state) => state.profiles.firstWhere((s) => s.id == player.seatId).artworkUrl = null)), icon: Icons.hide_image_outlined),
      ]),
      _section('Token creation'),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Apply summoning sickness'), subtitle: const Text('Creature tokens without haste enter summoning sick.'), value: player.summoningSicknessEnabled, onChanged: (value) => _run(() => c.updateState('Summoning sickness setting', (state) => state.session.player(player.id).summoningSicknessEnabled = value, recordHistory: true))),
      _section('Your commanders', detail: 'Each commander has a distinct identity, including partners with the same name.'),
      for (final commander in c.session.commanders.where((s) => s.ownerPlayerId == player.id)) ...[
        _input('commander.${commander.id}.name', 'Commander name', initial: commander.name),
        Wrap(spacing: 8, children: [
          _button('Rename commander', () => _run(() => c.renameCommander(commander.id, _field('commander.${commander.id}.name').text.trim()))),
          _button('Remove source', () => _confirm('Remove ${commander.name}?', 'This removes the active source. Existing damage and history will be handled by the saved source identity.', () => c.removeCommander(commander.id)), icon: Icons.remove_circle_outline),
        ]),
      ],
      _input('commander.new', 'Add commander or partner'),
      _button('Add commander', () => _run(() => c.addCommander(player.id, _field('commander.new').text.trim()), success: 'Commander added.', after: () => _field('commander.new').clear()), icon: Icons.add),
    ]);
  }

  String _nameForPlayer(String id) {
    for (final player in c.session.players) { if (player.id == id) return c.profile(player.seatId).name; }
    return 'Previous player';
  }

  Widget _countersPage() {
    final player = p;
    if (player == null) return _list([const Text('Select a player first.')]);
    final counters = {'energy': 0, 'poison': 0, 'experience': 0, 'radiation': 0, ...player.counters};
    return _list([
      _section('Counters on $_seatName', detail: 'Life: ${player.life}. These are player counters; token counter modifiers do not apply.'),
      for (final counter in counters.entries) ...[
        _stepper('${counter.key[0].toUpperCase()}${counter.key.substring(1)}', counter.value, () => _run(() => c.adjustPlayerCounter(player.id, counter.key, -1)), () => _run(() => c.adjustPlayerCounter(player.id, counter.key, 1)), detail: counter.key == 'poison' && counter.value >= 10 ? 'Poison threshold reached. Controls stay available.' : null),
        ExpansionTile(title: Text('Set ${counter.key} directly'), children: [
          _input('counter.${counter.key}', 'Set ${counter.key} to', initial: '${counter.value}', numeric: true),
          _button('Set counter', () => _run(() => c.setPlayerCounter(player.id, counter.key, _integer('counter.${counter.key}', min: 0)))),
        ]),
      ],
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('City’s blessing'), value: player.citysBlessing, onChanged: (value) => _run(() => c.setCitysBlessing(player.id, value))),
    ]);
  }

  Widget _commanderPage() {
    final player = p;
    if (player == null) return _list([const Text('Select the player receiving damage first.')]);
    final sources = c.session.commanders;
    if (sources.isEmpty) return _list([
      _section('No commander sources yet', detail: 'Add each player’s commander or partners in that player’s settings. Each source retains its identity when renamed.'),
      _button('Player settings', () => _go(WorkspacePage.player)),
    ]);
    return _list([
      _section('Damage received by $_seatName', detail: 'Current life: ${player.life}. New combat damage also subtracts life in one undoable action. Correcting a recorded total changes only this ledger.'),
      for (final source in sources) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(source.name, style: Theme.of(context).textTheme.titleMedium),
        Text('Source: ${_nameForPlayer(source.ownerPlayerId)}${source.ownerPlayerId == player.id ? ' · own commander' : ''} · ${source.id.substring(0, 6)}'),
        Text('Recorded damage: ${player.commanderDamage[source.id] ?? 0}${(player.commanderDamage[source.id] ?? 0) >= 21 ? ' · 21 damage warning' : ''}'),
        _input('damage.${source.id}', 'New combat damage', initial: '1', numeric: true),
        _button('Record damage & lose life', () => _run(() => c.adjustCommanderDamage(player.id, source.id, _integer('damage.${source.id}', min: 0), adjustLife: true), success: 'Damage and life saved together.'), icon: Icons.shield_outlined, primary: true),
        ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Correct recorded damage only'), children: [
          _input('damageCorrection.${source.id}', 'Set recorded damage to', initial: '${player.commanderDamage[source.id] ?? 0}', numeric: true),
          _button('Correct ledger only', () => _run(() => c.setCommanderDamage(player.id, source.id, _integer('damageCorrection.${source.id}', min: 0)), success: 'Ledger corrected; life was not changed.')),
        ]),
      ]))),
      _button('Correct life separately', () => _go(WorkspacePage.player)),
    ]);
  }

  Widget _historyPage() => _list([
    _section('This game’s timeline', detail: 'Undo always walks back the latest action across the entire table. Repeated similar actions settle together; another action closes that group.'),
    if (c.session.history.isNotEmpty) _button('Undo latest: ${c.session.history.last.summary}', () => _run(() => c.undo(), success: 'Latest action undone.'), icon: Icons.undo, primary: true),
    if (c.session.history.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('This game has no actions yet.')),
    for (final entry in c.session.history.reversed) Card(child: ListTile(
      leading: Icon(entry.playerId == null ? Icons.table_restaurant : Icons.person_outline),
      title: Text(entry.summary),
      subtitle: Text('${entry.playerLabel ?? 'Table'} · ${_date(entry.updatedAt)}'),
    )),
  ]);

  String _date(DateTime date) {
    final d = date.toLocal();
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _resetPage() => _list([
    _section('Start a new game', detail: 'The current game and its full timeline are archived before a reset. Permanent player names, colors, artwork and saved setups are preserved.'),
    Wrap(spacing: 10, children: [for (final count in [2, 3, 4]) ChoiceChip(label: Text('$count players'), selected: _resetCount == count, onSelected: (_) => _update(() => _resetCount = count))]),
    if (_resetCount == 3) ...[
      _section('Empty control slot'),
      Wrap(spacing: 8, children: [for (var slot = 0; slot < 4; slot++) ChoiceChip(label: Text(['Bottom left', 'Top left', 'Top right', 'Bottom right'][slot]), selected: _emptySlot == slot, onSelected: (_) => _update(() => _emptySlot = slot))]),
    ],
    _input('reset.life', 'Starting life', initial: '${c.session.startingLife}', numeric: true),
    Wrap(spacing: 8, children: [for (final life in [20, 40]) _button('$life life', () => _field('reset.life').text = '$life')]),
    const SizedBox(height: 18),
    _button('Reset with current configuration', () => _confirm('Reset with board?', 'Start a $_resetCount-player game. Keep remaining players’ token entries at zero and enabled utility selections; clear token counters, utility runtime values, damage and player counters. Restore starting life. Disable all modifier sources/custom rules. Removed seats lose their live boards. Save the current game to archives first.', () => c.resetGame(keepBoard: true, playerCount: _resetCount, startingLife: _integer('reset.life', min: 1, max: 1000000), emptySlot: _emptySlot), button: 'Archive & reset with board'), icon: Icons.restart_alt),
    const SizedBox(height: 8),
    _button('Complete reset', () => _confirm('Clear boards & restart?', 'Start a $_resetCount-player game with empty token and utility lanes, starting life, cleared damage/counters/statuses, and disabled modifier sources/custom rules. Permanent seat appearances and saved setups remain. Archive the current game first.', () => c.resetGame(keepBoard: false, playerCount: _resetCount, startingLife: _integer('reset.life', min: 1, max: 1000000), emptySlot: _emptySlot), button: 'Archive & complete reset'), icon: Icons.delete_sweep_outlined),
    _section('Reload a previous game state', detail: 'Restore the complete archived game and its timeline. The current game is saved first. The latest 10 archives are retained.'),
    if (c.state.archives.isEmpty) const Text('No archived games yet.'),
    for (final archive in c.state.archives.reversed) Card(child: ListTile(
      title: Text(archive.label), subtitle: Text('${_date(archive.savedAt)} · ${archive.session.players.length} players · ${archive.session.history.length} history entries'),
      trailing: const Icon(Icons.restore),
      onTap: () => _confirm('Restore ${archive.label}?', 'Save the current game first, then restore this archive’s board, life, damage, rules and full timeline. Saved setups and permanent player customization will not be overwritten.', () => c.restoreArchive(archive.id), button: 'Save current & restore'),
    )),
    _section('Board wipes', detail: 'A wipe affects only the named player’s tokens. Life, commander damage, player counters and modifier sources remain.'),
    for (final player in c.session.players) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(_nameForPlayer(player.id)),
      _button('Wipe creatures', () => _confirm('Wipe ${_nameForPlayer(player.id)}’s creatures?', 'Remove creature tokens from this player only. Undo is available in game history.', () => _board.bulk(player.id, 'wipe_creatures'), button: 'Wipe creatures'), icon: Icons.delete_outline),
      _button('Wipe all tokens', () => _confirm('Wipe ${_nameForPlayer(player.id)}’s tokens?', 'Remove every token from this player only. Utilities and all non-token state remain. Undo is available in game history.', () => _board.bulk(player.id, 'wipe_all'), button: 'Wipe all tokens'), icon: Icons.delete_outline),
    ])),
  ]);

  Widget _dicePage() => _list([
    _section('Roll dice', detail: 'Choose any mix of standard dice. Rolling does not change game state.'),
    for (final entry in _diceCounts.entries) _stepper('d${entry.key}', entry.value, () => _update(() => _diceCounts[entry.key] = max(0, entry.value - 1)), () => _update(() => _diceCounts[entry.key] = min(20, entry.value + 1))),
    _button('Roll selected dice', () => _update(() {
      final random = Random.secure();
      _diceResults.clear(); _diceTotal = 0;
      for (final entry in _diceCounts.entries) {
        if (entry.value == 0) continue;
        final rolls = List.generate(entry.value, (_) => random.nextInt(entry.key) + 1);
        _diceResults.add('${entry.value}d${entry.key}: ${rolls.join(' · ')}');
        _diceTotal = _diceTotal! + rolls.fold(0, (sum, value) => sum + value);
      }
    }), icon: Icons.casino, primary: true),
    if (_diceTotal != null) ...[
      _section('Total: $_diceTotal'),
      for (final result in _diceResults) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(result, style: Theme.of(context).textTheme.titleLarge)),
      if (_diceResults.isEmpty) const Text('Select at least one die.'),
    ],
  ]);

  Widget _settingsPage() => _list([
    _section('Shared game state'),
    Wrap(spacing: 8, children: [for (final state in ['neither', 'day', 'night']) ChoiceChip(label: Text(state == 'neither' ? 'Neither day nor night' : state[0].toUpperCase() + state.substring(1)), selected: c.session.dayNight == state, onSelected: (_) => _run(() => c.setDayNight(state)))]),
    _section('Token catalog', detail: '${catalog.tokens.length} definitions · database version ${catalog.version}. Catalog updates preserve current artwork and custom token selections.'),
    _button('Check for catalog updates', () => _run(() async {
      final update = await catalog.checkForUpdate();
      if (update.error != null) throw StateError(update.error!);
      if (update.version <= catalog.version) { _update(() => _status = 'Your token database is current.'); return; }
      _confirm('Update token catalog?', 'Download database version ${update.version}. The download will be checked before it replaces the current catalog.', () => catalog.applyUpdate(update), button: 'Download & verify');
    }), icon: Icons.download),
    _button('Use bundled catalog', () => _confirm('Restore the bundled catalog?', 'Remove the downloaded catalog update. Custom definitions and artwork choices remain.', () => catalog.revertToBundled())),
    _section('Appearance'),
    Wrap(spacing: 8, children: [for (final theme in ['system', 'light', 'dark']) ChoiceChip(label: Text(theme[0].toUpperCase() + theme.substring(1)), selected: (c.state.settings['theme'] ?? 'dark') == theme, onSelected: (_) => _run(() => c.updateState('Change theme', (state) => state.settings['theme'] = theme)))]),
    _section('Player appearance reset', detail: 'This separate reset clears saved player names, colors and life artwork only. It does not delete the current game or setups.'),
    _button('Reset saved seat appearance', () => _confirm('Reset all saved player appearances?', 'Replace all saved names and colors with defaults and remove life artwork, including hidden seats. This cannot be undone through game history.', () => c.updateState('Reset seat appearances', (state) {
      const colors = [0xffd7bd78, 0xff83b7ce, 0xffb498ca, 0xff92bc91];
      for (var index = 0; index < state.profiles.length; index++) {
        state.profiles[index].name = 'Player ${index + 1}'; state.profiles[index].color = colors[index % colors.length]; state.profiles[index].artworkUrl = null;
      }
    }), button: 'Reset appearances'), icon: Icons.person_off_outlined),
    _section('Tripling Season · Tablet edition', detail: 'Free to play, with no ads. Optional supporter cosmetics never gate game features.'),
    _button('Support this app', () => showTableSupport(context, quarterTurns: widget.quarterTurns), icon: Icons.favorite_outline),
  ]);
}

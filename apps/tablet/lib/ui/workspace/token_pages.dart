part of 'table_workspace.dart';

extension _TokenPages on _TableWorkspaceState {
  Widget _tokensPage() {
    if (p == null) return _list([const Text('Open Add tokens from a player’s menu.')]);
    if (_createCustom) return _customTokenPage();
    final selected = _selectedDefinition;
    if (selected != null) {
      final quantity = _field('create.quantity', '1');
      return _list([
        _button('Back to search', () => _update(() => _selectedDefinition = null), icon: Icons.arrow_back),
        _section(selected.name, detail: '${selected.pt} ${selected.cleanType}\n${selected.abilities}'.trim()),
        if (selected.artwork.isNotEmpty) Align(alignment: Alignment.centerLeft, child: _art(selected.artwork.first.url, width: 160, height: 150)),
        _input('create.quantity', 'Quantity before modifiers', initial: '1', numeric: true),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Create tapped'), value: _createTapped, onChanged: (v) => _update(() => _createTapped = v)),
        ValueListenableBuilder<TextEditingValue>(valueListenable: quantity, builder: (context, value, _) {
          final count = int.tryParse(value.text);
          if (count == null || count < 1) return const Text('Enter a positive quantity to preview creation.');
          try {
            final result = _board.preview(p!.id, selected, count);
            return _section('Will create for $_seatName', detail: TokenCreationResult.breakdownString(result));
          } catch (e) { return Text('$e'); }
        }),
        _button('Create tokens', () => _run(() => _board.createToken(p!.id, selected, quantity: _integer('create.quantity', min: 1, max: 999999), tapped: _createTapped, expectedRevision: c.session.revision), success: 'Tokens created for $_seatName.', after: () => _selectedDefinition = null), icon: Icons.add, primary: true),
      ]);
    }
    final query = _field('tokens.search');
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: Row(children: [
        Expanded(child: PlayerField(controller: query, label: 'Search tokens, abilities, type, or P/T')),
        const SizedBox(width: 12),
        _button('Custom token', () => _update(() => _createCustom = true), icon: Icons.add),
      ])),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(children: [
        for (final tab in ['all', 'recent', 'favorites', 'custom'])
          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text('${tab[0].toUpperCase()}${tab.substring(1)}'), selected: _tokenTab == tab, onSelected: (_) => _update(() => _tokenTab = tab))),
        const SizedBox(width: 14),
        DropdownButton<Category?>(value: _category, hint: const Text('All types'), items: [
          const DropdownMenuItem<Category?>(value: null, child: Text('All types')),
          for (final category in Category.values) DropdownMenuItem(value: category, child: Text(category.displayName)),
        ], onChanged: (value) => _update(() => _category = value)),
      ])),
      if (catalog.error != null) Padding(padding: const EdgeInsets.all(16), child: Text(catalog.error!)),
      Expanded(child: ValueListenableBuilder<TextEditingValue>(valueListenable: query, builder: (context, value, _) {
        final tokens = catalog.search(value.text, tab: _tokenTab, category: _category);
        if (!catalog.loaded && catalog.error == null) return const Center(child: CircularProgressIndicator());
        if (tokens.isEmpty) return const Center(child: Text('No matching tokens. Try another search or create a custom token.'));
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: tokens.length, itemBuilder: (context, index) {
          final token = tokens[index];
          return Card(child: ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: _art(token.artwork.isEmpty ? null : token.artwork.first.url, width: 58, height: 64)),
            title: Text('${token.name}${token.pt.isEmpty ? '' : ' · ${token.pt}'}'),
            subtitle: Text('${token.cleanType}${token.abilities.isEmpty ? '' : '\n${token.abilities}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(tooltip: catalog.isFavorite(token.id) ? 'Remove favorite' : 'Favorite token', icon: Icon(catalog.isFavorite(token.id) ? Icons.star : Icons.star_border), onPressed: () => _run(() => catalog.favorite(token.id))),
            onTap: () => _update(() => _selectedDefinition = token),
          ));
        });
      })),
    ]);
  }

  Widget _customTokenPage() => _list([
    _section('Create a reusable custom token', detail: 'Saving adds this definition to the custom library. Choose it to create tokens for $_seatName.'),
    _input('custom.name', 'Name'), _input('custom.pt', 'Base power / toughness', initial: '1/1'),
    _input('custom.type', 'Type', initial: 'Creature'), _input('custom.colors', 'Color identity', helper: 'W, U, B, R, G, or leave empty for colorless'),
    _input('custom.abilities', 'Abilities', maxLines: 3),
    Wrap(spacing: 10, children: [
      _button('Cancel', () => _update(() { _createCustom = false; for (final key in _fields.keys.where((k) => k.startsWith('custom.')).toList()) { _fields[key]!.clear(); } }), icon: Icons.close),
      _button('Save custom token', () => _run(() async {
        final name = _field('custom.name').text.trim();
        final colors = _field('custom.colors').text.trim().toUpperCase().replaceAll(' ', '');
        if (name.isEmpty) throw const FormatException('A token needs a name.');
        if (!RegExp(r'^[WUBRG]*$').hasMatch(colors)) throw const FormatException('Use W, U, B, R and G for color identity.');
        final definition = TokenDefinition(name: name, pt: _field('custom.pt').text.trim(), type: _field('custom.type').text.trim(), colors: colors, abilities: _field('custom.abilities').text.trim(), popularity: 0);
        await catalog.saveCustom(definition);
        _selectedDefinition = definition; _createCustom = false;
      }, success: 'Custom token saved.'), primary: true),
    ]),
  ]);

  Widget _tokenPage() {
    final player = p;
    if (player == null) return _list([const Text('Select a player first.')]);
    TokenState? token;
    for (final candidate in player.tokens) { if (candidate.id == _itemId) token = candidate; }
    if (token == null) return _list([const Text('This token is no longer on the board.'), _button('Add tokens', () => _go(WorkspacePage.tokens))]);
    final t = token;
    final key = 'token.${t.id}';
    final options = t.artworkOptions.isNotEmpty ? t.artworkOptions : (catalog.byId(t.definitionId)?.artwork.map((a) => a.toJson()).toList() ?? <Map<String, dynamic>>[]);
    return _list([
      Row(children: [if (t.artworkUrl != null) Padding(padding: const EdgeInsets.only(right: 16), child: _art(t.artworkUrl, width: 100, height: 110)), Expanded(child: _section(t.name, detail: '${t.amount} total · ${t.tapped} tapped · ${t.summoningSick} summoning sick'))]),
      _stepper('Quantity', t.amount, () => _run(() => _board.changeQuantity(player.id, t.id, -1)), () => _run(() => _board.changeQuantity(player.id, t.id, 1))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _button('Tap all', () => _run(() => _board.editToken(player.id, t.id, tapped: t.amount))),
        _button('Untap all', () => _run(() => _board.editToken(player.id, t.id, tapped: 0))),
        _button('Clear sickness', () => _run(() => _board.editToken(player.id, t.id, summoningSick: 0))),
        _button('Copy stack', () => _run(() => _board.copyToken(player.id, t.id), success: 'Stack copied.')),
      ]),
      ExpansionTile(title: const Text('Edit token properties'), childrenPadding: const EdgeInsets.symmetric(horizontal: 12), children: [
        _input('$key.name', 'Name', initial: t.name),
        _input('$key.pt', 'Base power / toughness', initial: t.pt),
        _input('$key.type', 'Type', initial: t.type),
        _input('$key.colors', 'Color identity', initial: t.colors),
        _input('$key.abilities', 'Abilities', initial: t.abilities, maxLines: 3),
        _input('$key.amount', 'Set quantity', initial: '${t.amount}', numeric: true),
        _input('$key.tapped', 'Set tapped', initial: '${t.tapped}', numeric: true),
        _input('$key.sick', 'Set summoning sick', initial: '${t.summoningSick}', numeric: true),
        _button('Save token', () => _run(() => _board.editToken(player.id, t.id, name: _field('$key.name').text.trim(), pt: _field('$key.pt').text.trim(), type: _field('$key.type').text.trim(), colors: _field('$key.colors').text.trim().toUpperCase(), abilities: _field('$key.abilities').text, amount: _integer('$key.amount', min: 0, max: 999999), tapped: _integer('$key.tapped', min: 0, max: 999999), summoningSick: _integer('$key.sick', min: 0, max: 999999)), success: 'Token properties saved.'), primary: true),
      ]),
      _section('Counters'),
      for (final entry in {'+1/+1': t.plusOneCounters, '-1/-1': t.minusOneCounters, ...t.counters}.entries)
        _stepper(entry.key, entry.value, () => _run(() => _board.counter(player.id, t.id, entry.key, -1)), () => _run(() => _board.counter(player.id, t.id, entry.key, 1))),
      Row(children: [Expanded(child: _input('$key.counterName', 'Counter name')), const SizedBox(width: 8), _button('Add counter', () => _run(() async {
        final name = _field('$key.counterName').text.trim();
        if (name.isEmpty) throw const FormatException('Enter a counter name.');
        await _board.counter(player.id, t.id, name, 1);
      }), icon: Icons.add)]),
      ExpansionTile(title: const Text('Split & merge'), children: [
        _input('$key.split', 'Quantity to split into a new stack', initial: '1', numeric: true),
        _button('Split stack', () => _run(() => _board.splitToken(player.id, t.id, _integer('$key.split', min: 1, max: t.amount - 1)), success: 'Stack split.')),
        for (final other in player.tokens.where((v) => v.id != t.id && v.definitionId == t.definitionId))
          ListTile(title: Text('Merge into ${other.name} (${other.amount})'), subtitle: const Text('Only compatible stacks can merge.'), trailing: const Icon(Icons.merge), onTap: () => _confirm('Merge ${t.name}?', 'Combine this stack with the selected stack for $_seatName. The source stack will be removed. Latest-action undo restores both.', () => _board.mergeTokens(player.id, t.id, other.id))),
      ]),
      ExpansionTile(title: const Text('Artwork for this game'), subtitle: const Text('Selections belong to this player and this game.'), children: [
        Wrap(spacing: 10, runSpacing: 10, children: [for (final art in options) SizedBox(width: 150, child: InkWell(onTap: () => _run(() => _board.setArtwork(player.id, t.id, art['url'] as String, set: art['set'] as String?, artist: art['artist'] as String?)), child: Column(children: [_art(art['url'] as String?, width: 150, height: 130), Text('${art['set'] ?? ''}\n${art['artist'] ?? ''}', maxLines: 2, textAlign: TextAlign.center)])))]),
        const SizedBox(height: 10),
        _button('Upload artwork', () => _run(() async { final url = await _pickArtwork(); if (url != null) await _board.setArtwork(player.id, t.id, url, artist: 'user uploaded'); }), icon: Icons.upload),
        _input('$key.artUrl', 'Artwork image URL', initial: t.artworkUrl?.startsWith('http') == true ? t.artworkUrl! : ''),
        _button('Use image URL', () => _run(() => _board.setArtwork(player.id, t.id, _field('$key.artUrl').text.trim())), icon: Icons.image),
      ]),
      const SizedBox(height: 20),
      _button('Delete stack', () => _confirm('Delete ${t.name}?', 'Remove this stack of ${t.amount} from $_seatName’s board. Undo is available in game history.', () => _board.deleteToken(player.id, t.id), button: 'Delete stack'), icon: Icons.delete_outline),
    ]);
  }
}

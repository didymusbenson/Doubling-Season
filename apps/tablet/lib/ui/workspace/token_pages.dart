part of 'table_workspace.dart';

extension _TokenPages on _TableWorkspaceState {
  Widget _tokensPage() {
    if (p == null) {
      return _list([const Text('Open Add tokens from a player’s menu.')]);
    }
    if (_createCustom) return _customTokenPage();
    final selected = _selectedDefinition;
    if (selected != null) {
      if (RingService.isRingDefinition(selected.name, selected.type)) {
        return _list([
          _button(
            'Back to search',
            () => _update(() => _selectedDefinition = null),
            icon: Icons.arrow_back,
          ),
          _section(
            'The Ring',
            detail:
                'Track your Ring progress and choose a Ring-bearer with a utility.',
          ),
          _button(
            'Add The Ring utility',
            () => _run(
              () => _board.addUtility(p!.id, RingService.kind),
              closeOnSuccess: true,
            ),
            primary: true,
          ),
        ]);
      }
      final scope = _board.scope(p!.id);
      final revision = c.session.revision;
      final quantity = _field('create.quantity', '1');
      return _list([
        _button(
          'Back to search',
          () => _update(() => _selectedDefinition = null),
          icon: Icons.arrow_back,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    selected.name,
                    detail: '${selected.pt} ${selected.cleanType}'.trim(),
                  ),
                  if (selected.abilities.isNotEmpty)
                    ManaText(selected.abilities),
                  if (selected.artwork.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _art(
                        selected.artwork.first.url,
                        width: 160,
                        height: 150,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _input(
                    'create.quantity',
                    'Quantity before modifiers',
                    initial: '1',
                    numeric: true,
                  ),
                  _creationQuantityShortcuts(quantity),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Create tapped'),
                    value: _createTapped,
                    onChanged: (v) => _update(() => _createTapped = v),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: quantity,
                    builder: (context, value, _) {
                      final count = int.tryParse(value.text);
                      if (count == null || count < 1) {
                        return const Text(
                          'Enter a positive quantity to preview creation.',
                        );
                      }
                      try {
                        final result = _board.preview(p!.id, selected, count);
                        return _section(
                          'Will create for $_seatName',
                          detail: TokenCreationResult.breakdownString(result),
                        );
                      } catch (e) {
                        return Text('$e');
                      }
                    },
                  ),
                  _button(
                    'Create tokens',
                    () => _run(
                      () => _board.createToken(
                        p!.id,
                        selected,
                        quantity: _integer(
                          'create.quantity',
                          min: 1,
                          max: 999999,
                        ),
                        tapped: _createTapped,
                        expectedRevision: revision,
                        captured: scope,
                      ),
                      closeOnSuccess: true,
                    ),
                    icon: Icons.add,
                    primary: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ]);
    }
    final query = _field('tokens.search');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: PlayerField(
                  controller: query,
                  label: 'Search tokens, abilities, type, or P/T',
                ),
              ),
              IconButton(
                tooltip: 'Clear token search',
                onPressed: () => _update(query.clear),
                icon: const Icon(Icons.clear),
              ),
              const SizedBox(width: 4),
              _button(
                'Custom token',
                () => _update(() => _createCustom = true),
                icon: Icons.add,
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              for (final tab in ['all', 'recent', 'favorites', 'custom'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${tab[0].toUpperCase()}${tab.substring(1)}'),
                    selected: _tokenTab == tab,
                    onSelected: (_) => _update(() => _tokenTab = tab),
                  ),
                ),
              const SizedBox(width: 14),
              ChoiceChip(
                label: const Text('All types'),
                selected: _category == null,
                onSelected: (_) => _update(() => _category = null),
              ),
              for (final category in Category.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(category.displayName),
                    selected: _category == category,
                    onSelected: (_) => _update(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final color in const {
                'W': 'White',
                'U': 'Blue',
                'B': 'Black',
                'R': 'Red',
                'G': 'Green',
                'C': 'Colorless',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilterChip(
                    avatar: ManaText('{${color.key}}'),
                    label: Text(color.value),
                    selected: _tokenColors.contains(color.key),
                    onSelected: (selected) => _update(() {
                      if (color.key == 'C') {
                        _tokenColors.clear();
                      } else {
                        _tokenColors.remove('C');
                      }
                      selected
                          ? _tokenColors.add(color.key)
                          : _tokenColors.remove(color.key);
                    }),
                  ),
                ),
              IconButton(
                tooltip: 'Clear filters',
                icon: const Icon(Icons.filter_alt_off_outlined),
                onPressed: () => _update(() {
                  _tokenColors.clear();
                  _category = null;
                  query.clear();
                }),
              ),
            ],
          ),
        ),
        if (catalog.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(catalog.error!),
          ),
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: query,
            builder: (context, value, _) {
              final tokens = catalog.search(
                value.text,
                tab: _tokenTab,
                category: _category,
                colors: _tokenColors,
              );
              if (!catalog.loaded && catalog.error == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (tokens.isEmpty) {
                return const Center(
                  child: Text(
                    'No matching tokens. Try another search or create a custom token.',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tokens.length,
                itemBuilder: (context, index) {
                  final token = tokens[index];
                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _art(
                          token.artwork.isEmpty
                              ? null
                              : token.artwork.first.url,
                          width: 58,
                          height: 64,
                        ),
                      ),
                      title: Text(
                        '${token.name}${token.pt.isEmpty ? '' : ' · ${token.pt}'}',
                      ),
                      subtitle: ManaText(
                        '${token.cleanType}${token.abilities.isEmpty ? '' : '\n${token.abilities}'}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: catalog.isFavorite(token.id)
                            ? 'Remove favorite'
                            : 'Favorite token',
                        icon: Icon(
                          catalog.isFavorite(token.id)
                              ? Icons.star
                              : Icons.star_border,
                        ),
                        onPressed: () => _run(() => catalog.favorite(token.id)),
                      ),
                      onTap: () => _selectToken(token),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _customTokenPage() => _list([
    _section(
      'Create a reusable custom token',
      detail:
          'Saving adds this definition to the custom library. Choose it to create tokens for $_seatName.',
    ),
    _gameGrid([
      _input('custom.name', 'Name'),
      _input('custom.pt', 'Base power / toughness', initial: '1/1'),
      _input('custom.type', 'Type', initial: 'Creature'),
      _input(
        'custom.colors',
        'Color identity',
        helper: 'W, U, B, R, G, or leave empty for colorless',
      ),
    ]),
    _input('custom.abilities', 'Abilities', maxLines: 3),
    if (_field('custom.artwork').text.isNotEmpty)
      Align(
        alignment: Alignment.centerLeft,
        child: _art(_field('custom.artwork').text, width: 180, height: 140),
      ),
    Wrap(
      spacing: 8,
      children: [
        _button(
          'Choose artwork',
          () => _run(() async {
            final image = await _pickArtwork();
            if (image != null) _field('custom.artwork').text = image;
          }),
          icon: Icons.add_photo_alternate_outlined,
        ),
        if (_field('custom.artwork').text.isNotEmpty)
          _button(
            'Remove artwork',
            () => _update(() => _field('custom.artwork').clear()),
            icon: Icons.hide_image_outlined,
          ),
      ],
    ),
    Wrap(
      spacing: 10,
      children: [
        _button(
          'Cancel',
          () => _update(() {
            _createCustom = false;
            for (final key
                in _fields.keys
                    .where((k) => k.startsWith('custom.'))
                    .toList()) {
              _fields[key]!.clear();
            }
          }),
          icon: Icons.close,
        ),
        _button(
          'Save custom token',
          () => _run(() async {
            final name = _field('custom.name').text.trim();
            final colors = _field(
              'custom.colors',
            ).text.trim().toUpperCase().replaceAll(' ', '');
            if (name.isEmpty) {
              throw const FormatException('A token needs a name.');
            }
            if (!RegExp(r'^[WUBRG]*$').hasMatch(colors)) {
              throw const FormatException(
                'Use W, U, B, R and G for color identity.',
              );
            }
            final definition = TokenDefinition(
              name: name,
              pt: _field('custom.pt').text.trim(),
              type: _field('custom.type').text.trim(),
              colors: colors,
              abilities: _field('custom.abilities').text.trim(),
              popularity: 0,
              artwork: _field('custom.artwork').text.isEmpty
                  ? const []
                  : [
                      ArtworkVariant(
                        set: 'Custom',
                        url: _field('custom.artwork').text,
                        artist: 'user uploaded',
                      ),
                    ],
            );
            await catalog.saveCustom(definition);
            _selectToken(definition);
            _createCustom = false;
          }, success: 'Custom token saved.'),
          primary: true,
        ),
      ],
    ),
  ]);

  void _selectToken(TokenDefinition definition) => _update(() {
    _selectedDefinition = definition;
    _field('create.quantity', '1').text = '1';
    _createTapped = false;
  });

  Widget _creationQuantityShortcuts(TextEditingController quantity) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: quantity,
        builder: (context, value, _) {
          final amount = int.tryParse(value.text) ?? 1;
          void setAmount(int next) =>
              quantity.text = '${next.clamp(1, 999999)}';
          return Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 156,
                child: HalfStepper(
                  height: 48,
                  label: 'Creation quantity',
                  value: '$amount',
                  decreaseLabel: 'Decrease creation quantity',
                  increaseLabel: 'Increase creation quantity',
                  onDecrease: _working || amount <= 1
                      ? null
                      : () => setAmount(amount - 1),
                  onIncrease: _working || amount >= 999999
                      ? null
                      : () => setAmount(amount + 1),
                ),
              ),
              for (var count = 1; count <= 5; count++)
                ChoiceChip(
                  label: Text('$count'),
                  selected: amount == count,
                  onSelected: (_) => setAmount(count),
                ),
            ],
          );
        },
      );

  Widget _tokenPage() {
    final player = p;
    if (player == null) return _list([const Text('Select a player first.')]);
    TokenState? token;
    for (final candidate in player.tokens) {
      if (candidate.id == _itemId) token = candidate;
    }
    if (token == null) {
      return _list([
        const Text('This token is no longer on the board.'),
        _button('Add tokens', () => _go(WorkspacePage.tokens)),
      ]);
    }
    return switch (_page) {
      WorkspacePage.tokenStatus => _tokenStatus(token),
      WorkspacePage.tokenCounters => _tokenCounters(token),
      WorkspacePage.tokenSplit => _tokenSplit(token),
      WorkspacePage.tokenArtwork => _list([
        TabletArtworkSelection(
          board: _board,
          catalog: catalog,
          player: player,
          token: token,
          quarterTurns: widget.quarterTurns,
        ),
      ]),
      _ => _tokenDetails(token),
    };
  }

  Widget _numberRow({
    required String id,
    required String label,
    required int value,
    required Future<void> Function(int) set,
    required Future<void> Function(int) change,
    int minimum = 0,
    int maximum = 999999,
  }) => Column(
    children: [
      _stepper(
        label,
        value,
        () => _runDirect(() => change(-1)),
        () => _runDirect(() => change(1)),
        minimum: minimum,
        maximum: maximum,
        edit: () => _update(() {
          _editingNumber = id;
          _field(id, '$value').text = '$value';
        }),
        holdMinusStep: (amount) => _runDirect(() => change(-amount)),
        holdPlusStep: (amount) => _runDirect(() => change(amount)),
      ),
      if (_editingNumber == id)
        Row(
          children: [
            Expanded(
              child: _input(
                id,
                'Set $label',
                initial: '$value',
                numeric: true,
                onCommit: (text) =>
                    set(_wholeNumber(text, min: minimum, max: maximum)),
              ),
            ),
            const SizedBox(width: 8),
            _button(
              'Set',
              () => _run(() async {}, after: () => _editingNumber = null),
              icon: Icons.check,
            ),
          ],
        ),
    ],
  );

  Widget _tokenStatus(TokenState t) {
    final player = p!;
    final scope = _board.scope(player.id);
    return _list([
      _section(
        t.name,
        detail:
            'Tap a number to set it. New eligible tokens gain summoning sickness when the total increases.',
      ),
      _numberRow(
        id: '${t.id}.status.amount',
        label: 'Total',
        value: t.amount,
        set: (v) =>
            _board.editToken(player.id, t.id, amount: v, captured: scope),
        change: (d) => _board.editToken(
          player.id,
          t.id,
          amount: (t.amount + d).clamp(0, 999999),
          captured: scope,
        ),
      ),
      if (!t.isEmblem)
        _numberRow(
          id: '${t.id}.status.tapped',
          label: 'Tapped',
          value: t.tapped,
          maximum: t.amount,
          set: (v) =>
              _board.editToken(player.id, t.id, tapped: v, captured: scope),
          change: (d) => _board.tapTokens(player.id, t.id, d),
        ),
      if (t.hasPowerToughness)
        _numberRow(
          id: '${t.id}.status.sick',
          label: 'Summoning sick',
          value: t.summoningSick,
          maximum: t.amount,
          set: (v) => _board.editToken(
            player.id,
            t.id,
            summoningSick: v,
            captured: scope,
          ),
          change: (d) => _board.editToken(
            player.id,
            t.id,
            summoningSick: (t.summoningSick + d).clamp(0, t.amount),
            captured: scope,
          ),
        ),
    ]);
  }

  Widget _tokenCounters(TokenState t) {
    final player = p!;
    final scope = _board.scope(player.id);
    final key = '${t.id}.counters';
    final selected = _selectedCounter;
    if (selected != null) {
      final quantity = _field('$key.quantity', '1');
      return _list([
        _button(
          'Back to counters',
          () => _update(() => _selectedCounter = null),
          icon: Icons.arrow_back,
        ),
        _section('Add $selected', detail: t.name),
        _input(
          '$key.quantity',
          'Counter quantity (applied exactly)',
          initial: '1',
          numeric: true,
        ),
        _creationQuantityShortcuts(quantity),
        _button(
          'Add to All',
          () => _run(
            () => _board.addSelectedCounter(
              player.id,
              t.id,
              selected,
              _integer('$key.quantity', min: 1, max: 999999),
            ),
            after: () => _selectedCounter = null,
          ),
          icon: Icons.add_circle_outline,
          primary: true,
        ),
        if (t.amount > 1) ...[
          const SizedBox(height: 10),
          const Text(
            'Split one untapped token with its existing counters, then add this exact quantity. The remaining stack keeps its status; the new token is not summoning sick.',
          ),
          _button(
            'Split & Add to One',
            () => _run(
              () => _board.splitAndAddCounter(
                player.id,
                t.id,
                selected,
                _integer('$key.quantity', min: 1, max: 999999),
                captured: scope,
              ),
              closeOnSuccess: true,
            ),
            icon: Icons.call_split,
          ),
        ],
      ]);
    }
    final query = _field('$key.search');
    return _list([
      _section(
        t.name,
        detail: 'Tap any counter number to Set an exact value, including zero.',
      ),
      for (final entry in <String, int>{
        '+1/+1': t.plusOneCounters,
        '-1/-1': t.minusOneCounters,
        ...t.counters,
      }.entries)
        _numberRow(
          id: '$key.set.${entry.key}',
          label: entry.key,
          value: entry.value,
          set: (value) => _board.setCounter(
            player.id,
            t.id,
            entry.key,
            value,
            captured: scope,
          ),
          change: (delta) => _board.counter(player.id, t.id, entry.key, delta),
        ),
      _section('Add counter'),
      PlayerField(
        controller: query,
        label: 'Search counters or enter a custom name',
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: query,
        builder: (context, value, _) {
          final search = value.text.trim();
          final names = CounterDatabase.predefinedCounters
              .where(
                (name) => name.toLowerCase().contains(search.toLowerCase()),
              )
              .toList();
          void choose(String name) => _update(() {
            _selectedCounter = name;
            _field('$key.quantity', '1').text = '1';
          });
          return Column(
            children: [
              if (search.isNotEmpty &&
                  !names.any(
                    (name) => name.toLowerCase() == search.toLowerCase(),
                  ))
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('Create “$search” counter'),
                  onTap: () => choose(search),
                ),
              for (final name in names)
                ListTile(
                  title: Text(name),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => choose(name),
                ),
            ],
          );
        },
      ),
    ]);
  }

  Widget _tokenSplit(TokenState t) {
    final player = p!;
    final scope = _board.scope(player.id);
    final key = '${t.id}.split';
    final quantity = _field('$key.quantity', '1');
    final tappedFirst = _field('$key.tappedFirst', 'false').text == 'true';
    return _list([
      _section(
        t.name,
        detail:
            'Counters and artwork stay on both stacks. Splitting clears summoning sickness on both.',
      ),
      if (t.amount < 2)
        const Text('At least two tokens are needed to split this stack.'),
      if (t.amount >= 2) ...[
        _input(
          '$key.quantity',
          'Quantity to split',
          initial: '1',
          numeric: true,
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: quantity,
          builder: (context, value, _) {
            final count = int.tryParse(value.text) ?? 0;
            if (count < 1 || count >= t.amount) {
              return Text('Choose from 1 to ${t.amount - 1}.');
            }
            final movedTapped = tappedFirst
                ? min(t.tapped, count)
                : count - min(count, t.amount - t.tapped);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepper(
                  'Split quantity',
                  count,
                  () => quantity.text = '${max(1, count - 1)}',
                  () => quantity.text = '${min(t.amount - 1, count + 1)}',
                  holdMinusStep: (amount) => quantity.text =
                      '${max(1, (int.tryParse(quantity.text) ?? 1) - amount)}',
                  holdPlusStep: (amount) => quantity.text =
                      '${min(t.amount - 1, (int.tryParse(quantity.text) ?? 1) + amount)}',
                  minimum: 1,
                  maximum: t.amount - 1,
                ),
                _section(
                  'Result preview',
                  detail:
                      'Original: ${t.amount - count} total · ${t.tapped - movedTapped} tapped\nNew stack: $count total · $movedTapped tapped',
                ),
              ],
            );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Move tapped tokens first'),
          subtitle: const Text('Off moves untapped tokens first.'),
          value: tappedFirst,
          onChanged: (value) =>
              _update(() => _field('$key.tappedFirst').text = '$value'),
        ),
        _button(
          'Split stack',
          () => _run(
            () => _board.splitToken(
              player.id,
              t.id,
              _integer('$key.quantity', min: 1, max: t.amount - 1),
              tappedFirst: tappedFirst,
              captured: scope,
            ),
            closeOnSuccess: true,
          ),
          icon: Icons.call_split,
          primary: true,
        ),
      ],
    ]);
  }

  Widget _tokenDetails(TokenState t) {
    final player = p!;
    final key = 'token.${t.id}';
    final scope = _board.scope(player.id);
    return _list([
      _section(
        t.name,
        detail:
            '${t.amount} total · ${t.tapped} tapped · ${t.summoningSick} summoning sick',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _button(
            'Status',
            () => _go(WorkspacePage.tokenStatus, itemId: t.id),
            icon: Icons.tune,
          ),
          _button(
            'Counters',
            () => _go(WorkspacePage.tokenCounters, itemId: t.id),
            icon: Icons.add_circle_outline,
          ),
          _button(
            'Split',
            () => _go(WorkspacePage.tokenSplit, itemId: t.id),
            icon: Icons.call_split,
          ),
          _button(
            'Artwork',
            () => _go(WorkspacePage.tokenArtwork, itemId: t.id),
            icon: Icons.image_outlined,
          ),
          _button(
            'Copy one',
            () => _run(
              () => _board.copyToken(player.id, t.id),
              closeOnSuccess: true,
            ),
            icon: Icons.copy,
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'These properties also edit directly on the expanded token. Changes save on focus loss, Done, or dismissal.',
      ),
      _gameGrid([
        _input(
          '$key.name',
          'Name',
          initial: t.name,
          onCommit: (v) =>
              _board.editToken(player.id, t.id, name: v, captured: scope),
        ),
        _input(
          '$key.pt',
          'Base power / toughness',
          initial: t.pt,
          onCommit: (v) =>
              _board.editToken(player.id, t.id, pt: v, captured: scope),
        ),
        _input(
          '$key.type',
          'Type',
          initial: t.type,
          onCommit: (v) =>
              _board.editToken(player.id, t.id, type: v, captured: scope),
        ),
        _input(
          '$key.colors',
          'Color identity',
          initial: t.colors,
          onCommit: (v) => _board.editToken(
            player.id,
            t.id,
            colors: v.toUpperCase(),
            captured: scope,
          ),
        ),
      ]),
      _input(
        '$key.abilities',
        'Abilities',
        initial: t.abilities,
        maxLines: 3,
        onCommit: (v) =>
            _board.editToken(player.id, t.id, abilities: v, captured: scope),
      ),
      const SizedBox(height: 20),
      _button(
        'Delete stack',
        () => _confirm(
          'Delete ${t.name}?',
          'Remove this stack of ${t.amount} from $_seatName’s board. Undo is available in game history.',
          () => _board.deleteToken(player.id, t.id),
          button: 'Delete stack',
          closeOnSuccess: true,
        ),
        icon: Icons.delete_outline,
      ),
    ]);
  }
}

part of 'table_workspace.dart';

extension _LibraryPages on _TableWorkspaceState {
  Widget _utilitiesPage() {
    final player = p;
    if (player == null) {
      return _list([const Text('Open utilities from a player’s menu.')]);
    }
    if (_itemId != null) {
      for (final utility in player.utilities) {
        if (utility.id == _itemId) return _utilityDetail(utility);
      }
    }
    final query = _field('utilities.search');
    return _list([
      _section(
        '$_seatName’s utilities',
        detail:
            'Hidden utilities retain their values. Restore them here; hiding is separate from clearing.',
      ),
      for (final utility in player.utilities)
        Card(
          child: ListTile(
            leading: Icon(
              utility.visible
                  ? Icons.dashboard_outlined
                  : Icons.visibility_off_outlined,
            ),
            title: Text(utility.name),
            subtitle: Text(
              utility.kind == 'mana_pool'
                  ? 'Mana total: ${player.mana.values.fold(0, (a, b) => a + b)}${utility.visible ? '' : ' · hidden'}'
                  : '${_board.utilityValue(player.id, utility.id)}${utility.isActive ? ' · active' : ''}${utility.visible ? '' : ' · hidden'}',
            ),
            trailing: IconButton(
              tooltip: utility.visible ? 'Hide utility' : 'Restore utility',
              icon: Icon(
                utility.visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => utility.visible
                  ? _confirm(
                      'Hide ${utility.name}?',
                      'Hide this utility for the current game. Stored values remain available in this menu.',
                      () => _board.setUtility(
                        player.id,
                        utility.id,
                        visible: false,
                      ),
                      button: 'Hide utility',
                    )
                  : _run(
                      () => _board.setUtility(
                        player.id,
                        utility.id,
                        visible: true,
                      ),
                    ),
            ),
            onTap: () => _update(() => _itemId = utility.id),
          ),
        ),
      _section('Add a utility'),
      PlayerField(controller: query, label: 'Search utilities'),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: query,
        builder: (context, value, _) => Column(
          children: [
            for (final definition in _board.utilityDefinitions.where(
              (d) => d.matches(searchQuery: value.text),
            ))
              ListTile(
                title: Text(definition.name),
                subtitle: Text(definition.description),
                trailing: const Icon(Icons.add),
                onTap: () => _run(
                  () => _board.addUtility(player.id, definition.id),
                  success: '${definition.name} added for $_seatName.',
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _utilityDetail(UtilityState utility) {
    final player = p!;
    final key = 'utility.${utility.id}';
    final scope = _board.scope(player.id);
    final revision = c.session.revision;
    final currentValue = _board.utilityValue(player.id, utility.id);
    final toggle = utility.configuration['type'] == 'toggle';
    final active = _board.utilityActive(player.id, utility.id);
    final action =
        utility.configuration['actionType'] as String? ?? utility.kind;
    final hasAction = utility.configuration['hasAction'] == true;
    final actionOnly = utility.configuration['actionOnly'] == true;
    final step = utility.configuration['tapIncrement'] as int? ?? 1;
    final preview = hasAction
        ? _board.utilityPreview(player.id, utility.id)
        : <TokenCreationResult>[];
    if (_field('$key.panel').text == 'artwork') {
      return _utilityArtwork(utility);
    }
    final transforming = hasAction && action == 'brudiclad_telchor_engineer';
    final controls = <Widget>[
      Row(
        children: [
          _button('All utilities', () async {
            if (await _flushInline()) _update(() => _itemId = null);
          }, icon: Icons.arrow_back),
          const Spacer(),
          _button('Artwork', () async {
            if (await _flushInline()) {
              _update(() => _field('$key.panel').text = 'artwork');
            }
          }, icon: Icons.image_outlined),
          const SizedBox(width: 8),
          IconButton(
            tooltip: utility.visible ? 'Hide this utility' : 'Restore to board',
            onPressed: _working
                ? null
                : () => utility.visible
                      ? _confirm(
                          'Hide ${utility.name}?',
                          'The utility’s current values will remain saved. Restore it from the utilities menu.',
                          () => _board.setUtility(
                            player.id,
                            utility.id,
                            visible: false,
                          ),
                          button: 'Hide utility',
                        )
                      : _run(
                          () => _board.setUtility(
                            player.id,
                            utility.id,
                            visible: true,
                          ),
                        ),
            icon: Icon(
              utility.visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ],
      ),
      if (!utility.visible)
        const Text('Hidden from the board. Its values are still saved.'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _input(
              '$key.name',
              'Name',
              initial: utility.name,
              onCommit: (value) => _board.setUtility(
                player.id,
                utility.id,
                name: value.trim(),
                captured: scope,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _input(
              '$key.description',
              'Description',
              initial: utility.description,
              maxLines: 2,
              onCommit: (value) => _board.setUtility(
                player.id,
                utility.id,
                description: value,
                captured: scope,
              ),
            ),
          ),
        ],
      ),
      if (utility.kind == 'mana_pool')
        ..._manaControls(player)
      else if (toggle)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(active ? 'Active' : 'Inactive'),
          subtitle: Text(
            active
                ? utility.description
                : utility.configuration['offDescription'] as String? ?? '',
          ),
          value: active,
          onChanged: (v) =>
              _run(() => _board.setUtility(player.id, utility.id, isActive: v)),
        )
      else if (!actionOnly)
        Row(
          children: [
            Expanded(
              child: _stepper(
                'Value',
                currentValue,
                () => _run(
                  () => _board.adjustUtility(player.id, utility.id, -step),
                ),
                () => _run(
                  () => _board.adjustUtility(player.id, utility.id, step),
                ),
                minimum: utility.kind == 'life_total' ? null : 0,
                holdMinus: () => _run(
                  () => _board.adjustUtility(
                    player.id,
                    utility.id,
                    -(utility.configuration['longPressIncrement'] as int? ??
                        10),
                  ),
                ),
                holdPlus: () => _run(
                  () => _board.adjustUtility(
                    player.id,
                    utility.id,
                    utility.configuration['longPressIncrement'] as int? ?? 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _input(
                '$key.value',
                'Set value',
                initial: '$currentValue',
                numeric: true,
              ),
            ),
            const SizedBox(width: 8),
            _button(
              'Set value',
              () => _run(
                () => _board.setUtility(
                  player.id,
                  utility.id,
                  value: _integer(
                    '$key.value',
                    min: utility.kind == 'life_total' ? -1000000000 : 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      if (hasAction) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: preview.isNotEmpty
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 96),
                  child: SingleChildScrollView(
                    key: const ValueKey('utility-action-preview'),
                    child: Text(TokenCreationResult.breakdownString(preview)),
                  ),
                )
              : Text(
                  action == 'cathars_crusade'
                      ? 'Resolve $currentValue pending creature entries as +1/+1 counters on your creatures, including applicable modifiers.'
                      : 'Apply this utility’s action to $_seatName’s board.',
                ),
        ),
        if (transforming) ...[
          const Text(
            'Choose the token every token will become. This also creates the Myr shown above and clears summoning sickness.',
          ),
          const SizedBox(height: 8),
        ] else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _button(
                utility.configuration['actionButtonText'] as String? ??
                    'Resolve action',
                () => _run(
                  () => _board.utilityAction(
                    player.id,
                    utility.id,
                    expectedRevision: revision,
                    captured: scope,
                  ),
                ),
                primary: true,
              ),
              if (action == 'cathars_crusade')
                _button(
                  'Quick +1/+1 to creatures',
                  () => _run(
                    () => _board.utilityAction(
                      player.id,
                      utility.id,
                      quick: true,
                      captured: scope,
                    ),
                  ),
                ),
            ],
          ),
      ],
    ];
    final targets = transforming
        ? ListView(
            key: const ValueKey('utility-transform-targets'),
            children: [
              for (final token in player.tokens.where(
                (t) => t.amount > 0 && !t.isEmblem,
              ))
                ListTile(
                  title: Text('${token.name} · ${token.pt}'),
                  subtitle: Text(token.abilities, maxLines: 2),
                  trailing: const Icon(Icons.transform),
                  onTap: () => _confirm(
                    'Transform into ${token.name}?',
                    'Create the previewed Myr, then make all your tokens copies of this selected token. Other seats are unaffected.',
                    () => _board.utilityAction(
                      player.id,
                      utility.id,
                      targetTokenId: token.id,
                      expectedRevision: revision,
                      captured: scope,
                    ),
                    button: 'Create & transform',
                  ),
                ),
              for (final result in preview)
                ListTile(
                  title: Text('${result.name} · ${result.pt} (new token)'),
                  trailing: const Icon(Icons.transform),
                  onTap: () => _confirm(
                    'Transform into ${result.name}?',
                    'Create the Myr and transform every token you control into this token.',
                    () => _board.utilityAction(
                      player.id,
                      utility.id,
                      targetTokenId: result.compositeId,
                      expectedRevision: revision,
                      captured: scope,
                    ),
                    button: 'Create & transform',
                  ),
                ),
            ],
          )
        : null;
    return Padding(
      key: ValueKey('utility-detail-${utility.kind}'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: transforming
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...controls,
                Expanded(child: targets!),
                _button(
                  'Create Myr & skip transformation',
                  () => _run(
                    () => _board.utilityAction(
                      player.id,
                      utility.id,
                      skip: true,
                      expectedRevision: revision,
                      captured: scope,
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              key: const ValueKey('utility-fixed-controls'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: controls,
              ),
            ),
    );
  }

  Widget _utilityArtwork(UtilityState utility) {
    final player = p!;
    final scope = _board.scope(player.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _button(
                'Utility controls',
                () => _update(
                  () => _field('utility.${utility.id}.panel').clear(),
                ),
                icon: Icons.arrow_back,
              ),
              _button(
                'Upload utility artwork',
                () => _run(() async {
                  final art = await _pickArtwork();
                  if (art != null) {
                    await _board.setUtility(
                      player.id,
                      utility.id,
                      artworkUrl: art,
                      captured: scope,
                    );
                  }
                }),
                icon: Icons.upload,
              ),
              if (utility.artworkUrl != null)
                _button(
                  'Remove artwork',
                  () => _run(
                    () => _board.setUtility(
                      player.id,
                      utility.id,
                      clearArtwork: true,
                      captured: scope,
                    ),
                  ),
                  icon: Icons.hide_image_outlined,
                ),
            ],
          ),
        ),
        Expanded(
          child: _list([
            _section('Artwork for ${utility.name}'),
            if (utility.artworkUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: _art(utility.artworkUrl, width: 180, height: 140),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final raw
                    in utility.configuration['artworkOptions'] as List? ?? [])
                  SizedBox(
                    width: 150,
                    child: InkWell(
                      onTap: () => _run(
                        () => _board.setUtility(
                          player.id,
                          utility.id,
                          artworkUrl: raw['url'] as String?,
                          captured: scope,
                        ),
                      ),
                      child: Column(
                        children: [
                          _art(raw['url'] as String?, width: 150, height: 130),
                          Text(
                            '${raw['set'] ?? ''}\n${raw['artist'] ?? ''}',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ],
    );
  }

  List<Widget> _manaControls(PlayerState player) => [
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'Tap ± for one; hold for ten. Locks protect against Empty only. Conversion moves all mana, including locked colors.',
      ),
    ),
    LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
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
      alignment: Alignment.centerRight,
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
    return Card(
      key: ValueKey('utility-mana-$color'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            HalfStepper(
              height: 48,
              label: '$name mana',
              value: '${player.mana[color] ?? 0}',
              decreaseLabel: 'Decrease $name mana',
              increaseLabel: 'Increase $name mana',
              onDecrease: _working || (player.mana[color] ?? 0) == 0
                  ? null
                  : () => _run(() => c.adjustMana(player.id, color, -1)),
              onIncrease: _working
                  ? null
                  : () => _run(() => c.adjustMana(player.id, color, 1)),
              onDecreaseHold: () =>
                  _run(() => c.adjustMana(player.id, color, -10)),
              onIncreaseHold: () =>
                  _run(() => c.adjustMana(player.id, color, 10)),
              holdRepeatInterval: null,
              valueWidget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: Theme.of(context).textTheme.labelMedium),
                  Text(
                    '${player.mana[color] ?? 0}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: HalfStepper(
                    height: 48,
                    label: '$name mana by ten',
                    value: '10',
                    decreaseLabel: 'Decrease $name mana by ten',
                    increaseLabel: 'Increase $name mana by ten',
                    onDecrease: _working || (player.mana[color] ?? 0) == 0
                        ? null
                        : () => _run(() => c.adjustMana(player.id, color, -10)),
                    onIncrease: _working
                        ? null
                        : () => _run(() => c.adjustMana(player.id, color, 10)),
                    valueStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: '${locked ? 'Unlock' : 'Lock'} $name mana for Empty',
                  isSelected: locked,
                  onPressed: _working
                      ? null
                      : () => _run(() => c.toggleManaLock(player.id, color)),
                  icon: const Icon(Icons.lock_open),
                  selectedIcon: const Icon(Icons.lock),
                ),
                IconButton(
                  tooltip: 'Convert all mana to $name',
                  onPressed: _working
                      ? null
                      : () => _run(() => c.convertMana(player.id, color)),
                  icon: const Icon(Icons.compare_arrows),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulesPage() {
    final player = p;
    if (player == null) {
      return _list([const Text('Open Rules from a player’s menu.')]);
    }
    final foreign = _board
        .effectiveSources(player.id)
        .where((s) => s.ownerPlayerId != player.id && s.enabled && s.count > 0)
        .toList();
    return _list([
      _section(
        'Your modifier sources',
        detail:
            'Each source belongs to $_seatName. Primal Vigor affects every player; other preset modifiers affect their owner.',
      ),
      for (final entry in BoardService.modifierDefinitions.entries)
        Builder(
          builder: (context) {
            ModifierSource? source;
            for (final rule in player.rules) {
              if (rule.definitionId == entry.key) source = rule;
            }
            final count = source?.count ?? 0;
            return _stepper(
              entry.value,
              count,
              () => _run(
                () =>
                    _board.setModifier(player.id, entry.key, max(0, count - 1)),
              ),
              () => _run(
                () => _board.setModifier(player.id, entry.key, count + 1),
              ),
              detail: entry.key == 'primal_vigor'
                  ? 'Global · applies to the entire table'
                  : 'Owned by $_seatName',
            );
          },
        ),
      _section('Custom rules'),
      for (final source in player.rules.where(
        (s) => s.definitionId == 'custom',
      ))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(source.name),
                  subtitle: Text(
                    source.global
                        ? 'Global source · affects all players'
                        : 'Applies only to $_seatName',
                  ),
                  value: source.enabled,
                  onChanged: (v) => _run(
                    () => _board.setSource(player.id, source.id, enabled: v),
                  ),
                ),
                _stepper(
                  'Copies',
                  source.count,
                  () => _run(
                    () => _board.setSource(
                      player.id,
                      source.id,
                      count: max(0, source.count - 1),
                    ),
                  ),
                  () => _run(
                    () => _board.setSource(
                      player.id,
                      source.id,
                      count: source.count + 1,
                    ),
                  ),
                ),
                _button(
                  'Edit rule',
                  () => _editRule(source),
                  icon: Icons.edit_outlined,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _button(
                      'Move earlier',
                      () =>
                          _run(() => _board.moveRule(player.id, source.id, -1)),
                      icon: Icons.arrow_upward,
                    ),
                    _button(
                      'Move later',
                      () =>
                          _run(() => _board.moveRule(player.id, source.id, 1)),
                      icon: Icons.arrow_downward,
                    ),
                  ],
                ),
                _button(
                  'Remove rule definition',
                  () => _confirm(
                    'Remove ${source.name}?',
                    'Delete this owned source and its effect for every affected player. This is undoable in game history.',
                    () => _board.removeModifier(player.id, source.id),
                  ),
                  icon: Icons.delete_outline,
                ),
              ],
            ),
          ),
        ),
      ExpansionTile(
        key: ValueKey('custom-rule-$_editingRuleId'),
        initiallyExpanded: _editingRuleId != null,
        title: Text(
          _editingRuleId == null ? 'Create a custom rule' : 'Edit custom rule',
        ),
        children: [
          _input('rule.name', 'Rule name'),
          _section('When creating'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in {
                'all': 'Any token',
                'creatures': 'Has P/T',
                'type': 'Token type',
                'color': 'Color',
                'specific': 'Specific token',
              }.entries)
                ChoiceChip(
                  label: Text(choice.value),
                  selected: _customTrigger == choice.key,
                  onSelected: (_) => _update(() => _customTrigger = choice.key),
                ),
            ],
          ),
          if (_customTrigger == 'specific') ...[
            _input('rule.triggerSearch', 'Find the triggering token'),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _field('rule.triggerSearch'),
              builder: (context, value, _) => Column(
                children: [
                  for (final token in catalog.search(value.text).take(12))
                    CheckboxListTile(
                      title: Text('${token.name} ${token.pt}'),
                      subtitle: Text(token.cleanType),
                      value: _field('rule.triggerId').text == token.id,
                      onChanged: (_) => _update(
                        () => _field('rule.triggerId').text = token.id,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_customTrigger == 'type' || _customTrigger == 'color')
            _input(
              'rule.triggerValue',
              _customTrigger == 'type'
                  ? 'Token type contains'
                  : 'Color W, U, B, R, or G',
            ),
          _section('Outcome'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in {
                'multiply': 'Multiply quantity',
                'also_create': 'Also create a token',
                'replace': 'Replace with a token',
              }.entries)
                ChoiceChip(
                  label: Text(choice.value),
                  selected: _customEffect == choice.key,
                  onSelected: (_) => _update(() => _customEffect = choice.key),
                ),
            ],
          ),
          if (_customEffect == 'multiply')
            _input('rule.multiplier', 'Multiplier', initial: '2', numeric: true)
          else ...[
            _input('rule.resultSearch', 'Find resulting token'),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _field('rule.resultSearch'),
              builder: (context, value, _) => Column(
                children: [
                  for (final token in catalog.search(value.text).take(12))
                    CheckboxListTile(
                      title: Text('${token.name} ${token.pt}'),
                      subtitle: Text(token.cleanType),
                      value: _field('rule.targetId').text == token.id,
                      onChanged: (_) => _update(
                        () => _field('rule.targetId').text = token.id,
                      ),
                    ),
                ],
              ),
            ),
            if (_customEffect == 'also_create')
              _input(
                'rule.extra',
                'Companion tokens per token created',
                initial: '1',
                numeric: true,
              ),
          ],
          _button(
            'Add outcome to rule',
            () => _run(() async {
              final outcome = _ruleOutcome();
              _update(() => _customRuleOutcomes.add(outcome));
            }, success: 'Outcome added. Save the rule to apply it.'),
            icon: Icons.add,
          ),
          for (var index = 0; index < _customRuleOutcomes.length; index++)
            ListTile(
              title: Text(_outcomeLabel(_customRuleOutcomes[index])),
              trailing: IconButton(
                tooltip: 'Remove outcome',
                onPressed: () =>
                    _update(() => _customRuleOutcomes.removeAt(index)),
                icon: const Icon(Icons.close),
              ),
            ),
          SwitchListTile(
            title: const Text('Global applicability'),
            subtitle: const Text(
              'This source affects every player while enabled.',
            ),
            value: _customGlobal,
            onChanged: (value) => _update(() => _customGlobal = value),
          ),
          _button(
            'Save custom rule',
            () => _run(
              () async {
                final name = _field('rule.name').text.trim();
                if (name.isEmpty) {
                  throw const FormatException('Enter a rule name.');
                }
                if (_customRuleOutcomes.isEmpty &&
                    _customEffect != 'multiply' &&
                    _field('rule.targetId').text.isEmpty) {
                  throw const FormatException('Select the resulting token.');
                }
                final trigger = {
                  'all': 'any_token',
                  'creatures': 'has_pt',
                  'type': 'token_type',
                  'color': 'color',
                  'specific': 'specific_token',
                }[_customTrigger]!;
                await _board.saveCustomRule(player.id, {
                  if (_editingRuleId != null) 'id': _editingRuleId,
                  if (_customTrigger == 'specific')
                    'targetTokenId': _field('rule.triggerId').text,
                  'name': name,
                  'count': _editingRuleId == null ? 1 : _editingRuleCount,
                  'global': _customGlobal,
                  'enabled': _editingRuleId == null
                      ? true
                      : _editingRuleEnabled,
                  'triggerType': trigger,
                  if (_customTrigger == 'type')
                    'targetType': _field('rule.triggerValue').text.trim(),
                  if (_customTrigger == 'color')
                    'targetColor': _field(
                      'rule.triggerValue',
                    ).text.trim().toUpperCase(),
                  'outcomes': _customRuleOutcomes.isEmpty
                      ? [_ruleOutcome()]
                      : List<Map<String, dynamic>>.from(_customRuleOutcomes),
                });
              },
              success: 'Custom rule saved.',
              after: () {
                _editingRuleId = null;
                _customRuleOutcomes.clear();
              },
            ),
            primary: true,
          ),
          if (_editingRuleId != null)
            _button(
              'Cancel rule edit',
              () => _update(() {
                _editingRuleId = null;
                _customRuleOutcomes.clear();
              }),
              icon: Icons.close,
            ),
        ],
      ),
      _section(
        'Other players’ global effects',
        detail:
            'These sources apply to $_seatName and remain owned by their originating player. Change them in that player’s Rules panel.',
      ),
      if (foreign.isEmpty)
        const Text('No active global effects from another player.'),
      for (final source in foreign)
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text('${source.name} ×${source.count}'),
            subtitle: Text(
              'Source: ${_nameForPlayer(source.ownerPlayerId)} · read only here',
            ),
          ),
        ),
    ]);
  }

  Map<String, dynamic> _ruleOutcome() {
    if (_customEffect != 'multiply' && _field('rule.targetId').text.isEmpty) {
      throw const FormatException('Select the resulting token.');
    }
    return {
      'outcomeType': _customEffect,
      if (_customEffect == 'multiply')
        'multiplier': _integer('rule.multiplier', min: 1, max: 1024),
      if (_customEffect != 'multiply')
        'targetTokenId': _field('rule.targetId').text,
      if (_customEffect == 'also_create')
        'quantity': _integer('rule.extra', min: 1, max: 999999),
    };
  }

  String _outcomeLabel(Map<String, dynamic> outcome) {
    if (outcome['outcomeType'] == 'multiply') {
      return 'Multiply by ${outcome['multiplier']}';
    }
    final name =
        catalog.byId(outcome['targetTokenId'] as String? ?? '')?.name ??
        'Selected token';
    return outcome['outcomeType'] == 'replace'
        ? 'Replace with $name'
        : 'Also create ${outcome['quantity']} $name';
  }

  void _editRule(ModifierSource source) => _update(() {
    _editingRuleId = source.id;
    _editingRuleCount = source.count;
    _editingRuleEnabled = source.enabled;
    _field('rule.name').text = source.name;
    _customGlobal = source.global;
    _customTrigger =
        {
          'any_token': 'all',
          'has_pt': 'creatures',
          'token_type': 'type',
          'color': 'color',
          'specific_token': 'specific',
        }[source.configuration['triggerType']] ??
        'all';
    _field('rule.triggerValue').text =
        (source.configuration['targetType'] ??
                source.configuration['targetColor'] ??
                '')
            .toString();
    _field('rule.triggerId').text =
        (source.configuration['targetTokenId'] ?? '').toString();
    _customRuleOutcomes.clear();
    for (final raw in source.configuration['outcomes'] as List? ?? []) {
      _customRuleOutcomes.add(Map<String, dynamic>.from(raw as Map));
    }
  });

  Widget _presetsPage() {
    final player = p;
    if (player == null) {
      return _list([
        const Text(
          'Open Saved setups from the player who will load the setup.',
        ),
      ]);
    }
    return _list([
      _section(
        'Saved setups for $_seatName',
        detail:
            'A setup contains zero-state tokens, utility configuration and artwork. Loading preserves life, damage, player counters and the game timeline.',
      ),
      _input('preset.name', 'Name for the current setup'),
      _button(
        'Save this player’s setup',
        () => _run(
          () => _presets.save(
            player.id,
            _field('preset.name').text.trim(),
            imageUrl: c.profile(player.seatId).artworkUrl,
          ),
          success: 'Setup saved to the library.',
        ),
        icon: Icons.save_outlined,
        primary: true,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Apply saved setup image to life tracker when loading',
        ),
        subtitle: const Text(
          'Only this player’s saved appearance changes; their name and life value remain.',
        ),
        value: _applyPresetImage,
        onChanged: (v) => _update(() => _applyPresetImage = v),
      ),
      if (_presets.presets.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No saved setups yet. Save the current board or import a Tripling Season setup.',
          ),
        ),
      for (final preset in _presets.presets) _presetCard(preset, player),
      _section('Import a setup or decklist'),
      _button(
        'Choose a JSON or text file',
        () => _run(() async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['json', 'txt', 'dec', 'dek'],
            withData: true,
          );
          if (result == null || !mounted || !_validScope) return;
          final bytes = result.files.single.bytes;
          if (bytes == null) throw StateError('The file could not be read.');
          _field('preset.import').text = utf8.decode(bytes);
          _status = 'File loaded. Review and choose the import type below.';
        }),
        icon: Icons.file_open_outlined,
      ),
      _input(
        'preset.import',
        'Paste Tripling Season setup JSON or a card decklist',
        maxLines: 6,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _button(
            'Import setup JSON',
            () => _run(
              () => _presets.importJson(_field('preset.import').text),
              success: 'Setup imported. Select Replace or Append to load it.',
            ),
          ),
          _button(
            'Find tokens from decklist',
            () => _run(
              () => _presets.importDecklist(
                _field('preset.import').text,
                name: _field('preset.name').text.trim().isEmpty
                    ? null
                    : _field('preset.name').text.trim(),
              ),
              success: 'Matching token setup imported. Review before loading.',
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _presetCard(Map<String, dynamic> preset, PlayerState player) {
    final id = preset['id'] as String;
    final name = preset['name'] as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (preset['imageUrl'] != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _art(
                      preset['imageUrl'] as String?,
                      width: 64,
                      height: 64,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${(preset['tokens'] as List? ?? []).length} token entries · ${(preset['utilities'] as List? ?? []).length} utilities',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            for (final warning in preset['warnings'] as List? ?? [])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Artwork notice: $warning',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button('Replace board', () {
                  final scope = _board.scope(player.id);
                  _confirm(
                    'Replace $_seatName’s setup?',
                    'Replace this player’s token and utility setup with $name. Tokens start at zero. Life, commander damage, player counters, modifier sources and the existing timeline remain. This is one undoable action.',
                    () => _presets.load(
                      player.id,
                      id,
                      applyImage: _applyPresetImage,
                      captured: scope,
                    ),
                    button: 'Replace setup',
                  );
                }),
                _button(
                  'Append',
                  () => _run(
                    () => _presets.load(
                      player.id,
                      id,
                      append: true,
                      applyImage: _applyPresetImage,
                      captured: _board.scope(player.id),
                    ),
                    success: '$name appended to $_seatName’s board.',
                  ),
                ),
                _button(
                  'Export tablet',
                  () => _exportPreset(id, name, false),
                  icon: Icons.ios_share,
                ),
                _button(
                  'Export phone v3',
                  () => _exportPreset(id, name, true),
                  icon: Icons.phone_android,
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Preview & manage'),
              children: [
                for (final token in preset['tokens'] as List? ?? [])
                  ListTile(
                    dense: true,
                    title: Text('${token['name']} ${token['pt'] ?? ''}'),
                    subtitle: Text(token['type'] as String? ?? ''),
                  ),
                for (final utility in preset['utilities'] as List? ?? [])
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.dashboard_outlined),
                    title: Text(utility['name'] as String),
                  ),
                _input(
                  'preset.$id.name',
                  'Setup name',
                  initial: name,
                  live: true,
                  helper: 'Valid name changes save as you type.',
                  onCommit: (value) => _presets.rename(id, value.trim()),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _button(
                      'Delete from library',
                      () => _confirm(
                        'Delete $name?',
                        'Delete this reusable setup from the library. Existing boards and archives are unaffected. This library deletion cannot be undone in game history.',
                        () => _presets.delete(id),
                        button: 'Delete setup',
                      ),
                      icon: Icons.delete_outline,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportPreset(String id, String name, bool phoneCompatible) {
    final warnings = _presets.exportWarnings(
      id,
      phoneCompatible: phoneCompatible,
    );
    Future<void> export() async {
      final json = await _presets.exportJson(
        id,
        phoneCompatible: phoneCompatible,
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Export setup',
        fileName:
            '${name.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')}${phoneCompatible ? '-phone-v3' : ''}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
    }

    if (warnings.isNotEmpty) {
      _confirm(
        'Export compatibility',
        warnings.join('\n\n'),
        export,
        button: 'Export with these limitations',
      );
    } else {
      _run(export, success: 'Setup export completed.');
    }
  }
}

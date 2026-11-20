part of 'table_workspace.dart';

// Deferred authoring must stay unreachable, including recovered editor drafts.
const _customRuleAuthoringEnabled = false;

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
    final legacy = player.utilities
        .where((utility) => !_board.isStandaloneUtilityKind(utility.kind))
        .toList();
    final definitions = {
      for (final definition in _board.utilityDefinitions)
        definition.id: definition,
    };
    final standalone = player.utilities
        .where((utility) => _board.isStandaloneUtilityKind(utility.kind))
        .toList();
    final existingKinds = standalone.map((utility) => utility.kind).toSet();
    final choices =
        <_UtilityChoice>[
          for (final utility in standalone)
            _UtilityChoice(
              utility: utility,
              definition: definitions[utility.kind],
            ),
          for (final definition in definitions.values)
            if (!existingKinds.contains(definition.id))
              _UtilityChoice(definition: definition),
        ]..sort((a, b) {
          final name = a.sortName.compareTo(b.sortName);
          return name != 0 ? name : a.id.compareTo(b.id);
        });
    final scope = _board.scope(player.id);
    final query = _field('utilities.search');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _contentTop(
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Utilities · $_seatName',
                key: const ValueKey('utility-picker-heading'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: _workspaceSearchField(
            key: const ValueKey('utility-picker-search'),
            query: query,
            label: 'Search utilities',
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: query,
            builder: (context, value, _) {
              final matching = choices.where(
                (choice) => choice.matches(value.text),
              );
              return _list(
                [
                  for (final choice in matching)
                    _utilityChoiceRow(player, choice, scope),
                  if (matching.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text('No utilities match your search.'),
                          TextButton(
                            onPressed: query.clear,
                            child: const Text('Clear search'),
                          ),
                        ],
                      ),
                    ),
                  if (legacy.isNotEmpty && value.text.trim().isEmpty)
                    ExpansionTile(
                      key: const PageStorageKey('legacy-utility-settings'),
                      title: const Text('Legacy settings'),
                      leading: const Icon(Icons.inventory_2_outlined, size: 20),
                      children: [
                        for (final utility in legacy)
                          ListTile(
                            key: ValueKey('legacy-settings-${utility.id}'),
                            title: Text(utility.name),
                            onTap: () => _go(
                              WorkspacePage.utilities,
                              itemId: utility.id,
                            ),
                          ),
                      ],
                    ),
                ],
                controls: false,
                controller: _playerScroll,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _utilityChoiceRow(
    PlayerState player,
    _UtilityChoice choice,
    BoardScope scope,
  ) {
    final canInteract = !_working && !_navigating && !_closing;
    return Row(
      key: choice.utility == null
          ? ValueKey('utility-choice-${choice.id}')
          : ValueKey('utility-menu-${choice.utility!.id}'),
      children: [
        Expanded(
          child: ListTile(
            key: ValueKey('utility-open-${choice.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(choice.name),
            subtitle: choice.description.isEmpty
                ? null
                : ManaText(choice.description),
            onTap: canInteract
                ? () => _openUtilityChoice(player, choice, scope)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Show ${choice.name} on board',
          child: Switch(
            key: ValueKey('utility-toggle-${choice.id}'),
            value: choice.visible,
            onChanged: !canInteract
                ? null
                : (visible) => _run(() {
                    final utility = choice.utility;
                    return utility == null
                        ? _board.addUtility(
                            player.id,
                            choice.id,
                            captured: scope,
                          )
                        : _board.setUtility(
                            player.id,
                            utility.id,
                            visible: visible,
                            captured: scope,
                          );
                  }),
          ),
        ),
      ],
    );
  }

  Future<void> _openUtilityChoice(
    PlayerState player,
    _UtilityChoice choice,
    BoardScope scope,
  ) async {
    var id = choice.utility?.id;
    if (id == null) {
      await _run(() async {
        await _board.addUtility(
          player.id,
          choice.id,
          visible: false,
          captured: scope,
        );
        id = c
            .player(player.id)
            .utilities
            .firstWhere((utility) => utility.kind == choice.id)
            .id;
      });
    }
    if (id != null && mounted && _validScope) {
      await _go(WorkspacePage.utilities, itemId: id);
    }
  }

  Future<void> _returnFromUtility(UtilityState utility) async {
    if (_working || _closing || _navigating) return;
    final panel = _field('utility.${utility.id}.panel');
    if (panel.text == 'artwork') {
      _update(panel.clear);
    } else if (_utilityPickerIsParent) {
      await _back();
    } else {
      await _directQueue;
      if (await _flushInline() && mounted && !_closing) {
        _update(() {
          _utilityTransformDraft = null;
          _itemId = null;
        });
      }
    }
  }

  // The title centers against the whole frame, not the leftover space after
  // a wide Back label. On narrow/large-type surfaces the title gets its own row.
  Widget _utilityNavigationBar(UtilityState utility) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
    child: LayoutBuilder(
      builder: (context, box) {
        final artwork = _field('utility.${utility.id}.panel').text == 'artwork';
        final caption = artwork ? 'Utility controls' : 'Utilities';
        final scale = MediaQuery.textScalerOf(context);
        final compactMana =
            utility.kind == 'mana_pool' &&
            !artwork &&
            box.maxWidth < scale.scale(400);
        final canNavigate = !_working && !_closing && !_navigating;
        final back = compactMana
            ? IconButton(
                key: const ValueKey('utility-back'),
                tooltip: caption,
                onPressed: canNavigate
                    ? () => _returnFromUtility(utility)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              )
            : TextButton.icon(
                key: const ValueKey('utility-back'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: canNavigate
                    ? () => _returnFromUtility(utility)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                label: Text(caption),
              );
        final close = MergeSemantics(
          child: Semantics(
            label: 'Close workspace',
            child: IconButton(
              onPressed: _working || _closing || _navigating
                  ? null
                  : _requestClose,
              icon: const Icon(Icons.close),
            ),
          ),
        );
        final title = Semantics(
          header: true,
          child: Text(
            artwork ? 'Artwork for ${utility.name}' : utility.name,
            key: const ValueKey('utility-panel-title'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        final side = compactMana
            ? 48.0
            : (artwork ? 68.0 : 44.0) + scale.scale(artwork ? 84 : 70);
        if (box.maxWidth - 2 * side < scale.scale(compactMana ? 100 : 150)) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Align(alignment: Alignment.centerLeft, child: back),
                  ),
                  close,
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: title,
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: side,
              child: Align(alignment: Alignment.centerLeft, child: back),
            ),
            Expanded(child: title),
            SizedBox(
              width: side,
              child: Align(alignment: Alignment.centerRight, child: close),
            ),
          ],
        );
      },
    ),
  );

  Widget _utilityInfo(UtilityState utility, WidgetDefinition? definition) {
    final custom =
        utility.kind == 'custom_tracker' || utility.kind == 'custom_toggle';
    final key = 'utility.${utility.id}';
    final scope = _board.scope(p!.id);
    final suppliedDescription = utility.description.trim().isNotEmpty
        ? utility.description.trim()
        : definition?.description ?? '';
    final description =
        suppliedDescription.isEmpty && utility.kind == 'storm_count'
        ? 'Count spells cast this turn, including spells cast by other players.'
        : suppliedDescription;
    if (!custom && description.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: custom
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _input(
                    '$key.name',
                    'Name',
                    initial: utility.name,
                    onCommit: (value) => _board.setUtility(
                      scope.playerId,
                      utility.id,
                      name: value.trim(),
                      captured: scope,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _input(
                    '$key.description',
                    'Description',
                    initial: utility.description,
                    maxLines: 2,
                    onCommit: (value) => _board.setUtility(
                      scope.playerId,
                      utility.id,
                      description: value,
                      captured: scope,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ManaText(
                  description,
                  textAlign:
                      description.length < 90 && !description.contains('\n')
                      ? TextAlign.center
                      : TextAlign.start,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
    );
  }

  Widget _utilityArtFooter(
    UtilityState utility,
    WidgetDefinition? definition, {
    bool compact = false,
  }) {
    final url = utility.displayedArtworkUrl;
    final saved = (utility.configuration['artworkOptions'] as List? ?? [])
        .whereType<Map>()
        .where((art) => art['url'] == url)
        .firstOrNull;
    final savedArtist = (saved?['artist'] as String?)?.trim() ?? '';
    final artist = savedArtist.isNotEmpty
        ? savedArtist
        : definition?.artwork.where((a) => a.url == url).firstOrNull?.artist;
    Future<void> edit() async {
      await _directQueue;
      if (await _flushInline() && mounted && !_closing) {
        _update(() => _field('utility.${utility.id}.panel').text = 'artwork');
      }
    }

    if (compact) {
      final credit = tabletArtworkArtist(url, artist);
      return Row(
        children: [
          IconButton(
            key: const ValueKey('utility-edit-artwork'),
            tooltip: url == null ? 'Add artwork' : 'Edit artwork',
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
            ),
            onPressed: _working ? null : edit,
            icon: url == null
                ? const Icon(Icons.add_photo_alternate_outlined)
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _art(url, width: 36, height: 28),
                      ),
                      PositionedDirectional(
                        end: -3,
                        bottom: -3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(Icons.edit_outlined, size: 13),
                        ),
                      ),
                    ],
                  ),
          ),
          if (url != null)
            Flexible(
              child: Text(
                credit,
                semanticsLabel: credit == 'Artist unknown'
                    ? credit
                    : 'Artist $credit',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: url == null
                  ? TextButton.icon(
                      key: const ValueKey('utility-edit-artwork'),
                      onPressed: _working ? null : edit,
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                      ),
                      label: const Text('Add artwork'),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _art(url, width: 76, height: 48),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TabletArtworkCredit(url: url, artist: artist),
                            IconButton(
                              key: const ValueKey('utility-edit-artwork'),
                              tooltip: 'Edit artwork',
                              onPressed: _working ? null : edit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _utilityExactValue(UtilityState utility, BoardScope scope) =>
      TextFieldTapRegion(
        // Opening exact entry must not finish an unrelated inline text draft.
        child: _button('Set value', () async {
          if (_utilityExactOpen || _working || _closing || _navigating) return;
          _update(() => _utilityExactOpen = true);
          try {
            await _directQueue;
            if (!mounted ||
                _closing ||
                !_validScope ||
                p?.generation != scope.playerGeneration ||
                p?.utilities.any((entry) => entry.id == utility.id) != true) {
              return;
            }
            final quarterTurns = widget.quarterTurns;
            final current = _board.utilityValue(scope.playerId, utility.id);
            await showDialog<void>(
              context: context,
              useSafeArea: false,
              barrierColor: Colors.black.withValues(alpha: .36),
              builder: (_) => _UtilityExactDialog(
                quarterTurns: quarterTurns,
                current: current,
                onApply: (value) => _board.setUtility(
                  scope.playerId,
                  utility.id,
                  value: value,
                  captured: scope,
                ),
              ),
            );
          } finally {
            if (mounted) _update(() => _utilityExactOpen = false);
          }
        }, icon: Icons.dialpad),
      );

  Widget _utilityDetail(UtilityState utility) {
    final definition = _board.utilityDefinitions
        .where((d) => d.id == utility.kind)
        .firstOrNull;
    if (utility.kind == RingService.kind &&
        _field('utility.${utility.id}.panel').text != 'artwork') {
      return _ringDetail(utility, definition);
    }
    final player = p!;
    final key = 'utility.${utility.id}';
    if (_field('$key.panel').text == 'artwork') {
      return _utilityArtwork(utility);
    }
    if (utility.kind == 'mana_pool') {
      return _compactManaPool(utility, definition, player);
    }
    final scope = _board.scope(player.id);
    final revision = c.session.revision;
    final currentValue = _board.utilityValue(player.id, utility.id);
    final standalone = _board.isStandaloneUtilityKind(utility.kind);
    final toggle = utility.configuration['type'] == null
        ? definition?.type == WidgetType.toggle ||
              utility.kind == 'custom_toggle'
        : utility.configuration['type'] == 'toggle';
    final active = _board.utilityActive(player.id, utility.id);
    final action =
        utility.configuration['actionType'] as String? ??
        definition?.actionType ??
        utility.kind;
    final hasAction =
        utility.configuration['hasAction'] as bool? ??
        definition?.hasAction ??
        false;
    final actionOnly =
        utility.configuration['actionOnly'] as bool? ??
        definition?.actionOnly ??
        false;
    final step =
        utility.configuration['tapIncrement'] as int? ??
        definition?.tapIncrement ??
        1;
    final preview = standalone && hasAction
        ? _board.utilityPreview(player.id, utility.id)
        : <TokenCreationResult>[];
    final transforming =
        standalone && hasAction && action == 'brudiclad_telchor_engineer';
    final controls = <Widget>[
      _utilityInfo(utility, definition),
      if (standalone && hasAction) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: preview.isNotEmpty
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 96),
                  child: SingleChildScrollView(
                    key: const ValueKey('utility-action-preview'),
                    child: Center(
                      child: Text(TokenCreationResult.breakdownString(preview)),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    action == 'cathars_crusade'
                        ? 'Resolve $currentValue pending creature entries as +1/+1 counters on your creatures, including applicable modifiers.'
                        : 'Apply this utility’s action to $_seatName’s board.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
        if (transforming) ...[
          const Text(
            'Choose a token to copy, then select Create & transform. This creates the tokens shown above and clears summoning sickness from the copies.',
          ),
          const SizedBox(height: 8),
        ],
      ],
      if (standalone && toggle)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(active ? 'Active' : 'Inactive'),
          subtitle:
              !active &&
                  (utility.configuration['offDescription'] as String? ?? '')
                      .isNotEmpty
              ? Text(utility.configuration['offDescription'] as String)
              : null,
          value: active,
          onChanged: (v) => _run(
            () => _board.setUtility(
              player.id,
              utility.id,
              isActive: v,
              captured: scope,
            ),
          ),
        )
      else if (standalone && !actionOnly)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: _stepper(
                'Value',
                currentValue,
                () => _runDirect(
                  () => _board.adjustUtility(player.id, utility.id, -step),
                ),
                () => _runDirect(
                  () => _board.adjustUtility(player.id, utility.id, step),
                ),
                minimum: utility.kind == 'life_total' ? null : 0,
                holdMinus: utility.legacySingleStepHold
                    ? () => _runDirect(
                        () => _board.adjustUtility(
                          player.id,
                          utility.id,
                          -utility.legacyHoldIncrement,
                        ),
                      )
                    : null,
                holdPlus: utility.legacySingleStepHold
                    ? () => _runDirect(
                        () => _board.adjustUtility(
                          player.id,
                          utility.id,
                          utility.legacyHoldIncrement,
                        ),
                      )
                    : null,
                holdMinusStep: utility.legacySingleStepHold
                    ? null
                    : (amount) => _runDirect(
                        () => _board.adjustUtility(
                          player.id,
                          utility.id,
                          -amount,
                        ),
                      ),
                holdPlusStep: utility.legacySingleStepHold
                    ? null
                    : (amount) => _runDirect(
                        () =>
                            _board.adjustUtility(player.id, utility.id, amount),
                      ),
              ),
            ),
            if (utility.kind != 'storm_count')
              _utilityExactValue(utility, scope),
          ],
        ),
      if (standalone && hasAction && !transforming)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _button(
              action == 'the_unbeatable_squirrel_girl'
                  ? 'Make Squirrels'
                  : utility.configuration['actionButtonText'] as String? ??
                        definition?.actionButtonText ??
                        'Resolve action',
              () => _run(
                () => _board.utilityAction(
                  player.id,
                  utility.id,
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
    ];
    return SingleChildScrollView(
      key: const ValueKey('utility-fixed-controls'),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Column(
        key: ValueKey('utility-detail-${utility.kind}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...controls,
          if (transforming)
            ..._brudicladControls(utility, player, scope, revision, preview),
          _utilityArtFooter(utility, definition),
        ],
      ),
    );
  }

  List<Widget> _brudicladControls(
    UtilityState utility,
    PlayerState player,
    BoardScope scope,
    int revision,
    List<TokenCreationResult> preview,
  ) {
    final existing = player.tokens
        .where((token) => token.amount > 0 && !token.isEmblem)
        .toList();
    final created = TokenCreationResult.aggregateForDisplay(
      preview,
    ).where((result) => result.quantity > 0).toList();
    final draft = _utilityTransformDraft;
    final isOwnDraft = draft != null && draft.$1 == utility.id;
    final candidate = isOwnDraft ? draft.$2 : null;
    final eligible =
        candidate != null &&
        (existing.any((t) => t.id == candidate) ||
            created.any((r) => r.compositeId == candidate));
    final selected = isOwnDraft && draft.$3 == revision && eligible
        ? candidate
        : null;
    bool isSelected(String target) => selected == target;
    void choose(String id) => _update(() {
      _utilityTransformDraft = selected == id
          ? null
          : (utility.id, id, revision);
    });
    void clear() => _utilityTransformDraft = null;
    final enabled = !_working && !_closing && !_navigating;
    final entries = [
      for (final token in existing)
        _tokenIdentityTile(
          key: ValueKey('utility-transform-existing-${token.id}'),
          name: token.name,
          pt: token.pt,
          type: token.type,
          abilities: token.abilities,
          artwork: token.artworkUrl,
          trailing: Icon(
            isSelected(token.id)
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
          ),
          selected: isSelected(token.id),
          onTap: enabled ? () => choose(token.id) : null,
        ),
      for (final result in created)
        _tokenIdentityTile(
          key: ValueKey('utility-transform-preview-${result.compositeId}'),
          name: result.name,
          pt: result.pt,
          type: result.type,
          abilities: result.abilities,
          artwork: catalog
              .byId(result.tokenDatabaseId ?? result.compositeId)
              ?.artwork
              .firstOrNull
              ?.url,
          note: 'new token',
          trailing: Icon(
            isSelected(result.compositeId)
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
          ),
          selected: isSelected(result.compositeId),
          onTap: enabled ? () => choose(result.compositeId) : null,
        ),
    ];
    return [
      if (entries.isEmpty)
        const Center(child: Text('No tokens are available to copy.'))
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 265),
          child: ListView(
            shrinkWrap: true,
            primary: false,
            key: const ValueKey('utility-transform-targets'),
            children: entries,
          ),
        ),
      if (isOwnDraft && selected == null)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'The board changed. Choose a token again.',
            textAlign: TextAlign.center,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            FilledButton.icon(
              key: const ValueKey('utility-transform-confirm'),
              onPressed: !enabled || selected == null
                  ? null
                  : () => _run(
                      () => _board.utilityAction(
                        player.id,
                        utility.id,
                        targetTokenId: selected,
                        expectedRevision: revision,
                        captured: scope,
                      ),
                      after: clear,
                    ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Create & transform'),
            ),
            OutlinedButton(
              onPressed: !enabled
                  ? null
                  : () => _run(
                      () => _board.utilityAction(
                        player.id,
                        utility.id,
                        skip: true,
                        expectedRevision: revision,
                        captured: scope,
                      ),
                      after: clear,
                    ),
              child: const Text('Create Myr & skip transformation'),
            ),
            if (isOwnDraft)
              TextButton(
                onPressed: enabled ? () => _update(clear) : null,
                child: const Text('Cancel selection'),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _ringDetail(UtilityState utility, WidgetDefinition? definition) {
    final player = p!;
    final key = 'utility.${utility.id}';
    final scope = _board.scope(player.id);
    final ring = RingService(c);
    final bearer = _field('$key.ringBearer', RingService.bearer(utility));
    return Padding(
      key: const ValueKey('utility-detail-the_ring'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SingleChildScrollView(
        key: const ValueKey('utility-fixed-controls'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _utilityInfo(utility, definition),
            Text(
              'Stage ${RingService.stage(utility)}/4',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < RingService.reminders.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${i + 1}. ${RingService.reminders[i]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: i < RingService.stage(utility)
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 235,
                child: _stepper(
                  'Total temptations',
                  utility.value,
                  () => _runDirect(
                    () => ring.adjustCount(
                      player.id,
                      utility.id,
                      -1,
                      captured: scope,
                    ),
                  ),
                  () => _runDirect(
                    () => ring.adjustCount(
                      player.id,
                      utility.id,
                      1,
                      captured: scope,
                    ),
                  ),
                  holdMinusStep: (amount) => _runDirect(
                    () => ring.adjustCount(
                      player.id,
                      utility.id,
                      -amount,
                      captured: scope,
                    ),
                  ),
                  holdPlusStep: (amount) => _runDirect(
                    () => ring.adjustCount(
                      player.id,
                      utility.id,
                      amount,
                      captured: scope,
                    ),
                  ),
                  maximum: RingService.maxTemptations,
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: _input(
                  '$key.ringBearer',
                  'Ring-bearer label (optional)',
                  initial: RingService.bearer(utility),
                  helper:
                      'A creature on the table needs no token or label here.',
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                _button(
                  'The Ring tempts you',
                  () => _run(
                    () => ring.tempt(
                      player.id,
                      utility.id,
                      bearer: bearer.text,
                      captured: scope,
                    ),
                    after: () {
                      final saved = c
                          .player(player.id)
                          .utilities
                          .firstWhere((u) => u.id == utility.id);
                      bearer.text = RingService.bearer(saved);
                    },
                  ),
                  primary: true,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: bearer,
                  builder: (context, value, _) =>
                      value.text.trim() == RingService.bearer(utility)
                      ? const SizedBox.shrink()
                      : _button(
                          'Save bearer',
                          () => _run(
                            () => ring.setBearer(
                              player.id,
                              utility.id,
                              value.text,
                              captured: scope,
                            ),
                            after: () => bearer.text = value.text.trim(),
                          ),
                          icon: Icons.check,
                        ),
                ),
                _button(
                  'Clear bearer',
                  () => _run(
                    () => ring.clearBearer(
                      player.id,
                      utility.id,
                      captured: scope,
                    ),
                    after: () => bearer.clear(),
                  ),
                  icon: Icons.person_remove_outlined,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Manual reminders. Creature eligibility and combat effects resolve at the table.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ),
            _utilityArtFooter(utility, definition),
          ],
        ),
      ),
    );
  }

  Widget _utilityArtwork(UtilityState utility) {
    final player = p!;
    final scope = _board.scope(player.id);
    final key = 'utility.${utility.id}';
    final candidate = _field('$key.artCandidate');
    final previewKey = GlobalObjectKey(candidate);
    final candidateArtist = _field('$key.artCandidateArtist');
    final candidateSet = _field('$key.artCandidateSet');
    final known = _board.utilityDefinitions
        .where((definition) => definition.id == utility.kind)
        .firstOrNull
        ?.artwork;
    final options = <Map<String, dynamic>>[];
    for (final raw in utility.configuration['artworkOptions'] as List? ?? []) {
      final option = Map<String, dynamic>.from(raw as Map);
      final url = option['url'] as String?;
      final displayed = utility.resolveArtworkUrl(url);
      if (displayed != url) {
        // The official choice replaces only the exact retired built-in image.
        continue;
      }
      if ((option['artist'] as String? ?? '').isEmpty) {
        final match = known?.where((art) => art.url == url).firstOrNull;
        if (match != null) option['artist'] = match.artist;
      }
      options.add(option);
    }
    final catalogUrl = UtilityState.catalogArtworkUrlFor(utility.kind);
    final catalogDefault = known
        ?.where((art) => art.url == catalogUrl)
        .firstOrNull;
    if (catalogDefault != null &&
        !options.any((art) => art['url'] == catalogDefault.url)) {
      options.insert(0, catalogDefault.toJson());
    }
    final previewing = candidate.text.isNotEmpty;
    final shown = previewing ? candidate.text : utility.displayedArtworkUrl;
    final current = options.where((art) => art['url'] == shown).firstOrNull;
    final artist = previewing
        ? candidateArtist.text
        : current?['artist'] as String?;
    Future<void> choose(
      String url, {
      String artist = '',
      String set = '',
    }) async {
      await TableArtwork.validatedBytes(url);
      if (!mounted) return;
      _update(() {
        candidate.text = url;
        candidateArtist.text = artist;
        candidateSet.text = set;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final previewContext = previewKey.currentContext;
        if (previewContext != null) {
          Scrollable.ensureVisible(previewContext, alignment: 0);
        }
      });
    }

    return _list([
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _button(
            'Upload utility artwork',
            () => _run(() async {
              final art = await _pickArtwork();
              if (art != null) {
                await choose(art, artist: 'user uploaded', set: 'Custom');
              }
            }),
            icon: Icons.upload,
          ),
        ],
      ),
      if (shown != null) ...[
        const SizedBox(height: 12),
        Text(
          previewing ? 'Preview — not saved' : 'Current artwork',
          key: previewKey,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _art(shown, width: 180, height: 140),
        ),
        TabletArtworkCredit(url: shown, artist: artist),
      ],
      if (previewing)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _button(
              'Use this artwork',
              () => _run(() async {
                final url = candidate.text;
                await TableArtwork.validatedBytes(url);
                final savedOptions = options
                    .map((art) => Map<String, dynamic>.from(art))
                    .toList();
                if (!savedOptions.any((art) => art['url'] == url)) {
                  savedOptions.add({
                    'url': url,
                    'set': candidateSet.text,
                    'artist': candidateArtist.text,
                  });
                }
                await _board.setUtility(
                  player.id,
                  utility.id,
                  artworkUrl: url,
                  configuration: {'artworkOptions': savedOptions},
                  captured: scope,
                );
                if (mounted) _update(candidate.clear);
              }),
              primary: true,
              icon: Icons.check,
            ),
            _button('Cancel preview', () => _update(candidate.clear)),
          ],
        ),
      if (utility.artworkUrl != null ||
          (utility.hasStockArtworkFallback &&
              utility.displayedArtworkUrl != null))
        _button(
          'Remove artwork',
          () => _run(() async {
            await _board.setUtility(
              player.id,
              utility.id,
              clearArtwork: true,
              captured: scope,
            );
            if (mounted) _update(candidate.clear);
          }),
          icon: Icons.hide_image_outlined,
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final art in options)
            SizedBox(
              width: 150,
              child: InkWell(
                onTap: _working
                    ? null
                    : () => _run(
                        () => choose(
                          art['url'] as String,
                          artist: art['artist'] as String? ?? '',
                          set: art['set'] as String? ?? '',
                        ),
                      ),
                child: Column(
                  children: [
                    _art(art['url'] as String?, width: 150, height: 130),
                    Text(
                      art['set'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    TabletArtworkCredit(
                      url: art['url'] as String?,
                      artist: art['artist'] as String?,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ], controls: false);
  }

  Future<void> _adjustPresetModifier(String playerId, String kind, int delta) =>
      _runDirect(() {
        final sources = c
            .player(playerId)
            .rules
            .where((r) => r.definitionId == kind);
        final count = sources.isEmpty ? 0 : sources.first.count;
        // A legacy source may exceed today's authoring limit. Submit only the
        // requested delta; service validation may reject it, but must never
        // turn one decrement into a jump down to the upper limit.
        return _board.setModifier(playerId, kind, max(0, count + delta));
      });

  Future<void> _adjustCustomModifier(
    String playerId,
    String sourceId,
    int delta,
  ) => _runDirect(() {
    final source = c.player(playerId).rules.firstWhere((r) => r.id == sourceId);
    return _board.setSource(
      playerId,
      sourceId,
      count: max(0, source.count + delta),
    );
  });

  Widget _rulesPage() {
    final player = p;
    if (player == null) {
      return _list([const Text('Open Rules from a player’s menu.')]);
    }
    if (_customRuleAuthoringEnabled && _ruleEditorOpen) {
      return _customRuleEditor(player);
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
      _gameGrid([
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
                () => _adjustPresetModifier(player.id, entry.key, -1),
                () => _adjustPresetModifier(player.id, entry.key, 1),
                holdMinusStep: (amount) =>
                    _adjustPresetModifier(player.id, entry.key, -amount),
                holdPlusStep: (amount) =>
                    _adjustPresetModifier(player.id, entry.key, amount),
                maximum: 20,
                detail: entry.key == 'primal_vigor'
                    ? 'Global · applies to the entire table'
                    : null,
              );
            },
          ),
      ]),
      if (player.rules.any((source) => source.definitionId == 'custom'))
        _section(
          'Existing custom effects',
          detail:
              'Saved effects are preserved. Enable or disable them here; authoring is deferred.',
        ),
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
                  () => _adjustCustomModifier(player.id, source.id, -1),
                  () => _adjustCustomModifier(player.id, source.id, 1),
                  holdMinusStep: (amount) =>
                      _adjustCustomModifier(player.id, source.id, -amount),
                  holdPlusStep: (amount) =>
                      _adjustCustomModifier(player.id, source.id, amount),
                  maximum: 20,
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

  Widget _customRuleEditor(PlayerState player) => _list([
    _button(
      'Back to rules',
      () => _update(() => _ruleEditorOpen = false),
      icon: Icons.arrow_back,
    ),
    const SizedBox(height: 8),
    _gameGrid([
      _gamePanel('When creating', [
        _input('rule.name', 'Rule name'),
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
                    onChanged: (_) =>
                        _update(() => _field('rule.triggerId').text = token.id),
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
      ]),
      _gamePanel('Outcome', [
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
                    onChanged: (_) =>
                        _update(() => _field('rule.targetId').text = token.id),
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
          }),
          icon: Icons.add,
        ),
        for (var index = 0; index < _customRuleOutcomes.length; index++)
          ListTile(
            title: Text(_outcomeLabel(_customRuleOutcomes[index])),
            trailing: MergeSemantics(
              child: Semantics(
                label: 'Remove outcome',
                child: IconButton(
                  onPressed: () =>
                      _update(() => _customRuleOutcomes.removeAt(index)),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
      ]),
    ]),
    SwitchListTile(
      title: const Text('Global applicability'),
      subtitle: const Text('This source affects every player while enabled.'),
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
            'enabled': _editingRuleId == null ? true : _editingRuleEnabled,
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
        after: () {
          _ruleEditorOpen = false;
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
          _ruleEditorOpen = false;
          _editingRuleId = null;
          _customRuleOutcomes.clear();
        }),
        icon: Icons.close,
      ),
  ]);

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
      _gameFieldAction(
        _input('preset.name', 'Name for the current setup'),
        _button(
          'Save this player’s setup',
          () => _run(
            () => _presets.save(
              player.id,
              _field('preset.name').text.trim(),
              imageUrl: c.profile(player.seatId).artworkUrl,
            ),
          ),
          icon: Icons.save_outlined,
          primary: true,
        ),
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
            () => _run(() => _presets.importJson(_field('preset.import').text)),
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
      _run(export);
    }
  }
}

/// An existing saved instance or a catalog entry that has not been enabled yet.
/// Catalog order and identity never depend on visibility, so a switch cannot
/// move its own row. Imported/custom duplicate instances remain independent.
class _UtilityChoice {
  const _UtilityChoice({this.utility, this.definition});
  final UtilityState? utility;
  final WidgetDefinition? definition;
  String get id => utility?.id ?? definition!.id;
  String get name => utility?.name ?? definition!.name;
  String get description => utility?.description.isNotEmpty == true
      ? utility!.description
      : definition?.description ?? '';
  String get sortName => name.toLowerCase();
  bool get visible => utility?.visible ?? false;
  bool matches(String query) {
    final search = query.trim().toLowerCase();
    return search.isEmpty ||
        '$name $description ${definition?.name ?? ''} ${definition?.description ?? ''}'
            .toLowerCase()
            .contains(search);
  }
}

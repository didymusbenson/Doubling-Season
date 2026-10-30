import 'dart:async';

import 'package:flutter/material.dart';
import 'package:doubling_season/utils/color_utils.dart';
import 'package:doubling_season/utils/constants.dart';
import 'package:doubling_season/widgets/counter_pill.dart';
import 'package:doubling_season/widgets/inline_color_identity_bar.dart';
import 'package:doubling_season/widgets/mana/mana_icons.dart';
import 'package:doubling_season/widgets/mana/mana_text.dart';

import '../domain/table_state.dart';
import '../features/board_service.dart';
import 'table_artwork.dart';
import 'half_stepper.dart';
import 'workspace/player_keyboard.dart';
import 'workspace/table_workspace.dart';

/// The original TokenCard's object controls, fitted to a player-local lane.
///
/// Reuses its symbol renderer, color bar, counter pills and color rail. All
/// mutations go through the tablet's scoped transaction/undo boundary; this
/// widget never initializes the phone providers or Hive boxes.
class TabletTokenCard extends StatefulWidget {
  const TabletTokenCard({
    super.key,
    required this.token,
    required this.player,
    required this.board,
    required this.playerName,
    required this.quarterTurns,
    required this.expanded,
    required this.onExpand,
    required this.onOpenDetailed,
    required this.onInputLock,
    this.topContentInset = 0,
    this.interactionEpoch = 0,
  });

  /// Extra internal room for shared controls over the first two-player card.
  /// The artwork and color rail still start at the card's outer top edge.
  final double topContentInset;
  final int interactionEpoch;
  final TokenState token;
  final PlayerState player;
  final BoardService board;
  final String playerName;
  final int quarterTurns;
  final bool expanded;
  final VoidCallback onExpand;
  final ValueChanged<WorkspacePage> onOpenDetailed;
  final ValueChanged<bool> onInputLock;

  @override
  State<TabletTokenCard> createState() => _TabletTokenCardState();
}

class _TabletTokenCardState extends State<TabletTokenCard>
    with AutomaticKeepAliveClientMixin {
  // Failed drafts remain attached to this stable token ID when the keyboard is
  // dismissed. Reopening the field retries that exact raw value.
  final Map<String, String> _drafts = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _fieldFocus = {};
  BoardScope? _draftScope;
  String? _editing;
  String? _error;
  bool _inputOpen = false;

  @override
  bool get wantKeepAlive => _inputOpen || _drafts.isNotEmpty;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focus in _fieldFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  TokenState get token => widget.token;
  String _value(String field, String saved) => _drafts[field] ?? saved;
  String get _name => token.name.isEmpty ? 'Unnamed token' : token.name;
  String get _target => '${widget.playerName}, $_name';

  Future<void> _perform(
    Future<void> Function() action, {
    bool allowInputLock = false,
  }) async {
    if (_inputOpen && !allowInputLock) return;
    try {
      if (!await _flushDrafts()) return;
      await action();
      if (mounted && _error != null) setState(() => _error = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    }
  }

  Future<bool> _flushDrafts() async {
    if (_drafts.isEmpty) return true;
    final pending = Map<String, String>.from(_drafts);
    try {
      await widget.board.editToken(
        widget.player.id,
        token.id,
        name: pending['name'],
        type: pending['type'],
        pt: pending['pt'],
        abilities: pending['abilities'],
        captured: _draftScope,
      );
      if (!mounted) return false;
      setState(() {
        for (final field in pending.keys) {
          if (_drafts[field] == pending[field]) _drafts.remove(field);
        }
        if (_drafts.isEmpty) _draftScope = null;
        _error = null;
      });
      updateKeepAlive();
      return true;
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${error.toString().replaceFirst('Bad state: ', '')} '
              'Draft kept; retry the field before continuing.',
        );
      }
      return false;
    }
  }

  Future<void> _open(WorkspacePage page) async {
    if (_inputOpen || !await _flushDrafts() || !mounted) return;
    widget.onOpenDetailed(page);
  }

  Future<void> _expand() async {
    if (_inputOpen || !await _flushDrafts() || !mounted) return;
    widget.onExpand();
  }

  Future<void> _edit(
    String field,
    String label,
    String saved, {
    bool numeric = false,
    bool multiline = false,
  }) async {
    if (_inputOpen) return;
    final playerId = widget.player.id;
    final tokenId = token.id;
    final board = widget.board;
    final scope = _draftScope ?? board.scope(playerId);
    final controller = _controllers.putIfAbsent(
      field,
      () => TextEditingController(text: _value(field, saved)),
    );
    if (!_drafts.containsKey(field)) {
      controller.value = TextEditingValue(
        text: saved,
        selection: TextSelection.collapsed(offset: saved.length),
      );
    }
    _fieldFocus.putIfAbsent(
      field,
      () => FocusNode(debugLabel: 'Token $tokenId $field'),
    );
    setState(() {
      _inputOpen = true;
      _editing = field;
      _drafts.putIfAbsent(field, () => saved);
      _draftScope = scope;
    });
    updateKeepAlive();
    widget.onInputLock(true);
    try {
      final savedSuccessfully = await showPlayerKeyboardEditor(
        context,
        title: '${widget.playerName} · $_name · $label',
        value: _value(field, saved),
        controller: controller,
        numeric: numeric,
        multiline: multiline,
        quarterTurns: widget.quarterTurns,
        onChanged: (value) {
          if (mounted) setState(() => _drafts[field] = value);
        },
        onCommit: (value) async {
          await board.editToken(
            playerId,
            tokenId,
            name: field == 'name' ? value : null,
            type: field == 'type' ? value : null,
            pt: field == 'pt' ? value : null,
            abilities: field == 'abilities' ? value : null,
            captured: scope,
          );
        },
      );
      if (!mounted) return;
      setState(() {
        if (savedSuccessfully) {
          _drafts.remove(field);
          if (_drafts.isEmpty) _draftScope = null;
          _error = null;
        } else {
          _error = 'Draft kept. Tap $label to retry saving.';
        }
      });
    } finally {
      widget.onInputLock(false);
      if (mounted) {
        setState(() {
          _inputOpen = false;
          _editing = null;
        });
        updateKeepAlive();
      }
    }
  }

  Future<bool> _deleteOnSwipe(DismissDirection _) async {
    if (_inputOpen || _drafts.isNotEmpty) return false;
    final playerId = widget.player.id;
    final tokenId = token.id;
    final board = widget.board;
    final scope = board.scope(playerId);
    setState(() => _inputOpen = true);
    widget.onInputLock(true);
    try {
      await _perform(
        () => board.deleteToken(playerId, tokenId, captured: scope),
        allowInputLock: true,
      );
    } finally {
      widget.onInputLock(false);
      if (mounted) setState(() => _inputOpen = false);
    }
    // Only the durable transaction removes the row. Failure leaves it intact;
    // global History provides undo without a confirmation or success toast.
    return false;
  }

  String get _powerToughness {
    if (_drafts.containsKey('pt')) return _drafts['pt']!;
    final parts = token.pt.split('/');
    if (parts.length != 2) return token.pt;
    String stat(String base, int independent) {
      final change = token.netPlusOneCounters + independent;
      final number = int.tryParse(base.trim());
      if (number != null) return '${number + change}';
      return '$base${change == 0
          ? ''
          : change > 0
          ? '+$change'
          : '$change'}';
    }

    return '${stat(parts[0], token.counters['+1/+0'] ?? 0)}/'
        '${stat(parts[1], token.counters['+0/+1'] ?? 0)}';
  }

  bool get _modifiedPt =>
      token.netPlusOneCounters != 0 ||
      (token.counters['+1/+0'] ?? 0) != 0 ||
      (token.counters['+0/+1'] ?? 0) != 0;

  // Readability belongs to the content, not a scrim across the token artwork.
  Widget _readable(Widget child) => token.artworkUrl == null
      ? child
      : DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .60),
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        );

  Widget _field({
    required String field,
    required String label,
    required String value,
    required Widget child,
    bool numeric = false,
    bool multiline = false,
  }) {
    final editing = _editing == field;
    Widget content = child;
    if (editing) {
      final color = token.artworkUrl == null
          ? Theme.of(context).colorScheme.onSurface
          : Colors.white;
      // The field on the token owns the controller. The keyboard uses this
      // exact instance, including selection and composing state; it is not a
      // second form whose text is later copied back into the object.
      content = TextField(
        key: ValueKey('inline:${token.id}:$field'),
        controller: _controllers[field]!,
        focusNode: _fieldFocus[field]!,
        readOnly: true,
        showCursor: true,
        keyboardType: TextInputType.none,
        maxLines: multiline ? 3 : 1,
        minLines: 1,
        textAlign: field == 'pt' ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: color,
          fontSize: field == 'name'
              ? 15
              : field == 'pt'
              ? 20
              : field == 'type'
              ? 11
              : 12,
          fontWeight: field == 'name' || field == 'pt'
              ? FontWeight.w800
              : FontWeight.normal,
          fontStyle: field == 'type' ? FontStyle.italic : FontStyle.normal,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 3),
          border: InputBorder.none,
          hintText: label,
        ),
        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      );
      if (field == 'pt') {
        content = SizedBox(width: 88, child: content);
      }
    }
    return Semantics(
      label: '$_target, $label',
      button: !editing,
      textField: editing,
      hint: widget.expanded ? 'Edit inline' : 'Expand token',
      child: InkWell(
        onTap: editing
            ? null
            : widget.expanded
            ? () => _edit(
                field,
                label,
                value,
                numeric: numeric,
                multiline: multiline,
              )
            : _expand,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: editing
                    ? Theme.of(context).colorScheme.primary
                    : widget.expanded
                    ? Colors.white24
                    : Colors.transparent,
              ),
            ),
            color: editing ? Colors.black26 : null,
          ),
          child: Align(
            alignment: field == 'pt' ? Alignment.center : Alignment.centerLeft,
            widthFactor: 1,
            child: _readable(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quantityAction({required bool increase}) {
    final enabled = !_inputOpen && (increase || token.amount > 0);
    final session = widget.board.controller.session;
    final playerId = widget.player.id;
    final tokenId = token.id;
    Future<void> change(int amount) => _perform(
      () => widget.board.changeQuantity(
        playerId,
        tokenId,
        increase ? amount : -amount,
      ),
    );
    return NumericHoldRegion(
      key: ValueKey('$tokenId-quantity-${increase ? 'increase' : 'decrease'}'),
      label:
          '$_target, ${increase ? 'Add one' : 'Remove one'}; hold for accelerating steps',
      interactionEpoch: Object.hash(
        session.id,
        session.generation,
        widget.player.generation,
        _inputOpen,
        widget.interactionEpoch,
      ),
      onTap: enabled ? () => change(1) : null,
      onStep: enabled ? change : null,
      child: SizedBox(
        width: 38,
        height: 40,
        child: Center(
          child: _readable(
            Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                increase ? Icons.add : Icons.remove,
                size: 21,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    VoidCallback? onHold,
    Key? key,
    bool consumeDisabled = false,
  }) => Semantics(
    key: key,
    button: true,
    enabled: onTap != null && !_inputOpen,
    label: '$_target, $label',
    onTap: _inputOpen ? null : onTap,
    onLongPress: _inputOpen || onTap == null ? null : onHold,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: _inputOpen ? null : onTap ?? (consumeDisabled ? () {} : null),
          onLongPress: _inputOpen ? null : onHold,
          child: SizedBox(
            width: 38,
            height: 40,
            child: Center(
              child: _readable(
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    icon,
                    size: 21,
                    color: onTap == null ? Colors.grey : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _status(Color textColor) => Semantics(
    label: '$_target, edit total, tapped and summoning sickness',
    button: true,
    explicitChildNodes: true,
    onTap: () => _open(WorkspacePage.tokenStatus),
    child: InkWell(
      excludeFromSemantics: true,
      onTap: () => _open(WorkspacePage.tokenStatus),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 7,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusCount(
              Icons.layers_outlined,
              token.amount,
              'total',
              textColor,
              prominent: true,
            ),
            if (!token.isEmblem) ...[
              _statusCount(
                Icons.mobile_friendly,
                token.untapped,
                'ready',
                textColor,
              ),
              _statusCount(ManaIcons.tap, token.tapped, 'tapped', textColor),
              if (widget.player.summoningSicknessEnabled)
                _statusCount(
                  ManaIcons.summoningSickness,
                  token.summoningSick,
                  'summoning sick',
                  textColor,
                ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _statusCount(
    IconData icon,
    int value,
    String name,
    Color color, {
    bool prominent = false,
  }) => Semantics(
    label: '$value $name',
    child: ExcludeSemantics(
      child: _readable(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: prominent ? 17 : 15, color: color),
              const SizedBox(width: 2),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: prominent ? 18 : 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _abilityDescription(String abilities, Color color) {
    final text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ManaText(
        abilities.isEmpty ? 'Abilities' : abilities,
        maxLines: widget.expanded ? null : 3,
        overflow: widget.expanded ? TextOverflow.clip : TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
    // Let the renderer reserve three complete lines in the collapsed card.
    // A fixed pixel viewport can cut a line in half with the real font, mana
    // symbols or larger accessibility text, even when maxLines is correct.
    if (!widget.expanded) return text;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 102),
      child: SingleChildScrollView(child: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final color = token.artworkUrl == null
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;
    final abilities = _value('abilities', token.abilities);
    final counters = <(String, int)>[
      if (token.plusOneCounters != 0) ('+1/+1', token.plusOneCounters),
      if (token.minusOneCounters != 0) ('-1/-1', token.minusOneCounters),
      for (final entry in token.counters.entries)
        if (entry.value != 0) (entry.key, entry.value),
    ];
    final card = AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      curve: Curves.easeInOutCubic,
      child: Opacity(
        opacity: token.amount == 0 ? .62 : 1,
        child: TableArtworkSurface(
          url: token.artworkUrl,
          style: token.extra['artworkDisplayStyle'] as String? ?? 'full',
          // Token expansion reveals editing controls, not a different art mode.
          // Match the original TokenCard: keep the selected fade/full treatment.
          shadeArtwork: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ColorUtils.gradientForColors(
                        token.colors,
                        isEmblem: token.isEmblem,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _inputOpen ? null : _expand,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        13,
                        5 + widget.topContentInset,
                        5,
                        3,
                      ),
                      child: IconTheme.merge(
                        data: IconThemeData(color: color),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: color),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) => Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _field(
                                        field: 'name',
                                        label: 'Name',
                                        value: token.name,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 3,
                                          ),
                                          child: Text(
                                            _value('name', token.name).isEmpty
                                                ? 'Name'
                                                : _value('name', token.name),
                                            maxLines: widget.expanded
                                                ? null
                                                : 2,
                                            overflow: widget.expanded
                                                ? null
                                                : TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth * .65,
                                      ),
                                      child: _status(color),
                                    ),
                                  ],
                                ),
                              ),
                              if (counters.isNotEmpty || widget.expanded)
                                SizedBox(
                                  height: 32,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final entry in counters)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: Semantics(
                                              button: true,
                                              label:
                                                  '$_target, manage ${entry.$1} counters',
                                              child: InkWell(
                                                onTap: () => _open(
                                                  WorkspacePage.tokenCounters,
                                                ),
                                                child: CounterPillView(
                                                  name: entry.$1,
                                                  amount: entry.$2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        _action(
                                          Icons.add_circle_outline,
                                          'Manage counters',
                                          () => _open(
                                            WorkspacePage.tokenCounters,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (token.type.isNotEmpty || widget.expanded)
                                _field(
                                  field: 'type',
                                  label: 'Type',
                                  value: token.type,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      _value('type', token.type).isEmpty
                                          ? 'Type'
                                          : _value('type', token.type),
                                      maxLines: widget.expanded ? null : 1,
                                      overflow: widget.expanded
                                          ? null
                                          : TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: color.withValues(alpha: .85),
                                      ),
                                    ),
                                  ),
                                ),
                              if ((token.type.isNotEmpty || widget.expanded) &&
                                  (abilities.isNotEmpty || widget.expanded))
                                const SizedBox(height: 3),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child:
                                        abilities.isNotEmpty || widget.expanded
                                        ? _field(
                                            field: 'abilities',
                                            label: 'Abilities',
                                            value: token.abilities,
                                            multiline: true,
                                            child: _abilityDescription(
                                              abilities,
                                              color,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  if (!token.isEmblem &&
                                      (token.hasPowerToughness ||
                                          widget.expanded)) ...[
                                    const SizedBox(width: 5),
                                    Flexible(
                                      flex: 0,
                                      child: _field(
                                        field: 'pt',
                                        label: 'Base power and toughness',
                                        value: token.pt,
                                        numeric: true,
                                        child: _PowerToughness(
                                          value: _powerToughness,
                                          modified: _modifiedPt,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (widget.expanded) ...[
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 2,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InlineColorIdentityBar(
                                      colorIdentity: token.colors,
                                      onToggle: (symbol) => _perform(
                                        () => widget.board.editToken(
                                          widget.player.id,
                                          token.id,
                                          colors: 'WUBRG'
                                              .split('')
                                              .where(
                                                (c) => c == symbol
                                                    ? !token.colors.contains(c)
                                                    : token.colors.contains(c),
                                              )
                                              .join(),
                                        ),
                                      ),
                                    ),
                                    _action(
                                      Icons.image_outlined,
                                      'Choose artwork',
                                      () => _open(WorkspacePage.tokenArtwork),
                                    ),
                                    _action(
                                      Icons.more_horiz,
                                      'Token details',
                                      () => _open(WorkspacePage.token),
                                    ),
                                  ],
                                ),
                              ],
                              // Tokens keep the original dense action row. Quantity
                              // is inline here; life and other trackers use halves.
                              Wrap(
                                key: ValueKey('${token.id}-actions'),
                                spacing: 0,
                                runSpacing: 0,
                                children: [
                                  _quantityAction(increase: false),
                                  _quantityAction(increase: true),
                                  if (!token.isEmblem) ...[
                                    _action(
                                      Icons.mobile_friendly,
                                      'Untap one; hold to untap all',
                                      token.tapped == 0
                                          ? null
                                          : () => _perform(
                                              () => widget.board.tapTokens(
                                                widget.player.id,
                                                token.id,
                                                -1,
                                              ),
                                            ),
                                      onHold: token.tapped == 0
                                          ? null
                                          : () => _perform(
                                              () => widget.board.tapTokens(
                                                widget.player.id,
                                                token.id,
                                                -token.tapped,
                                              ),
                                            ),
                                    ),
                                    _action(
                                      ManaIcons.tap,
                                      'Tap one; hold to tap all',
                                      token.untapped == 0
                                          ? null
                                          : () => _perform(
                                              () => widget.board.tapTokens(
                                                widget.player.id,
                                                token.id,
                                                1,
                                              ),
                                            ),
                                      onHold: token.untapped == 0
                                          ? null
                                          : () => _perform(
                                              () => widget.board.tapTokens(
                                                widget.player.id,
                                                token.id,
                                                token.untapped,
                                              ),
                                            ),
                                    ),
                                    _action(
                                      Icons.trending_up,
                                      'Add +1/+1 counter; hold to add ten',
                                      () => _perform(
                                        () => widget.board.counter(
                                          widget.player.id,
                                          token.id,
                                          '+1/+1',
                                          1,
                                        ),
                                      ),
                                      onHold: () => _perform(
                                        () => widget.board.counter(
                                          widget.player.id,
                                          token.id,
                                          '+1/+1',
                                          10,
                                        ),
                                      ),
                                    ),
                                    _action(
                                      Icons.content_copy,
                                      'Copy one fresh token',
                                      () => _perform(
                                        () => widget.board.copyToken(
                                          widget.player.id,
                                          token.id,
                                        ),
                                      ),
                                    ),
                                    _action(
                                      Icons.call_split,
                                      'Split stack',
                                      token.amount < 2
                                          ? null
                                          : () =>
                                                _open(WorkspacePage.tokenSplit),
                                    ),
                                  ],
                                  if (token.name.toLowerCase().contains(
                                    GameConstants.scuteSwarmName,
                                  ))
                                    _action(
                                      Icons.bug_report,
                                      'Create Scute Swarms from this seat’s total',
                                      () => _perform(
                                        () => widget.board.scuteSwarm(
                                          widget.player.id,
                                          token.id,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (_error != null)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    if (_drafts.isNotEmpty)
                                      MergeSemantics(
                                        child: Semantics(
                                          label: 'Discard unsaved token edits',
                                          child: IconButton(
                                            onPressed: _inputOpen
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _drafts.clear();
                                                      _draftScope = null;
                                                      _error = null;
                                                    });
                                                    updateKeepAlive();
                                                  },
                                            icon: const Icon(
                                              Icons.undo,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Dismissible(
      key: ValueKey('swipe:${token.id}'),
      direction: _inputOpen || _drafts.isNotEmpty
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: _deleteOnSwipe,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.all(12),
        child: const Icon(
          Icons.delete_outline,
          semanticLabel: 'Remove token stack',
        ),
      ),
      child: card,
    );
  }
}

/// Same pop-on-change feedback as the original token object, without coupling
/// this seat's model to the phone Item/Hive class.
class _PowerToughness extends StatefulWidget {
  const _PowerToughness({
    required this.value,
    required this.modified,
    required this.color,
  });
  final String value;
  final bool modified;
  final Color color;
  @override
  State<_PowerToughness> createState() => _PowerToughnessState();
}

class _PowerToughnessState extends State<_PowerToughness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  @override
  void didUpdateWidget(_PowerToughness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: widget.modified ? Colors.orange.shade800 : Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: widget.value.isEmpty
          ? ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ManaIcons.power,
                    size: 22,
                    color: widget.color.withValues(alpha: .55),
                  ),
                  Text(
                    '/',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: widget.color.withValues(alpha: .55),
                    ),
                  ),
                  Icon(
                    ManaIcons.toughness,
                    size: 22,
                    color: widget.color.withValues(alpha: .55),
                  ),
                ],
              ),
            )
          : Text(
              widget.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: widget.modified ? Colors.white : widget.color,
              ),
            ),
    ),
  );
}

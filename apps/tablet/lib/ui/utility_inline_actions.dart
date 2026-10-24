import 'package:flutter/material.dart';

import '../domain/table_state.dart';
import '../features/board_service.dart';

/// Gameplay belongs on the board. Management remains a separate destination.
class UtilityInlineActions extends StatefulWidget {
  final BoardService board;
  final String playerId;
  final UtilityState utility;
  final List<Widget> management;
  const UtilityInlineActions({
    super.key,
    required this.board,
    required this.playerId,
    required this.utility,
    this.management = const [],
  });

  static const labels = {
    'rhys_the_redeemed': 'Copy Tokens',
    'krenko_mob_boss': 'Make Goblins',
    'krenko_tin_street': 'Make Goblins',
    'hare_apparent': 'Make Rabbits',
    'the_unbeatable_squirrel_girl': 'Make Squirrels · 1GGG',
    'academy_manufactor': 'Make Tokens',
    'cathars_crusade': 'Resolve All',
    'brudiclad_telchor_engineer': 'Resolve Trigger',
  };

  @override
  State<UtilityInlineActions> createState() => _UtilityInlineActionsState();
}

class _UtilityInlineActionsState extends State<UtilityInlineActions> {
  bool _working = false;
  String? _message;
  BoardScope? _selectionScope;
  int? _selectionRevision;

  void _chooseTarget() {
    setState(() {
      _message = null;
      _selectionScope = widget.board.scope(widget.playerId);
      _selectionRevision = widget.board.controller.session.revision;
    });
  }

  Future<void> _resolve({
    bool quick = false,
    bool skip = false,
    String? target,
  }) async {
    if (_working) return;
    final kind = widget.utility.kind;
    final choosing = kind == 'brudiclad_telchor_engineer';
    // Resolve direct activations against the live serialized board. A multi-step
    // target choice instead pins its preview and fails safely after any revision.
    final scope = choosing
        ? _selectionScope
        : widget.board.scope(widget.playerId);
    final revision = choosing ? _selectionRevision : null;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      if (!choosing &&
          kind != 'cathars_crusade' &&
          widget.board
              .utilityPreview(widget.playerId, widget.utility.id)
              .isEmpty) {
        if (mounted) setState(() => _message = 'No tokens to create.');
        return;
      }
      if (kind == 'cathars_crusade' && !quick && widget.utility.value <= 0) {
        if (mounted) setState(() => _message = 'No pending triggers.');
        return;
      }
      await widget.board.utilityAction(
        widget.playerId,
        widget.utility.id,
        quick: quick,
        skip: skip,
        targetTokenId: target,
        captured: scope,
        expectedRevision: revision,
      );
      if (mounted) setState(() => _selectionScope = null);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString().replaceFirst('Bad state: ', '');
          // Reopen deliberately to refresh a stale preview/target set.
          _selectionScope = null;
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.utility.kind;
    final label = UtilityInlineActions.labels[kind];
    if (label == null) {
      return Wrap(spacing: 4, children: widget.management);
    }
    final choosing = _selectionScope != null;
    final player = widget.board.controller.player(widget.playerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            FilledButton.tonal(
              key: ValueKey('utility-action-${widget.utility.id}'),
              onPressed: _working
                  ? null
                  : kind == 'brudiclad_telchor_engineer'
                  ? _chooseTarget
                  : () => _resolve(),
              child: Text(_working ? 'Working…' : label),
            ),
            if (kind == 'cathars_crusade')
              OutlinedButton(
                key: ValueKey('utility-quick-${widget.utility.id}'),
                onPressed: _working ? null : () => _resolve(quick: true),
                child: const Text('Quick +1/+1'),
              ),
            ...widget.management,
          ],
        ),
        if (choosing) ...[
          const Text(
            'Choose a token to copy, or create the Myr without transforming.',
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              key: ValueKey('utility-targets-${widget.utility.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final token in player.tokens.where(
                    (t) => t.amount > 0 && !t.isEmblem,
                  ))
                    OutlinedButton(
                      key: ValueKey(
                        'utility-target-${widget.utility.id}-${token.id}',
                      ),
                      onPressed: _working
                          ? null
                          : () => _resolve(target: token.id),
                      child: Text('Copy ${token.name} · ${token.pt}'),
                    ),
                  for (final result in widget.board.utilityPreview(
                    widget.playerId,
                    widget.utility.id,
                  ))
                    OutlinedButton(
                      onPressed: _working
                          ? null
                          : () => _resolve(target: result.compositeId),
                      child: Text('Copy ${result.name} (new token)'),
                    ),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'Create the Myr and skip transformation',
            child: OutlinedButton(
              key: ValueKey('utility-skip-${widget.utility.id}'),
              onPressed: _working ? null : () => _resolve(skip: true),
              child: const Text('Create Myr only'),
            ),
          ),
          TextButton(
            onPressed: _working
                ? null
                : () => setState(() => _selectionScope = null),
            child: const Text('Cancel selection'),
          ),
        ],
        if (_message != null)
          Text(
            _message!,
            key: ValueKey('utility-feedback-${widget.utility.id}'),
          ),
      ],
    );
  }
}

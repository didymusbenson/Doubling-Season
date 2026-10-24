import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/database/counter_database.dart';
import 'package:doubling_season/widgets/mana/mana_text.dart';
import 'package:doubling_season/providers/rules_provider.dart'
    show TokenCreationResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/table_controller.dart';
import '../../domain/table_state.dart';
import '../../features/board_service.dart';
import '../../features/preset_service.dart';
import '../../services/tablet_catalog.dart';
import 'player_keyboard.dart';
import '../table_artwork.dart';
import '../half_stepper.dart';
import '../commander_ledger.dart';
import '../monarch_crown.dart';
import '../artwork_selection.dart';
import '../life_artwork_picker.dart';
import '../token_board_summary.dart';
import '../support_sheet.dart';

part 'token_pages.dart';
part 'game_pages.dart';
part 'library_pages.dart';

enum WorkspacePage {
  tokens,
  token,
  tokenStatus,
  tokenCounters,
  tokenSplit,
  tokenArtwork,
  tokenSummary,
  utilities,
  rules,
  presets,
  player,
  commanderDamage,
  counters,
  history,
  reset,
  dice,
  settings,
}

bool _workspaceOpen = false;
final Map<String, _WorkspaceDraft> _failedDrafts = {};

/// This route owns the sole editor and consumes all taps outside its surface.
Future<void> showTableWorkspace(
  BuildContext context,
  TableController controller, {
  required TabletCatalog catalog,
  String? seatId,
  int quarterTurns = 0,
  WorkspacePage initialPage = WorkspacePage.tokens,
  String? itemId,
}) async {
  if (_workspaceOpen) return;
  _workspaceOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close workspace',
      barrierColor: Colors.black.withValues(alpha: .76),
      useRootNavigator: true,
      builder: (context) => _TableWorkspace(
        controller: controller,
        catalog: catalog,
        seatId: seatId,
        quarterTurns: quarterTurns,
        initialPage: initialPage,
        itemId: itemId,
      ),
    );
  } finally {
    _workspaceOpen = false;
  }
}

class _TableWorkspace extends StatefulWidget {
  const _TableWorkspace({
    required this.controller,
    required this.catalog,
    required this.initialPage,
    required this.quarterTurns,
    this.seatId,
    this.itemId,
  });
  final TableController controller;
  final TabletCatalog catalog;
  final String? seatId;
  final int quarterTurns;
  final WorkspacePage initialPage;
  final String? itemId;
  @override
  State<_TableWorkspace> createState() => _TableWorkspaceState();
}

class _TableWorkspaceState extends State<_TableWorkspace> {
  late WorkspacePage _page;
  String? _commanderOwnerId;
  bool _commanderSetup = false;
  int _playerTabIndex = 0;
  int _resetTabIndex = 0;
  String? _editingPlayerCounter;
  bool _artworkPreviewActive = false;
  String? _editingCommanderId;
  Future<void> _directQueue = Future.value();
  // Failure survives later successful writes and close-in-progress rebuilds.
  String? _directFailure;
  int _directFailureEpoch = 0;
  bool _directFailureNeedsAcknowledgement = false;
  late BoardService _board;
  late PresetService _presets;
  late String _sessionId;
  late int _sessionGeneration;
  String? _playerId;
  String? _itemId;
  final _fields = <String, TextEditingController>{};
  final _inlineEdits = <String, _InlineEdit>{};
  bool _allowPop = false;
  bool _closing = false;
  bool _navigating = false;
  String? _error;
  String? _status;
  bool _working = false;
  bool _createCustom = false;
  bool _createTapped = false;
  bool _applyPresetImage = false;
  String _tokenTab = 'all';
  Category? _category;
  final Set<String> _tokenColors = {};
  String? _selectedCounter;
  String? _editingNumber;
  TokenDefinition? _selectedDefinition;
  _Confirmation? _confirmation;
  final _navigation = <(WorkspacePage, String?)>[];
  int _resetCount = 4;
  int _emptySlot = 3;
  String? _editingRuleId;
  bool _ruleEditorOpen = false;
  int _editingRuleCount = 1;
  bool _editingRuleEnabled = true;
  final List<Map<String, dynamic>> _customRuleOutcomes = [];
  String _customTrigger = 'all';
  String _customEffect = 'multiply';
  bool _customGlobal = false;
  final Map<int, int> _diceCounts = {4: 0, 6: 1, 8: 0, 10: 0, 12: 0, 20: 0};
  final List<String> _diceResults = [];
  int? _diceTotal;

  TableController get c => widget.controller;
  TabletCatalog get catalog => widget.catalog;
  PlayerState? get p {
    for (final player in c.session.players) {
      if (player.id == _playerId) return player;
    }
    return null;
  }

  String get _seatName => p == null ? 'Table' : c.profile(p!.seatId).name;
  String get _draftKey =>
      '$_sessionId:$_sessionGeneration:${_playerId ?? 'table'}:$_page:${_itemId ?? ''}';
  bool get _validScope =>
      c.session.id == _sessionId &&
      c.session.generation == _sessionGeneration &&
      (_playerId == null || p != null);

  @override
  void initState() {
    super.initState();
    _sessionId = c.session.id;
    _sessionGeneration = c.session.generation;
    _page = widget.initialPage;
    _itemId = widget.itemId;
    for (final player in c.session.players) {
      if (player.seatId == widget.seatId || player.id == widget.seatId) {
        _playerId = player.id;
      }
    }
    _resetCount = c.session.players.length;
    _emptySlot = List.generate(4, (index) => index).firstWhere(
      (slot) => !c.session.players.any((player) => player.slot == slot),
      orElse: () => 3,
    );
    _board = BoardService(c, catalog);
    _presets = PresetService(c, catalog);
    final recovered = _failedDrafts[_draftKey];
    if (recovered != null) {
      for (final entry in recovered.fields.entries) {
        _field(entry.key, entry.value);
      }
      _page = recovered.page;
      _itemId = recovered.itemId;
      _selectedDefinition = recovered.definition;
      _createCustom = recovered.createCustom;
      _createTapped = recovered.createTapped;
      _applyPresetImage = recovered.applyPresetImage;
      _customTrigger = recovered.trigger;
      _customEffect = recovered.effect;
      _customGlobal = recovered.global;
      _editingRuleId = recovered.ruleId;
      _editingRuleCount = recovered.ruleCount;
      _editingRuleEnabled = recovered.ruleEnabled;
      _customRuleOutcomes.addAll(
        recovered.outcomes.map((value) => Map<String, dynamic>.from(value)),
      );
      _resetCount = recovered.playerCount;
      _emptySlot = recovered.emptySlot;
      _status = 'Recovered your draft from an unsuccessful save.';
    }
    c.addListener(_refresh);
    catalog.addListener(_refresh);
    if (!catalog.loaded) catalog.load();
  }

  void _update(VoidCallback callback) {
    if (mounted && !_closing && !_navigating) setState(callback);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  TextEditingController _field(String id, [String initial = '']) =>
      _fields.putIfAbsent(id, () => TextEditingController(text: initial));

  void _retainDrafts() {
    _failedDrafts[_draftKey] = _WorkspaceDraft(
      fields: {
        for (final entry in _fields.entries) entry.key: entry.value.text,
      },
      page: _page,
      itemId: _itemId,
      definition: _selectedDefinition,
      createCustom: _createCustom,
      createTapped: _createTapped,
      applyPresetImage: _applyPresetImage,
      trigger: _customTrigger,
      effect: _customEffect,
      global: _customGlobal,
      ruleId: _editingRuleId,
      ruleCount: _editingRuleCount,
      ruleEnabled: _editingRuleEnabled,
      outcomes: _customRuleOutcomes.map((value) => cloneJson(value)).toList(),
      playerCount: _resetCount,
      emptySlot: _emptySlot,
    );
  }

  Future<bool> _commitInline(String id) async {
    final edit = _inlineEdits[id];
    if (edit == null) return true;
    edit.timer?.cancel();
    if (edit.saving != null) return edit.saving!;
    if (edit.controller.text == edit.savedValue) return true;
    Future<bool> persist() async {
      if (!_validScope) {
        _retainDrafts();
        return false;
      }
      while (edit.controller.text != edit.savedValue) {
        final value = edit.controller.text;
        try {
          final result = await edit.save(value);
          if (result == false) {
            throw StateError(c.error ?? 'Your edit could not be saved.');
          }
          edit.savedValue = value;
          if (mounted) setState(() => _error = null);
        } catch (error) {
          _retainDrafts();
          if (mounted) setState(() => _error = '$error');
          return false;
        }
      }
      if (_inlineEdits.values.every(
        (value) => value.controller.text == value.savedValue,
      )) {
        _failedDrafts.remove(_draftKey);
      }
      return true;
    }

    edit.saving = persist();
    final result = await edit.saving!;
    edit.saving = null;
    return result;
  }

  Future<bool> _flushInline() async {
    var saved = true;
    for (final id in _inlineEdits.keys.toList()) {
      if (!await _commitInline(id)) saved = false;
    }
    return saved;
  }

  Future<void> _requestClose() async {
    if (_closing) return;
    setState(() => _closing = true);
    await WidgetsBinding.instance.endOfFrame;
    await _directQueue;
    await _flushInline();
    if (!mounted) return;
    if (_directFailureNeedsAcknowledgement) {
      setState(() {
        _closing = false;
        _directFailureNeedsAcknowledgement = false;
        _error = _directFailure;
      });
      return; // Show the failed action once; explicit Close can then dismiss.
    }
    _finishClose();
  }

  // Completion can replace the session; do not revalidate the old target or
  // replay its inline fields after a successful reset/restore.
  void _finishClose() {
    if (!mounted) return;
    setState(() {
      _closing = true;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _back() async {
    if (_working || _closing || _navigating) return;
    setState(() => _navigating = true);
    try {
      if (!await _flushInline() || !mounted || _closing) return;
      setState(() {
        final destination = _navigation.removeLast();
        _page = destination.$1;
        _itemId = destination.$2;
        _confirmation = null;
      });
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  Future<void> _run(
    Future<dynamic> Function() action, {
    String? success,
    VoidCallback? after,
    bool closeOnSuccess = false,
  }) async {
    if (_working || _closing || _navigating || !_validScope) return;
    setState(() {
      _working = true;
      _error = null;
      _status = null;
    });
    try {
      await _directQueue;
      if (!await _flushInline() || !mounted || !_validScope || _closing) return;
      final result = await action();
      if (result == false) {
        throw StateError(c.error ?? 'The change could not be saved.');
      }
      _failedDrafts.remove(_draftKey);
      if (mounted) {
        setState(() {
          if (success != null) _status = success;
          after?.call();
        });
        if (closeOnSuccess) _finishClose();
      }
    } catch (error) {
      _retainDrafts();
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Direct numeric commands never disable/reflow the active control per save.
  Future<void> _runDirect(Future<dynamic> Function() action) {
    if (_working || _closing || _navigating || !_validScope) {
      return Future.value();
    }
    final operation = _directQueue.then((_) async {
      try {
        if (!mounted || !_validScope) return;
        if (!await _flushInline()) {
          throw StateError('The current text edit could not be saved.');
        }
        final result = await action();
        if (result == false) {
          throw StateError(c.error ?? 'The change could not be saved.');
        }
      } catch (error) {
        _directFailure =
            'Some changes were not saved. Check the displayed totals before retrying. $error';
        _directFailureNeedsAcknowledgement = true;
        _directFailureEpoch++;
        if (mounted) setState(() => _error = _directFailure);
      }
    });
    _directQueue = operation;
    return operation;
  }

  Future<void> _stepCommander(
    PlayerState player,
    CommanderSource source,
    int delta,
  ) => _runDirect(() => c.adjustCommanderDamage(player.id, source.id, delta));

  Future<void> _editCommander(
    PlayerState player,
    CommanderSource source,
  ) async {
    if (_working || _closing || _navigating || !_validScope) return;
    setState(() => _working = true);
    try {
      await _directQueue;
      if (!mounted || !_validScope || _closing) return;
      setState(() {
        _field('damage.${source.id}').text = '1';
        _field('damageCorrection.${source.id}').text =
            '${c.player(player.id).commanderDamage[source.id] ?? 0}';
        _editingCommanderId = source.id;
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  int _integer(String field, {int min = -1000000000, int max = 1000000000}) {
    return _wholeNumber(_field(field).text, min: min, max: max);
  }

  int _wholeNumber(
    String valueText, {
    int min = -1000000000,
    int max = 1000000000,
  }) {
    final text = valueText.trim();
    if (!RegExp(r'^-?[0-9]+$').hasMatch(text)) {
      throw const FormatException(
        'Enter a whole number, with a minus sign only for negative values.',
      );
    }
    final value = int.tryParse(text);
    if (value == null || value < min || value > max) {
      throw FormatException('Enter a number between $min and $max.');
    }
    return value;
  }

  Future<void> _go(WorkspacePage page, {String? itemId}) async {
    if (_working || _closing || _navigating) return;
    setState(() => _navigating = true);
    try {
      if (!await _flushInline() || !mounted || _closing) return;
      setState(() {
        _navigation.add((_page, _itemId));
        _page = page;
        if (page == WorkspacePage.player) _playerTabIndex = 0;
        _itemId = itemId;
        _confirmation = null;
        _error = null;
        _status = null;
        _selectedDefinition = null;
        _createCustom = false;
      });
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  void _confirm(
    String title,
    String detail,
    Future<dynamic> Function() action, {
    String button = 'Confirm',
    bool closeOnSuccess = false,
  }) {
    if (!mounted || !_validScope || _closing || _navigating) return;
    setState(
      () => _confirmation = _Confirmation(
        title,
        detail,
        action,
        button,
        closeOnSuccess,
      ),
    );
  }

  Widget _button(
    String label,
    VoidCallback action, {
    IconData? icon,
    bool primary = false,
  }) => primary
      ? FilledButton.icon(
          onPressed: _working ? null : action,
          icon: Icon(icon ?? Icons.check, size: 18),
          label: Text(label),
        )
      : OutlinedButton.icon(
          onPressed: _working ? null : action,
          icon: Icon(icon ?? Icons.chevron_right, size: 18),
          label: Text(label),
        );

  Widget _input(
    String id,
    String label, {
    String initial = '',
    bool numeric = false,
    int maxLines = 1,
    String? helper,
    Future<dynamic> Function(String value)? onCommit,
    bool live = false,
  }) {
    final controller = _field(id, initial);
    if (onCommit != null && !_inlineEdits.containsKey(id)) {
      final edit = _InlineEdit(controller, initial, onCommit);
      _inlineEdits[id] = edit;
      if (live) {
        controller.addListener(() {
          edit.timer?.cancel();
          if (controller.text.trim().isEmpty ||
              controller.text == edit.savedValue) {
            return;
          }
          edit.timer = Timer(
            const Duration(milliseconds: 350),
            () => _commitInline(id),
          );
        });
      }
    }
    final existing = _inlineEdits[id];
    if (existing != null &&
        existing.saving == null &&
        existing.controller.text == existing.savedValue &&
        onCommit != null) {
      existing.save = onCommit;
    }
    if (existing != null &&
        existing.saving == null &&
        existing.controller.text == existing.savedValue &&
        initial != existing.savedValue) {
      existing.savedValue = initial;
      existing.controller.text = initial;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PlayerField(
        controller: controller,
        label: label,
        numeric: numeric,
        maxLines: maxLines,
        helperText: helper,
        onExit: onCommit == null ? null : () => _commitInline(id),
      ),
    );
  }

  Widget _section(String title, {String? detail}) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (detail != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail)),
      ],
    ),
  );

  Widget _list(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
    children: [
      for (final child in children)
        if (child is ButtonStyleButton)
          Align(alignment: Alignment.centerLeft, child: child)
        else
          child,
    ],
  );

  Widget _art(String? url, {double width = 72, double height = 72}) => SizedBox(
    width: width,
    height: height,
    child: TableArtwork(
      url: url,
      placeholder: const Icon(Icons.image_outlined),
    ),
  );

  Future<String?> _pickArtwork() async {
    final reference = await pickTabletArtwork(
      context,
      quarterTurns: widget.quarterTurns,
    );
    if (!mounted || !_validScope) return null;
    return reference;
  }

  Widget _stepper(
    String label,
    int value,
    VoidCallback minus,
    VoidCallback plus, {
    String? detail,
    VoidCallback? edit,
    VoidCallback? holdMinus,
    VoidCallback? holdPlus,
    FutureOr<void> Function(int)? holdMinusStep,
    FutureOr<void> Function(int)? holdPlusStep,
    int holdStep = 5,
    int? minimum = 0,
    int? maximum,
  }) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HalfStepper(
            height: 48,
            label: label,
            value: '$value',
            decreaseLabel: 'Decrease $label',
            increaseLabel: 'Increase $label',
            onDecrease: _working || (minimum != null && value <= minimum)
                ? null
                : minus,
            onIncrease: _working || (maximum != null && value >= maximum)
                ? null
                : plus,
            onDecreaseHold: _working ? null : holdMinus,
            onIncreaseHold: _working ? null : holdPlus,
            onDecreaseHoldStep: _working || _closing || _navigating
                ? null
                : holdMinusStep,
            onIncreaseHoldStep: _working || _closing || _navigating
                ? null
                : holdPlusStep,
            holdStep: holdStep,
            interactionEpoch: Object.hash(
              _sessionId,
              _sessionGeneration,
              _closing,
              _navigating,
              _page,
              _itemId,
              _directFailureEpoch,
            ),
            holdRepeatInterval: null,
            onEdit: _working ? null : edit,
            valueWidget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text('$value', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          if (detail != null)
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    c.removeListener(_refresh);
    catalog.removeListener(_refresh);
    for (final edit in _inlineEdits.values) {
      edit.timer?.cancel();
    }
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String get _title => switch (_page) {
    WorkspacePage.tokens => 'Add tokens',
    WorkspacePage.token => 'Token details',
    WorkspacePage.tokenStatus => 'Token status',
    WorkspacePage.tokenCounters => 'Token counters',
    WorkspacePage.tokenSplit => 'Split stack',
    WorkspacePage.tokenArtwork => 'Token artwork',
    WorkspacePage.tokenSummary => 'Board summary',
    WorkspacePage.utilities => 'Utilities',
    WorkspacePage.rules => 'Rules',
    WorkspacePage.presets => 'Saved setups',
    WorkspacePage.player => 'Life & player',
    WorkspacePage.commanderDamage => 'Commander damage',
    WorkspacePage.counters => 'Player counters',
    WorkspacePage.history => 'Game history',
    WorkspacePage.reset => 'Reset & restore',
    WorkspacePage.dice => 'Dice',
    WorkspacePage.settings => 'Table settings',
  };

  Widget _content() {
    if (!_validScope) {
      return _list([
        _section(
          'This game has changed',
          detail:
              'Close this workspace and reopen the current game. Your previous target will not be reassigned.',
        ),
      ]);
    }
    final confirmation = _confirmation;
    if (confirmation != null) {
      return _list([
        _section(confirmation.title, detail: confirmation.detail),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _button(
              'Cancel',
              () => setState(() => _confirmation = null),
              icon: Icons.close,
            ),
            _button(
              confirmation.button,
              () => _run(
                confirmation.action,
                after: () => _confirmation = null,
                closeOnSuccess: confirmation.closeOnSuccess,
              ),
              primary: true,
            ),
          ],
        ),
      ]);
    }
    return switch (_page) {
      WorkspacePage.tokens => _tokensPage(),
      WorkspacePage.token ||
      WorkspacePage.tokenStatus ||
      WorkspacePage.tokenCounters ||
      WorkspacePage.tokenSplit ||
      WorkspacePage.tokenArtwork => _tokenPage(),
      WorkspacePage.tokenSummary =>
        p == null
            ? const SizedBox.shrink()
            : _list([TokenBoardSummary(player: p!)]),
      WorkspacePage.utilities => _utilitiesPage(),
      WorkspacePage.rules => _rulesPage(),
      WorkspacePage.presets => _presetsPage(),
      WorkspacePage.player => _playerPage(),
      WorkspacePage.commanderDamage => _commanderPage(),
      WorkspacePage.counters => _countersPage(),
      WorkspacePage.history => _historyPage(),
      WorkspacePage.reset => _resetPage(),
      WorkspacePage.dice => _dicePage(),
      WorkspacePage.settings => _settingsPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final visibleError = _directFailure ?? _error;
    final rotated = widget.quarterTurns.isOdd;
    final focusedCommander = _page == WorkspacePage.commanderDamage;
    final commanderSetup = _commanderSetup || _editingCommanderId != null;
    const commanderWidth = 680.0;
    final utility = _page == WorkspacePage.utilities && p != null
        ? p!.utilities.where((u) => u.id == _itemId).firstOrNull
        : null;
    final utilityArtwork =
        utility != null &&
        _field('utility.${utility.id}.panel').text == 'artwork';
    final compactUtility = utility != null && !utilityArtwork;
    final artworkToken = _page == WorkspacePage.tokenArtwork
        ? p?.tokens.where((t) => t.id == _itemId).firstOrNull
        : null;
    final hasArtwork = artworkToken?.artworkUrl != null;
    final hasArtworkOptions =
        (artworkToken?.artworkOptions.isNotEmpty ?? false) ||
        (catalog.byId(artworkToken?.definitionId ?? '')?.artwork.isNotEmpty ??
            false);
    // Frames follow the task's content. Search/artwork/timelines keep a taller
    // list viewport; fixed controls do not inherit a nearly full-screen form.
    final (panelWidth, panelHeight) = switch (_page) {
      WorkspacePage.player => (
        900.0,
        _playerTabIndex == 3
            ? 760.0
            : _playerTabIndex == 0
            ? ((rotated ? size.height : size.width) < 760 ? 620.0 : 540.0)
            : 600.0,
      ),
      WorkspacePage.counters => (
        680.0,
        _editingPlayerCounter == null ? 420.0 : 470.0,
      ),
      WorkspacePage.dice => (800.0, 580.0),
      WorkspacePage.reset => (
        760.0,
        _resetTabIndex == 0
            ? (_resetCount == 3
                  ? 600.0
                  : (rotated ? size.height : size.width) < 760
                  ? 520.0
                  : 480.0)
            : 650.0,
      ),
      WorkspacePage.settings => (760.0, 760.0),
      WorkspacePage.tokenArtwork => (
        760.0,
        _artworkPreviewActive
            ? 640.0
            : hasArtwork
            ? 580.0
            : hasArtworkOptions
            ? 520.0
            : 360.0,
      ),
      WorkspacePage.tokenStatus => (600.0, 440.0),
      WorkspacePage.tokenCounters => (680.0, 640.0),
      WorkspacePage.tokenSplit => (680.0, 560.0),
      WorkspacePage.tokenSummary => (700.0, 650.0),
      WorkspacePage.token => (820.0, 760.0),
      WorkspacePage.tokens when _selectedDefinition != null => (720.0, 520.0),
      WorkspacePage.tokens when _createCustom => (760.0, 600.0),
      WorkspacePage.utilities when compactUtility => (
        utility.kind == 'mana_pool' ? 960.0 : 760.0,
        utility.kind == 'mana_pool'
            ? ((rotated ? size.height : size.width) >= 760 ? 560.0 : 650.0)
            : utility.configuration['hasAction'] == true
            ? 600.0
            : 330.0,
      ),
      WorkspacePage.utilities => (820.0, 760.0),
      WorkspacePage.rules => (900.0, 760.0),
      WorkspacePage.presets => (820.0, 760.0),
      _ => (920.0, 800.0),
    };
    final width = min(
      focusedCommander ? commanderWidth : panelWidth,
      (rotated ? size.height : size.width) - 40,
    );
    final commanderRows = CommanderSeatLayout.rowsFor(
      c.session.players,
      widget.quarterTurns,
    ).length;
    final height = min(
      _confirmation != null
          ? 460.0
          : focusedCommander
          ? commanderSetup
                ? 520.0
                : min(680.0, 196.0 + commanderRows * 184)
          : panelHeight,
      (rotated ? size.width : size.height) - 40,
    );
    final content = Center(
      child: RotatedBox(
        quarterTurns: widget.quarterTurns,
        child: SizedBox(
          key: focusedCommander
              ? const ValueKey('commander-workspace')
              : const ValueKey('context-workspace'),
          width: width,
          height: height,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 24,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 4),
                  child: Row(
                    children: [
                      if (_navigation.isNotEmpty)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              focusedCommander
                                  ? '$_seatName · ${p?.life ?? 0} life'
                                  : _seatName,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            Text(
                              _title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                      if (focusedCommander)
                        IconButton(
                          tooltip: 'Correct life separately',
                          onPressed: _working
                              ? null
                              : () => _go(WorkspacePage.player),
                          icon: const Icon(Icons.edit_note, size: 22),
                        ),
                      IconButton(
                        tooltip: 'Close workspace',
                        onPressed: _requestClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (_playerId != null &&
                    !_createCustom &&
                    _selectedDefinition == null &&
                    !compactUtility &&
                    !{
                      WorkspacePage.player,
                      WorkspacePage.rules,
                      WorkspacePage.presets,
                      WorkspacePage.counters,
                      WorkspacePage.token,
                      WorkspacePage.commanderDamage,
                      WorkspacePage.tokenStatus,
                      WorkspacePage.tokenCounters,
                      WorkspacePage.tokenSplit,
                      WorkspacePage.tokenArtwork,
                      WorkspacePage.tokenSummary,
                    }.contains(_page))
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        for (final page in [
                          WorkspacePage.tokens,
                          WorkspacePage.utilities,
                          WorkspacePage.rules,
                          WorkspacePage.presets,
                          WorkspacePage.player,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(switch (page) {
                                WorkspacePage.tokens => 'Tokens',
                                WorkspacePage.utilities => 'Utilities',
                                WorkspacePage.rules => 'Rules',
                                WorkspacePage.presets => 'Setups',
                                _ => 'Player',
                              }),
                              selected: _page == page,
                              onSelected: (_) => _go(page),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_playerId == null && _page != WorkspacePage.reset)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        for (final page in [
                          WorkspacePage.history,
                          WorkspacePage.reset,
                          WorkspacePage.dice,
                          WorkspacePage.settings,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(switch (page) {
                                WorkspacePage.history => 'History',
                                WorkspacePage.reset => 'Reset',
                                WorkspacePage.dice => 'Dice',
                                _ => 'Settings',
                              }),
                              selected: _page == page,
                              onSelected: (_) => _go(page),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 2,
                  child: _working
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                if (visibleError != null || _status != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    color: visibleError == null
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    child: Text(
                      visibleError != null
                          ? (visibleError == _directFailure
                                ? '$visibleError\nClose again to dismiss.'
                                : '$visibleError\nYour draft is retained. You can retry or close and reopen.')
                          : _status!,
                    ),
                  ),
                const Divider(height: 12),
                Expanded(
                  child: PlayerKeyboardHost(
                    enabled: !_closing && !_working && !_navigating,
                    canEdit: () => !_closing && !_working && !_navigating,
                    key: ValueKey(
                      '$_page:$_itemId:${_selectedDefinition?.id}:$_createCustom:${_confirmation?.title}',
                    ),
                    child: _content(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestClose();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Semantics(
              label: 'Close workspace',
              button: true,
              onTap: _requestClose,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _requestClose,
              ),
            ),
          ),
          AbsorbPointer(absorbing: _closing, child: content),
        ],
      ),
    );
  }
}

class _Confirmation {
  const _Confirmation(
    this.title,
    this.detail,
    this.action,
    this.button,
    this.closeOnSuccess,
  );
  final String title;
  final String detail;
  final Future<dynamic> Function() action;
  final String button;
  final bool closeOnSuccess;
}

class _WorkspaceDraft {
  const _WorkspaceDraft({
    required this.fields,
    required this.page,
    required this.itemId,
    required this.definition,
    required this.createCustom,
    required this.createTapped,
    required this.applyPresetImage,
    required this.trigger,
    required this.effect,
    required this.global,
    required this.ruleId,
    required this.ruleCount,
    required this.ruleEnabled,
    required this.outcomes,
    required this.playerCount,
    required this.emptySlot,
  });
  final Map<String, String> fields;
  final WorkspacePage page;
  final String? itemId;
  final TokenDefinition? definition;
  final bool createCustom, createTapped, applyPresetImage, global, ruleEnabled;
  final String trigger, effect;
  final String? ruleId;
  final int ruleCount, playerCount, emptySlot;
  final List<Map<String, dynamic>> outcomes;
}

class _InlineEdit {
  _InlineEdit(this.controller, this.savedValue, this.save);
  final TextEditingController controller;
  String savedValue;
  Future<dynamic> Function(String value) save;
  Future<bool>? saving;
  Timer? timer;
}

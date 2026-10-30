import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:doubling_season/models/token_definition.dart';
import '../artwork_credit.dart';
import 'package:doubling_season/database/counter_database.dart';
import 'package:doubling_season/widgets/mana/mana_text.dart';
import 'package:doubling_season/widgets/mana/mana_icons.dart';
import 'package:doubling_season/providers/rules_provider.dart'
    show TokenCreationResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/table_controller.dart';
import '../../domain/table_state.dart';
import '../../features/board_service.dart';
import '../../features/preset_service.dart';
import '../../features/ring_service.dart';
import '../../services/tablet_catalog.dart';
import 'player_keyboard.dart';
import '../table_artwork.dart';
import '../table_modal_frame.dart';
import '../game_drawer_body.dart';
import '../table_mana_icons.dart';
import '../half_stepper.dart';
import '../die_outline.dart';
import 'dice_roll.dart';
import '../commander_ledger.dart';
import '../monarch_crown.dart';
import '../custom_token_fields.dart';
import '../artwork_selection.dart';
import '../life_artwork_picker.dart';
import '../token_board_summary.dart';
import '../support_sheet.dart';

part 'token_pages.dart';
part 'game_pages.dart';
part 'dice_pages.dart';
part 'commander_page.dart';
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
  tableHub,
  archives,
  boardWipes,
  reset,
  dice,
  diceResults,
  settings,
  support,
}

/// Shared game workflows live inside the table channel. Player-local editors
/// retain their existing modal route and independent keyboard orientation.
bool isGameDrawerPage(WorkspacePage page) => switch (page) {
  WorkspacePage.tableHub ||
  WorkspacePage.history ||
  WorkspacePage.archives ||
  WorkspacePage.boardWipes ||
  WorkspacePage.reset ||
  WorkspacePage.dice ||
  WorkspacePage.diceResults ||
  WorkspacePage.settings ||
  WorkspacePage.support => true,
  _ => false,
};

/// Coordinates edge buttons with the mounted workspace's durable-save guards.
/// The shell keeps the workspace mounted until its closing animation completes.
class GameDrawerController {
  _TableWorkspaceState? _workspace;

  Future<bool> close() async => await _workspace?._requestClose() ?? false;

  Future<void> open(WorkspacePage page) async {
    assert(isGameDrawerPage(page));
    if (!isGameDrawerPage(page)) return;
    await _workspace?._go(page);
  }
}

class GameDrawerWorkspace extends StatelessWidget {
  const GameDrawerWorkspace({
    super.key,
    required this.controller,
    required this.catalog,
    required this.drawerController,
    required this.onClose,
    this.initialPage = WorkspacePage.tableHub,
  });
  final TableController controller;
  final TabletCatalog catalog;
  final GameDrawerController drawerController;
  final VoidCallback onClose;
  final WorkspacePage initialPage;

  @override
  Widget build(BuildContext context) => _TableWorkspace(
    controller: controller,
    catalog: catalog,
    initialPage: initialPage,
    quarterTurns: 0,
    drawerController: drawerController,
    onDrawerClose: onClose,
  );
}

bool _workspaceOpen = false;
final Set<_TableWorkspaceState> _presentationWorkspaces = {};

/// Preserve transient drafts and let already accepted direct commands settle.
/// Neither ordinary tap-away nor resetGame belongs in a posture transition.
Future<void> dismissTableTransientForPresentationChange(
  BuildContext context,
) async {
  await dismissPlayerKeyboardForPresentationChange();
  for (final workspace in _presentationWorkspaces.toList()) {
    await workspace._suspendForPresentation();
  }
  await WidgetsBinding.instance.endOfFrame;
  if (context.mounted) {
    // Child art/crop dialogs are transient too. Workspace routes are removed by
    // identity, so dismissing a child cannot strand or double-pop its parent.
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }
}

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
      useSafeArea: false,
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
    this.drawerController,
    this.onDrawerClose,
  });
  final GameDrawerController? drawerController;
  final VoidCallback? onDrawerClose;
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
  String? _editingPlayerCounter;
  final _counterCorrectionKey = GlobalKey();
  Future<void> _directQueue = Future.value();
  int _directPending = 0;
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
  final _restoredInlineOriginals = <String, String>{};
  bool _allowPop = false;
  bool _closing = false;
  bool _closeSaveFailed = false;
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
  final _navigation = <(WorkspacePage, String?, double, double)>[];
  final _playerScroll = ScrollController();
  final _counterScroll = ScrollController();

  void _rememberLocation() => _navigation.add((
    _page,
    _itemId,
    _playerScroll.hasClients ? _playerScroll.offset : 0,
    _counterScroll.hasClients ? _counterScroll.offset : 0,
  ));
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
  DiceRoll? _diceRoll;

  bool get _embedded => widget.drawerController != null;
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
    widget.drawerController?._workspace = this;
    _presentationWorkspaces.add(this);
    _sessionId = c.session.id;
    _sessionGeneration = c.session.generation;
    _page = widget.initialPage;
    if (_embedded && _page != WorkspacePage.tableHub) {
      _navigation.add((WorkspacePage.tableHub, null, 0, 0));
    }
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
    _restoreDraft();
    c.addListener(_refresh);
    catalog.addListener(_refresh);
    if (!catalog.loaded) catalog.load();
  }

  bool _restoringDraft = false;
  Future<void>? _presentationSuspension;
  ModalRoute<dynamic>? _ownedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownedRoute = ModalRoute.of(context);
  }

  void _restoreDraft() {
    _restoringDraft = true;
    try {
      final recovered = _failedDrafts[_draftKey];
      if (recovered != null) {
        _restoredInlineOriginals.addAll(recovered.inlineOriginals);
        for (final entry in recovered.fields.entries) {
          _field(entry.key, entry.value).text = entry.value;
          final edit = _inlineEdits[entry.key];
          final original = _restoredInlineOriginals[entry.key];
          if (edit != null && original != null) {
            edit.savedValue = original;
            _restoredInlineOriginals.remove(entry.key);
          }
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
        _customRuleOutcomes.clear();
        _customRuleOutcomes.addAll(
          recovered.outcomes.map((value) => Map<String, dynamic>.from(value)),
        );
        _resetCount = recovered.playerCount;
        _emptySlot = recovered.emptySlot;
        _selectedCounter = recovered.selectedCounter;
        _editingNumber = recovered.editingNumber;
        _editingPlayerCounter = recovered.editingPlayerCounter;
        _status = recovered.presentationChange
            ? 'Recovered your unsaved edit.'
            : 'Recovered your draft from an unsuccessful save.';
      }
    } finally {
      _restoringDraft = false;
    }
  }

  void _update(VoidCallback callback) {
    if (mounted && !_closing && !_navigating) setState(callback);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  TextEditingController _field(String id, [String initial = '']) =>
      _fields.putIfAbsent(id, () => TextEditingController(text: initial));

  void _retainDrafts({bool presentationChange = false}) {
    _failedDrafts[_draftKey] = _WorkspaceDraft(
      fields: {
        for (final entry in _fields.entries)
          if (!_inlineEdits.containsKey(entry.key) ||
              entry.value.text != _inlineEdits[entry.key]!.savedValue)
            entry.key: entry.value.text,
      },
      inlineOriginals: {
        ..._restoredInlineOriginals,
        for (final entry in _inlineEdits.entries)
          if (entry.value.controller.text != entry.value.savedValue)
            entry.key: entry.value.savedValue,
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
      selectedCounter: _selectedCounter,
      editingNumber: _editingNumber,
      editingPlayerCounter: _editingPlayerCounter,
      presentationChange: presentationChange,
    );
  }

  Future<bool> _commitInline(String id) async {
    final edit = _inlineEdits[id];
    if (edit == null) return true;
    edit.timer?.cancel();
    if (edit.saving != null) return edit.saving!;
    if (edit.controller.text == edit.savedValue) return true;
    if (edit.liveValue != edit.savedValue &&
        edit.liveValue != edit.controller.text) {
      _retainDrafts();
      if (mounted) {
        setState(
          () => _error =
              'This field changed in another view. Your draft is kept. Edit the retained field to confirm it before saving.',
        );
      }
      return false;
    }
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

  Future<bool> _requestClose() async {
    if (_closing || _working || _navigating) return false;
    setState(() => _closing = true);
    await WidgetsBinding.instance.endOfFrame;
    await _directQueue;
    final saved = await _flushInline();
    if (!mounted) return false;
    if (!saved) {
      setState(() {
        _closing = false;
        _closeSaveFailed = true;
        _error ??= 'Your changes could not be saved.';
      });
      return false;
    }
    _closeSaveFailed = false;
    if (_directFailureNeedsAcknowledgement) {
      setState(() {
        _closing = false;
        _directFailureNeedsAcknowledgement = false;
        _error = _directFailure;
      });
      return false; // Show failure once; an explicit second Close can dismiss.
    }
    _finishClose();
    return true;
  }

  Future<void> _retryCloseSave() async {
    if (_working || _closing || _navigating) return;
    setState(() => _working = true);
    final saved = await _flushInline();
    if (!mounted) return;
    setState(() {
      _working = false;
      _closeSaveFailed = !saved;
    });
  }

  Future<void> _suspendForPresentation() =>
      _presentationSuspension ??= _finishPresentationSuspension();

  Future<void> _finishPresentationSuspension() async {
    if (!mounted || _allowPop) return;
    _retainDrafts(presentationChange: true);
    for (final edit in _inlineEdits.values) {
      edit.timer?.cancel();
    }
    setState(() => _closing = true);
    await _directQueue;
    for (final edit in _inlineEdits.values) {
      if (edit.saving != null) await edit.saving;
    }
    if (mounted) {
      // A completed live save may have cleared the earlier snapshot. Retain the
      // surviving non-inline draft fields after the accepted writes settle.
      _retainDrafts(presentationChange: true);
      _finishClose();
    }
  }

  void _closeKeepingSessionDraft() {
    if (_working || _closing || _navigating) return;
    _retainDrafts();
    _finishClose();
  }

  // Completion can replace the session; do not revalidate the old target or
  // replay its inline fields after a successful reset/restore.
  void _finishClose() {
    if (!mounted || _allowPop) return;
    setState(() {
      _closing = true;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_embedded) {
        widget.onDrawerClose!();
      } else {
        final route = _ownedRoute;
        if (route != null && route.isActive) {
          if (_presentationSuspension != null) {
            Navigator.of(context).removeRoute(route);
          } else {
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  Future<void> _back() async {
    if (_working || _closing || _navigating) return;
    if (_confirmation != null) {
      setState(() => _confirmation = null);
      return;
    }
    if (_navigation.isEmpty) return;
    setState(() => _navigating = true);
    try {
      await _directQueue;
      if (!await _flushInline() || !mounted || _closing) return;
      setState(() {
        final destination = _navigation.removeLast();
        _page = destination.$1;
        _itemId = destination.$2;
        _restoreDraft();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_playerScroll.hasClients) {
            _playerScroll.jumpTo(
              destination.$3.clamp(0, _playerScroll.position.maxScrollExtent),
            );
          }
          if (_counterScroll.hasClients) {
            _counterScroll.jumpTo(
              destination.$4.clamp(0, _counterScroll.position.maxScrollExtent),
            );
          }
        });
        _confirmation = null;
      });
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  Future<void> _run(
    Future<dynamic> Function() action, {
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
      // A child picker can return after posture suspension captured its draft.
      // Its cancellation is not a successful save of the retained workspace.
      if (_presentationSuspension == null) _failedDrafts.remove(_draftKey);
      if (mounted) {
        setState(() {
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
    // Keep the display committed, but permit a queued reversal at a displayed
    // boundary (for example + then - while zero is still being saved).
    setState(() => _directPending++);
    final operation = _directQueue.then((_) async {
      try {
        if (!mounted || !_validScope) return;
        if (!await _flushInline()) {
          throw StateError('The current text edit could not be saved.');
        }
        if (!mounted || !_validScope) return;
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
      } finally {
        if (mounted) setState(() => _directPending--);
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

  Future<void> _editPlayerCounter(String playerId, String key) async {
    if (_working || _closing || _navigating || !_validScope) return;
    setState(() => _navigating = true);
    try {
      await _directQueue;
      if (!mounted || !_validScope || _closing) return;
      setState(() {
        _editingPlayerCounter = key;
        _field('counter.$key').text =
            '${c.player(playerId).counters[key] ?? 0}';
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_validScope || _closing) return;
      final editContext = _counterCorrectionKey.currentContext;
      if (editContext != null && editContext.mounted) {
        await Scrollable.ensureVisible(editContext, alignment: 1);
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
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
    if (_embedded && !isGameDrawerPage(page)) return;
    if (_page == page && _confirmation == null && _itemId == itemId) return;
    if (_working || _closing || _navigating) return;
    setState(() => _navigating = true);
    try {
      await _directQueue;
      if (!await _flushInline() || !mounted || _closing) return;
      setState(() {
        _rememberLocation();
        _page = page;
        _itemId = itemId;
        _confirmation = null;
        _error = null;
        _status = null;
        _selectedDefinition = null;
        _createCustom = false;
        _restoreDraft();
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
    String? compactButton,
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
        compactButton,
      ),
    );
  }

  Widget _button(
    String label,
    VoidCallback action, {
    IconData? icon,
    bool primary = false,
    String? compactLabel,
  }) {
    final compact = _embedded && compactLabel != null;
    final text = Text(
      compact ? compactLabel : label,
      textAlign: _embedded ? TextAlign.center : null,
    );
    final child = primary
        ? FilledButton.icon(
            style: _embedded
                ? FilledButton.styleFrom(minimumSize: const Size(44, 48))
                : null,
            onPressed: _working ? null : action,
            icon: Icon(icon ?? Icons.check, size: 18),
            label: compact ? ExcludeSemantics(child: text) : text,
          )
        : OutlinedButton.icon(
            style: _embedded
                ? OutlinedButton.styleFrom(minimumSize: const Size(44, 48))
                : null,
            onPressed: _working ? null : action,
            icon: Icon(icon ?? Icons.chevron_right, size: 18),
            label: compact ? ExcludeSemantics(child: text) : text,
          );
    return compact
        ? MergeSemantics(
            child: Semantics(label: label, child: child),
          )
        : child;
  }

  Widget _input(
    String id,
    String label, {
    String initial = '',
    bool numeric = false,
    int maxLines = 1,
    String? helper,
    Widget? prefixIcon,
    Future<dynamic> Function(String value)? onCommit,
    Future<dynamic> Function(String value, String original)?
    onCommitWithOriginal,
    bool live = false,
  }) {
    final controller = _field(id, initial);
    if (onCommitWithOriginal != null) {
      onCommit = (value) =>
          onCommitWithOriginal(value, _inlineEdits[id]!.savedValue);
    }
    if (onCommit != null && !_inlineEdits.containsKey(id)) {
      final edit = _InlineEdit(
        controller,
        _restoredInlineOriginals.remove(id) ?? initial,
        onCommit,
      )..liveValue = initial;
      _inlineEdits[id] = edit;
      var observedText = controller.text;
      controller.addListener(() {
        final changed = controller.text != observedText;
        observedText = controller.text;
        if (!changed || _restoringDraft || _closing) return;
        // Editing a retained conflict is explicit review; selection/focus alone
        // must not authorize replacing a newer board value.
        if (edit.liveValue != edit.savedValue) {
          edit.savedValue = edit.liveValue;
        }
      });
      if (live) {
        controller.addListener(() {
          edit.timer?.cancel();
          if (_restoringDraft || _closing) return;
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
    if (existing != null) existing.liveValue = initial;
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
        prefixIcon: prefixIcon,
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

  bool get _ownsCommanderControls =>
      (_page == WorkspacePage.commanderDamage ||
          _page == WorkspacePage.counters) &&
      _confirmation == null &&
      _validScope;
  double get _controlWidth =>
      (_navigation.isNotEmpty || _confirmation != null) ? 88 : 44;

  Widget _dismissControls() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_navigation.isNotEmpty || _confirmation != null)
        SizedBox(
          width: 44,
          height: 44,
          child: MergeSemantics(
            child: Semantics(
              label: 'Back',
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
        ),
      SizedBox(
        width: 44,
        height: 44,
        child: MergeSemantics(
          child: Semantics(
            label: 'Close workspace',
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _working || _navigating ? null : _requestClose,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ),
    ],
  );

  // Only the actual corner occupied by dismissal controls is reserved. There is
  // no app bar, divider, full-width heading band or full-height side rail.
  Widget _contentTop(Widget child) => _ownsCommanderControls || _embedded
      ? child
      : Padding(
          padding: EdgeInsets.only(right: _controlWidth),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: child,
          ),
        );

  Widget _list(
    List<Widget> children, {
    bool controls = true,
    ScrollController? controller,
    bool centered = false,
  }) {
    if (_embedded) {
      return GameDrawerBody(
        centered: centered,
        wideMaxContentWidth:
            _page == WorkspacePage.tableHub && _confirmation == null
            ? 640
            : null,
        scrollKey: PageStorageKey(
          'drawer-${_page.name}-${_confirmation?.title ?? "page"}',
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      children: [
        for (var index = 0; index < children.length; index++)
          if (index == 0 && controls)
            _contentTop(children[index])
          else if (children[index] is ButtonStyleButton)
            Align(alignment: Alignment.centerLeft, child: children[index])
          else
            children[index],
      ],
    );
  }

  Widget _drawerList({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) => LayoutBuilder(
    builder: (context, constraints) => GameDrawerLayout(
      body: Semantics(
        identifier: 'game-drawer-body-viewport',
        container: true,
        explicitChildNodes: true,
        child: ListView.builder(
          key: PageStorageKey('drawer-list-${_page.name}'),
          // Flexible supplies a finite viewport; sliver children stay lazy.
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
          itemCount: itemCount,
          itemBuilder: (context, index) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: min(384.0, max(0.0, constraints.maxWidth - 64)),
              child: Semantics(
                identifier: 'game-drawer-list-row-$index',
                container: true,
                explicitChildNodes: true,
                child: itemBuilder(context, index),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _drawerHeader() => Semantics(
    identifier: 'game-drawer-header',
    container: true,
    explicitChildNodes: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: _navigation.isEmpty && _confirmation == null
                ? null
                : MergeSemantics(
                    child: Semantics(
                      label: 'Back',
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _title,
                key: const ValueKey('game-drawer-title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: MergeSemantics(
              child: Semantics(
                label: 'Close workspace',
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _working || _navigating ? null : _requestClose,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _balancedActions(List<Widget> actions) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 280
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: actions[index]),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                actions[index],
              ],
            ],
          ),
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
            onDecrease:
                _working ||
                    (_directPending == 0 && minimum != null && value <= minimum)
                ? null
                : minus,
            onIncrease:
                _working ||
                    (_directPending == 0 && maximum != null && value >= maximum)
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
    _presentationWorkspaces.remove(this);
    if (widget.drawerController?._workspace == this) {
      widget.drawerController?._workspace = null;
    }
    c.removeListener(_refresh);
    catalog.removeListener(_refresh);
    for (final edit in _inlineEdits.values) {
      edit.timer?.cancel();
    }
    for (final field in _fields.values) {
      field.dispose();
    }
    _playerScroll.dispose();
    _counterScroll.dispose();
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
    WorkspacePage.player => 'Player customization',
    WorkspacePage.commanderDamage ||
    WorkspacePage.counters => 'Damage & counters',
    WorkspacePage.history => 'Game history',
    WorkspacePage.reset => 'New game',
    WorkspacePage.tableHub => 'Table tools',
    WorkspacePage.archives => 'Archives',
    WorkspacePage.boardWipes => 'Board wipes',
    WorkspacePage.dice => 'Dice',
    WorkspacePage.diceResults => 'Dice results',
    WorkspacePage.settings => 'Table settings',
    WorkspacePage.support => 'Support',
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
        _balancedActions([
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
            compactLabel: confirmation.compactButton,
          ),
        ]),
      ], centered: true);
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
      WorkspacePage.commanderDamage => _focusedCommanderPage(),
      WorkspacePage.counters => _focusedCommanderPage(),
      WorkspacePage.history => _historyPage(),
      WorkspacePage.reset => _resetPage(),
      WorkspacePage.tableHub => _tableHubPage(),
      WorkspacePage.archives => _archivesPage(),
      WorkspacePage.boardWipes => _boardWipesPage(),
      WorkspacePage.dice => _dicePage(),
      WorkspacePage.diceResults => _diceResultsPage(),
      WorkspacePage.settings => _settingsPage(),
      WorkspacePage.support => TableSupportContent(embedded: _embedded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleError = _directFailure ?? _error;
    final focusedCommander = _ownsCommanderControls;
    final media = MediaQuery.of(context);
    final localBounds = TableModalFrame.localSize(
      Size(
        media.size.width - media.padding.horizontal,
        media.size.height - media.padding.vertical,
      ),
      widget.quarterTurns,
    );
    final surface = PlayerKeyboardHost(
      enabled: !_closing && !_working && !_navigating,
      canEdit: () => !_closing && !_working && !_navigating,
      onClose: _requestClose,
      key: ValueKey(
        '$_page:$_itemId:${_selectedDefinition?.id}:$_createCustom:${_confirmation?.title}:$_closeSaveFailed',
      ),
      child: Column(
        children: [
          SizedBox(
            height: 2,
            child: _working
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          if (visibleError != null || _status != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: _embedded ? 32 : 20,
                vertical: 9,
              ),
              color: visibleError == null
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Text(
                visibleError != null
                    ? (_closeSaveFailed
                          ? '$visibleError\nYour draft is retained only for this app session; it is not saved to storage.'
                          : visibleError == _directFailure
                          ? '$visibleError\nClose again to dismiss.'
                          : visibleError)
                    : _status!,
              ),
            ),
          if (_closeSaveFailed)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _embedded ? 32 : 20),
              child: Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _working ? null : _retryCloseSave,
                    child: const Text('Retry'),
                  ),
                  OutlinedButton(
                    onPressed: _working ? null : _closeKeepingSessionDraft,
                    child: const Text('Close and keep draft'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _embedded
                ? GameDrawerHeaderScope(
                    header: _drawerHeader(),
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label: _title,
                      child: _content(),
                    ),
                  )
                : focusedCommander
                ? Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: _title,
                    child: _content(),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: ClipPath(
                          clipper: _WorkspaceControlCutout(_controlWidth + 8),
                          child: Semantics(
                            container: true,
                            explicitChildNodes: true,
                            namesRoute: true,
                            label: _title,
                            child: _content(),
                          ),
                        ),
                      ),
                      Positioned(top: 6, right: 8, child: _dismissControls()),
                    ],
                  ),
          ),
        ],
      ),
    );
    if (_embedded) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (_navigation.isNotEmpty || _confirmation != null) {
              _back();
            } else {
              _requestClose();
            }
          }
        },
        child: Material(
          key: const ValueKey('game-drawer-workspace'),
          color: Theme.of(context).colorScheme.surface,
          child: Semantics(
            identifier: 'game-drawer-workspace',
            container: true,
            explicitChildNodes: true,
            child: AbsorbPointer(absorbing: _closing, child: surface),
          ),
        ),
      );
    }
    final content = TableModalFrame(
      quarterTurns: widget.quarterTurns,
      preferredWidth: focusedCommander ? 620 : 720,
      preferredHeight: focusedCommander
          ? _combinedContentHeight(min(620.0, localBounds.width)) +
                (visibleError == null && _status == null ? 0 : 64)
          : 640,
      surfaceKey: focusedCommander
          ? const ValueKey('commander-workspace')
          : const ValueKey('context-workspace'),
      child: surface,
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
            // A full-window actionable semantics node can sit above dialog
            // controls in Flutter web's DOM hit order after a state update.
            // Outside pointer taps still dismiss; assistive technology uses the
            // visible 44px Close button (or the focused keyboard's Close).
            child: ExcludeSemantics(
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
    this.compactButton,
  );
  final String? compactButton;
  final String title;
  final String detail;
  final Future<dynamic> Function() action;
  final String button;
  final bool closeOnSuccess;
}

class _WorkspaceDraft {
  const _WorkspaceDraft({
    required this.fields,
    required this.inlineOriginals,
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
    this.selectedCounter,
    this.editingNumber,
    this.editingPlayerCounter,
    this.presentationChange = false,
  });
  final String? selectedCounter, editingNumber, editingPlayerCounter;
  final bool presentationChange;
  final Map<String, String> fields;
  final Map<String, String> inlineOriginals;
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
  _InlineEdit(this.controller, this.savedValue, this.save)
    : liveValue = savedValue;
  final TextEditingController controller;
  String savedValue;
  String liveValue;
  Future<dynamic> Function(String value) save;
  Future<bool>? saving;
  Timer? timer;
}

class _WorkspaceControlCutout extends CustomClipper<Path> {
  const _WorkspaceControlCutout(this.width);
  final double width;
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - width, 0)
    ..lineTo(size.width - width, 52)
    ..lineTo(size.width, 52)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(_WorkspaceControlCutout old) => old.width != width;
}

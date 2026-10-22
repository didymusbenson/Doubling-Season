import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/providers/rules_provider.dart' show TokenCreationResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/table_controller.dart';
import '../../domain/table_state.dart';
import '../../features/board_service.dart';
import '../../features/preset_service.dart';
import '../../services/tablet_catalog.dart';
import 'player_keyboard.dart';
import '../../services/tablet_media_store.dart';
import '../table_artwork.dart';
import '../support_sheet.dart';

part 'token_pages.dart';
part 'game_pages.dart';
part 'library_pages.dart';

enum WorkspacePage { tokens, token, utilities, rules, presets, player, commanderDamage, counters, history, reset, dice, settings }

bool _workspaceOpen = false;
final Map<String, Map<String, String>> _failedDrafts = {};

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
      barrierDismissible: true,
      barrierLabel: 'Close workspace',
      barrierColor: Colors.black.withValues(alpha: .76),
      useRootNavigator: true,
      builder: (context) => _TableWorkspace(
        controller: controller, catalog: catalog, seatId: seatId,
        quarterTurns: quarterTurns, initialPage: initialPage, itemId: itemId,
      ),
    );
  } finally {
    _workspaceOpen = false;
  }
}

class _TableWorkspace extends StatefulWidget {
  const _TableWorkspace({required this.controller, required this.catalog, required this.initialPage, required this.quarterTurns, this.seatId, this.itemId});
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
  late BoardService _board;
  late PresetService _presets;
  late String _sessionId;
  String? _playerId;
  String? _itemId;
  final _fields = <String, TextEditingController>{};
  String? _error;
  String? _status;
  bool _working = false;
  bool _createCustom = false;
  bool _createTapped = false;
  bool _applyPresetImage = false;
  String _tokenTab = 'all';
  Category? _category;
  TokenDefinition? _selectedDefinition;
  _Confirmation? _confirmation;
  final _navigation = <WorkspacePage>[];
  int _resetCount = 4;
  int _emptySlot = 3;
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
  String get _draftKey => '$_sessionId:${_playerId ?? 'table'}';
  bool get _validScope => c.session.id == _sessionId && (_playerId == null || p != null);

  @override
  void initState() {
    super.initState();
    _sessionId = c.session.id;
    _page = widget.initialPage;
    _itemId = widget.itemId;
    for (final player in c.session.players) {
      if (player.seatId == widget.seatId || player.id == widget.seatId) _playerId = player.id;
    }
    _resetCount = c.session.players.length;
    _board = BoardService(c, catalog);
    _presets = PresetService(c, catalog);
    final recovered = _failedDrafts[_draftKey];
    if (recovered != null) {
      for (final entry in recovered.entries) { _field(entry.key, entry.value); }
      _status = 'Recovered your draft from an unsuccessful save.';
    }
    c.addListener(_refresh);
    catalog.addListener(_refresh);
    if (!catalog.loaded) catalog.load();
  }

  void _update(VoidCallback callback) => setState(callback);

  void _refresh() { if (mounted) setState(() {}); }

  TextEditingController _field(String id, [String initial = '']) => _fields.putIfAbsent(id, () => TextEditingController(text: initial));

  void _retainDrafts() {
    _failedDrafts[_draftKey] = {for (final entry in _fields.entries) entry.key: entry.value.text};
  }

  Future<void> _run(Future<dynamic> Function() action, {String? success, VoidCallback? after}) async {
    if (_working || !_validScope) return;
    setState(() { _working = true; _error = null; _status = null; });
    try {
      final result = await action();
      if (result == false) throw StateError(c.error ?? 'The change could not be saved.');
      _failedDrafts.remove(_draftKey);
      if (mounted) setState(() { _status = success; after?.call(); });
    } catch (error) {
      _retainDrafts();
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  int _integer(String field, {int min = -1000000000, int max = 1000000000}) {
    final text = _field(field).text.trim();
    if (!RegExp(r'^-?[0-9]+$').hasMatch(text)) throw const FormatException('Enter a whole number, with a minus sign only for negative values.');
    final value = int.tryParse(text);
    if (value == null || value < min || value > max) throw FormatException('Enter a number between $min and $max.');
    return value;
  }

  void _go(WorkspacePage page, {String? itemId}) {
    setState(() {
      _navigation.add(_page);
      _page = page; _itemId = itemId; _confirmation = null; _error = null; _status = null;
      _selectedDefinition = null; _createCustom = false;
    });
  }

  void _confirm(String title, String detail, Future<dynamic> Function() action, {String button = 'Confirm'}) {
    setState(() => _confirmation = _Confirmation(title, detail, action, button));
  }

  Widget _button(String label, VoidCallback action, {IconData? icon, bool primary = false}) => primary
      ? FilledButton.icon(onPressed: _working ? null : action, icon: Icon(icon ?? Icons.check, size: 18), label: Text(label))
      : OutlinedButton.icon(onPressed: _working ? null : action, icon: Icon(icon ?? Icons.chevron_right, size: 18), label: Text(label));

  Widget _input(String id, String label, {String initial = '', bool numeric = false, int maxLines = 1, String? helper}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: PlayerField(controller: _field(id, initial), label: label, numeric: numeric, maxLines: maxLines, helperText: helper),
  );

  Widget _section(String title, {String? detail}) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (detail != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail)),
    ]),
  );

  Widget _list(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 24), children: children);

  Widget _art(String? url, {double width = 72, double height = 72}) => SizedBox(
    width: width, height: height,
    child: TableArtwork(url: url, placeholder: const Icon(Icons.image_outlined)),
  );

  Future<String?> _pickArtwork() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) throw StateError('This image could not be read. Please choose another image.');
    if (bytes.length > 8 * 1024 * 1024) throw const FormatException('Choose an image smaller than 8 MB.');
    return TabletMediaStore.save(bytes);
  }

  Widget _stepper(String label, int value, VoidCallback minus, VoidCallback plus, {String? detail, VoidCallback? edit}) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), if (detail != null) Text(detail, style: Theme.of(context).textTheme.bodySmall)])),
      IconButton(tooltip: 'Decrease $label', onPressed: _working ? null : minus, icon: const Icon(Icons.remove)),
      TextButton(onPressed: edit, child: Text('$value', style: Theme.of(context).textTheme.titleLarge)),
      IconButton(tooltip: 'Increase $label', onPressed: _working ? null : plus, icon: const Icon(Icons.add)),
    ])),
  );

  @override
  void dispose() {
    c.removeListener(_refresh); catalog.removeListener(_refresh);
    for (final field in _fields.values) { field.dispose(); }
    super.dispose();
  }

  String get _title => switch (_page) {
    WorkspacePage.tokens => 'Add tokens', WorkspacePage.token => 'Token details',
    WorkspacePage.utilities => 'Utilities', WorkspacePage.rules => 'Rules',
    WorkspacePage.presets => 'Saved setups', WorkspacePage.player => 'Life & player',
    WorkspacePage.commanderDamage => 'Commander damage', WorkspacePage.counters => 'Player counters',
    WorkspacePage.history => 'Game history', WorkspacePage.reset => 'Reset & restore',
    WorkspacePage.dice => 'Dice', WorkspacePage.settings => 'Table settings',
  };

  Widget _content() {
    if (!_validScope) return _list([_section('This game has changed', detail: 'Close this workspace and reopen the current game. Your previous target will not be reassigned.')]);
    final confirmation = _confirmation;
    if (confirmation != null) return _list([
      _section(confirmation.title, detail: confirmation.detail),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 8, children: [
        _button('Cancel', () => setState(() => _confirmation = null), icon: Icons.close),
        _button(confirmation.button, () => _run(confirmation.action, success: 'Saved.', after: () => _confirmation = null), primary: true),
      ]),
    ]);
    return switch (_page) {
      WorkspacePage.tokens => _tokensPage(), WorkspacePage.token => _tokenPage(),
      WorkspacePage.utilities => _utilitiesPage(), WorkspacePage.rules => _rulesPage(),
      WorkspacePage.presets => _presetsPage(), WorkspacePage.player => _playerPage(),
      WorkspacePage.commanderDamage => _commanderPage(), WorkspacePage.counters => _countersPage(),
      WorkspacePage.history => _historyPage(), WorkspacePage.reset => _resetPage(),
      WorkspacePage.dice => _dicePage(), WorkspacePage.settings => _settingsPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rotated = widget.quarterTurns.isOdd;
    final width = min(1050.0, (rotated ? size.height : size.width) - 40);
    final height = min(940.0, (rotated ? size.width : size.height) - 40);
    return Center(child: RotatedBox(quarterTurns: widget.quarterTurns, child: SizedBox(
      width: width, height: height,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 24,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(22),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 10, 4), child: Row(children: [
            if (_navigation.isNotEmpty) IconButton(tooltip: 'Back', onPressed: () => setState(() { _page = _navigation.removeLast(); _confirmation = null; }), icon: const Icon(Icons.arrow_back)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_seatName, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
              Text(_title, style: Theme.of(context).textTheme.headlineSmall),
            ])),
            IconButton(tooltip: 'Close workspace', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ])),
          if (_playerId != null)
            SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
              for (final page in [WorkspacePage.tokens, WorkspacePage.utilities, WorkspacePage.rules, WorkspacePage.presets, WorkspacePage.player])
                Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(switch (page) { WorkspacePage.tokens => 'Tokens', WorkspacePage.utilities => 'Utilities', WorkspacePage.rules => 'Rules', WorkspacePage.presets => 'Setups', _ => 'Player' }), selected: _page == page, onSelected: (_) => _go(page))),
            ])),
          if (_working) const LinearProgressIndicator(minHeight: 2),
          if (_error != null || _status != null)
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9), color: _error == null ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.errorContainer, child: Text(_error != null ? '$_error\nYour draft is retained. You can retry or close and reopen.' : _status!)),
          const Divider(height: 12),
          Expanded(child: PlayerKeyboardHost(key: ValueKey('$_page:${_confirmation?.title}'), child: _content())),
        ]),
      ),
    )));
  }
}

class _Confirmation {
  const _Confirmation(this.title, this.detail, this.action, this.button);
  final String title;
  final String detail;
  final Future<dynamic> Function() action;
  final String button;
}

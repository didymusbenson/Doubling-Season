import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

bool _playerKeyboardEditorOpen = false;

/// Edit the field on its board object while the single player-facing keyboard
/// intercepts the whole table. A false result leaves the caller's mirrored draft
/// intact so a failed save can be resumed from the same inline field. A supplied
/// controller belongs to the inline field; its text and selection are preserved
/// on opening, and this route never disposes it.
Future<bool> showPlayerKeyboardEditor(
  BuildContext context, {
  required String title,
  required String value,
  TextEditingController? controller,
  bool numeric = false,
  bool multiline = false,
  int quarterTurns = 0,
  required ValueChanged<String> onChanged,
  required Future<void> Function(String) onCommit,
}) async {
  if (_playerKeyboardEditorOpen) return false;
  _playerKeyboardEditorOpen = true;
  try {
    return await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: .16),
          builder: (_) => _PlayerKeyboardEditor(
            title: title,
            value: value,
            controller: controller,
            numeric: numeric,
            multiline: multiline,
            quarterTurns: quarterTurns,
            onChanged: onChanged,
            onCommit: onCommit,
          ),
        ) ??
        false;
  } finally {
    _playerKeyboardEditorOpen = false;
  }
}

class _PlayerKeyboardEditor extends StatefulWidget {
  const _PlayerKeyboardEditor({
    required this.title,
    required this.value,
    this.controller,
    required this.numeric,
    required this.multiline,
    required this.quarterTurns,
    required this.onChanged,
    required this.onCommit,
  });

  final String title, value;
  final TextEditingController? controller;
  final bool numeric, multiline;
  final int quarterTurns;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String) onCommit;

  @override
  State<_PlayerKeyboardEditor> createState() => _PlayerKeyboardEditorState();
}

class _PlayerKeyboardEditorState extends State<_PlayerKeyboardEditor> {
  late final TextEditingController _controller;
  final _keyboard = GlobalKey<_PlayerKeyboardHostState>();
  bool _saving = false;
  bool _allowPop = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.value);
    if (!_controller.selection.isValid) {
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _keyboard.currentState?.activateField(
        _controller,
        widget.title,
        widget.numeric,
        widget.multiline,
        _commit,
      );
    });
  }

  void _changed() => widget.onChanged(_controller.text);

  void _close(bool committed) {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(committed);
    });
  }

  Future<bool> _commit() async {
    if (_saving || _allowPop) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onCommit(_controller.text);
      _close(true);
      return true;
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _tapAway() {
    if (_saving || _allowPop) return;
    if (_error != null) {
      _close(false);
    } else {
      _commit();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _tapAway();
    },
    child: RotatedBox(
      quarterTurns: widget.quarterTurns,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PlayerKeyboardHost(
                key: _keyboard,
                enabled: !_saving && !_allowPop,
                canEdit: () => !_saving && !_allowPop,
                showValue: true,
                child: Semantics(
                  label: 'Finish editing ${widget.title}',
                  button: true,
                  onTap: _tapAway,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _tapAway,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_error\nYour draft is kept on the token. Retry or close and resume it later.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _commit(),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () => _close(false),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// One input surface, contained in and rotated with the active workspace.
class PlayerKeyboardHost extends StatefulWidget {
  const PlayerKeyboardHost({
    super.key,
    required this.child,
    this.enabled = true,
    this.canEdit,
    this.showValue = false,
    this.onClose,
  });
  final Widget child;
  final bool enabled;
  final bool showValue;
  final VoidCallback? onClose;
  final bool Function()? canEdit;

  @override
  State<PlayerKeyboardHost> createState() => _PlayerKeyboardHostState();
}

class _PlayerKeyboardHostState extends State<PlayerKeyboardHost>
    with WidgetsBindingObserver {
  final FocusNode _hardwareFocus = FocusNode(debugLabel: 'Player keyboard');
  final FocusNode _draftFocus = FocusNode(debugLabel: 'Inline token draft');
  final _draftEditable = GlobalKey<EditableTextState>();
  final _keysScroll = ScrollController();
  TextEditingController? _controller;
  Future<bool> Function()? _onExit;
  bool _numeric = false;
  bool _multiline = false;
  bool _shift = false;
  bool _symbols = false;
  String _label = '';
  bool _selecting = false;
  bool _editingMenu = false;
  String? _clipboardError;
  Timer? _deleteTimer;
  bool _deleteHeld = false;
  bool get _editable => widget.enabled && (widget.canEdit?.call() ?? true);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_hardwareHandler);
    WidgetsBinding.instance.addObserver(this);
  }

  bool _hardwareHandler(KeyEvent event) =>
      _editable &&
      _controller != null &&
      _onKey(_hardwareFocus, event) == KeyEventResult.handled;

  Future<bool> activateField(
    TextEditingController controller,
    String label,
    bool numeric,
    bool multiline,
    Future<bool> Function()? onExit,
  ) async {
    if (!_editable) return false;
    if (_controller != controller && await _onExit?.call() == false) {
      return false;
    }
    if (!mounted) return false;
    if (_controller != controller) {
      _stopDelete();
      _shift = false;
      _symbols = false;
      _selecting = false;
      _editingMenu = false;
      _clipboardError = null;
      _controller?.removeListener(_revealDraft);
      controller.addListener(_revealDraft);
    }
    setState(() {
      _controller = controller;
      _onExit = onExit;
      _label = label;
      _numeric = numeric;
      _multiline = multiline;
    });
    _hardwareFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _controller == controller &&
          _draftEditable.currentState != null) {
        _draftFocus.requestFocus();
        _revealDraft();
      }
    });
    return true;
  }

  Future<void> finishField([TextEditingController? expected]) async {
    if (expected != null && expected != _controller) return;
    _stopDelete();
    final captured = _controller;
    if (await _onExit?.call() == false) return;
    if (!mounted || captured != _controller) return;
    _controller?.removeListener(_revealDraft);
    setState(() {
      _controller = null;
      _onExit = null;
    });
  }

  void _revealDraft() {
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller == null || controller != _controller) return;
      final offset = controller.selection.extentOffset;
      if (offset < 0 || offset > controller.text.length) return;
      _draftEditable.currentState?.bringIntoView(TextPosition(offset: offset));
    });
  }

  void _focusDraft() {
    if (_draftEditable.currentState != null) _draftFocus.requestFocus();
  }

  void _replace(String value) {
    if (!_editable) return;
    _focusDraft();
    final c = _controller;
    if (c == null) return;
    final selection = c.selection;
    final start = selection.isValid ? selection.start : c.text.length;
    final end = selection.isValid ? selection.end : c.text.length;
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  int _previousBoundary(String text, int offset) {
    var boundary = 0;
    for (final character in text.characters) {
      final next = boundary + character.length;
      if (next >= offset) return boundary;
      boundary = next;
    }
    return boundary;
  }

  int _nextBoundary(String text, int offset) {
    var boundary = 0;
    for (final character in text.characters) {
      boundary += character.length;
      if (boundary > offset) return boundary;
    }
    return text.length;
  }

  void _delete({bool forward = false}) {
    if (!_editable) return;
    _focusDraft();
    final c = _controller;
    if (c == null || c.text.isEmpty) return;
    if (c.selection.isValid && !c.selection.isCollapsed) {
      _replace('');
      return;
    }
    final offset = c.selection.isValid
        ? c.selection.extentOffset
        : c.text.length;
    final start = forward ? offset : _previousBoundary(c.text, offset);
    final end = forward ? _nextBoundary(c.text, offset) : offset;
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }

  void _move(bool forward, {bool extend = false}) {
    if (!_editable) return;
    _focusDraft();
    final c = _controller;
    if (c == null) return;
    final selection = c.selection;
    final old = selection.isValid ? selection.extentOffset : c.text.length;
    final next = forward
        ? _nextBoundary(c.text, old)
        : _previousBoundary(c.text, old);
    c.selection = extend
        ? TextSelection(
            baseOffset: selection.isValid ? selection.baseOffset : old,
            extentOffset: next,
          )
        : TextSelection.collapsed(offset: next);
  }

  void _clipboardFailure(String message) {
    if (mounted) {
      setState(() => _clipboardError = message);
      _revealKeyboardContext();
    }
  }

  Future<void> _paste() async {
    if (!_editable) return;
    final captured = _controller;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || captured != _controller || !_editable) return;
      if (data?.text == null || data!.text!.isEmpty) {
        _clipboardFailure(
          'No text is available to paste. Copy text and try again.',
        );
        return;
      }
      setState(() => _clipboardError = null);
      _replace(data.text!);
    } catch (_) {
      if (mounted && captured == _controller) {
        _clipboardFailure(
          'Paste is unavailable. Allow clipboard access or type the text.',
        );
      }
    }
  }

  Future<void> _copy({bool cut = false}) async {
    if (!_editable) return;
    final c = _controller;
    if (c == null) return;
    final value = c.value;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    try {
      await Clipboard.setData(
        ClipboardData(text: selection.textInside(value.text)),
      );
      if (!mounted || c != _controller || !_editable) return;
      setState(() => _clipboardError = null);
      // Never cut a newer draft or a selection changed during clipboard access.
      if (cut && c.value == value) _replace('');
    } catch (_) {
      if (mounted && c == _controller) {
        _clipboardFailure('Clipboard access failed. Your text is unchanged.');
      }
    }
  }

  void _revealKeyboardContext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _keysScroll.hasClients) _keysScroll.jumpTo(0);
    });
  }

  void _toggleEditingMenu() {
    setState(() => _editingMenu = !_editingMenu);
    _revealKeyboardContext();
  }

  void _showEditingMenu() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller != null && !_editingMenu) {
        setState(() => _editingMenu = true);
        _revealKeyboardContext();
      }
    });
  }

  void _stopDelete() {
    _deleteTimer?.cancel();
    _deleteTimer = null;
  }

  void _startDelete() {
    _stopDelete();
    _deleteHeld = true;
    _delete();
    _deleteTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!_editable || _controller == null) {
        _stopDelete();
      } else {
        _delete();
      }
    });
  }

  @override
  void didUpdateWidget(PlayerKeyboardHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editable) _stopDelete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopDelete();
  }

  void _selectAll() {
    _focusDraft();
    final c = _controller;
    if (c != null) {
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    }
  }

  bool _isEditingKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return {
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyX,
        LogicalKeyboardKey.keyV,
      }.contains(key);
    }
    return {
          LogicalKeyboardKey.backspace,
          LogicalKeyboardKey.delete,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.escape,
        }.contains(key) ||
        (event.character?.runes.every((c) => c >= 32) ?? false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_controller == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final shortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (shortcut) {
      if (key == LogicalKeyboardKey.keyA) {
        _selectAll();
      } else if (key == LogicalKeyboardKey.keyC) {
        _copy();
      } else if (key == LogicalKeyboardKey.keyX) {
        _copy(cut: true);
      } else if (key == LogicalKeyboardKey.keyV) {
        _paste();
      } else {
        return KeyEventResult.ignored;
      }
    } else if (key == LogicalKeyboardKey.backspace) {
      _delete();
    } else if (key == LogicalKeyboardKey.delete) {
      _delete(forward: true);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _move(
        key == LogicalKeyboardKey.arrowRight,
        extend: HardwareKeyboard.instance.isShiftPressed,
      );
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_multiline) {
        _replace('\n');
      } else {
        finishField();
      }
    } else if (key == LogicalKeyboardKey.escape) {
      finishField();
    } else if (event.character != null &&
        event.character!.runes.every((c) => c >= 32)) {
      _replace(event.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _stopDelete();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_hardwareHandler);
    _controller?.removeListener(_revealDraft);
    _hardwareFocus.dispose();
    _draftFocus.dispose();
    _keysScroll.dispose();
    super.dispose();
  }

  Widget _key(
    String text, {
    VoidCallback? action,
    double? width,
    String? semantics,
    IconData? icon,
    bool selected = false,
    bool backspace = false,
  }) {
    void perform() {
      if (!_editable) return;
      if (backspace && _deleteHeld) {
        _deleteHeld = false;
        return;
      }
      if (action != null) {
        action();
      } else {
        _replace(_shift ? text.toUpperCase() : text);
        if (_shift && RegExp(r'[a-z]').hasMatch(text)) {
          setState(() => _shift = false);
        }
      }
    }

    Widget button = Semantics(
      label: semantics ?? text,
      button: true,
      enabled: _editable,
      selected: selected,
      onTap: _editable ? perform : null,
      child: ExcludeSemantics(
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            maximumSize: const Size(double.infinity, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _editable ? perform : null,
          child: icon == null
              ? Text(
                  action == null && _shift ? text.toUpperCase() : text,
                  maxLines: 1,
                )
              : Icon(icon, size: 22),
        ),
      ),
    );
    if (backspace) {
      button = Listener(
        onPointerDown: (_) => _deleteHeld = false,
        onPointerUp: (_) => _stopDelete(),
        onPointerCancel: (_) => _stopDelete(),
        child: GestureDetector(
          onLongPressStart: _editable ? (_) => _startDelete() : null,
          onLongPressEnd: (_) => _stopDelete(),
          onLongPressCancel: _stopDelete,
          child: button,
        ),
      );
    }
    return SizedBox(
      width: width,
      height: 48,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: width != null && width >= 48 ? 2 : .25,
          vertical: 2,
        ),
        child: button,
      ),
    );
  }

  Widget _draft({bool compact = false}) => Padding(
    padding: EdgeInsets.fromLTRB(4, 0, 4, compact ? 0 : 6),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 4 : 8,
        ),
        child: EditableText(
          key: _draftEditable,
          controller: _controller!,
          focusNode: _draftFocus,
          readOnly: true,
          // Preserve explicit selection when a software key returns focus.
          selectAllOnFocus: false,
          showCursor: true,
          keyboardType: TextInputType.none,
          maxLines: compact ? 1 : (_multiline ? 2 : 1),
          style: Theme.of(context).textTheme.bodyLarge!,
          cursorColor: Theme.of(context).colorScheme.primary,
          backgroundCursorColor: Colors.grey,
          selectionColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .3),
          selectionControls: materialTextSelectionHandleControls,
          contextMenuBuilder: (_, state) {
            _showEditingMenu();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (state.mounted) state.hideToolbar(false);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  Widget _menu() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _controller!,
    builder: (context, value, _) {
      final selected = value.selection.isValid && !value.selection.isCollapsed;
      final items = <ContextMenuButtonItem>[
        if (selected)
          ContextMenuButtonItem(
            type: ContextMenuButtonType.copy,
            onPressed: _editable ? _copy : null,
          ),
        if (selected)
          ContextMenuButtonItem(
            type: ContextMenuButtonType.cut,
            onPressed: _editable ? () => _copy(cut: true) : null,
          ),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: _editable ? _paste : null,
        ),
        if (value.text.isNotEmpty)
          ContextMenuButtonItem(
            type: ContextMenuButtonType.selectAll,
            onPressed: _editable ? _selectAll : null,
          ),
      ];
      return Material(
        key: const ValueKey('player-editing-toolbar'),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Wrap(
          alignment: WrapAlignment.center,
          children:
              AdaptiveTextSelectionToolbar.getAdaptiveButtons(context, items)
                  .map(
                    (button) => ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: button,
                    ),
                  )
                  .toList(),
        ),
      );
    },
  );

  Widget _keyBank(double availableWidth) {
    final rows = _numeric
        ? ['12345', '67890']
        : _symbols
        ? ['1234567890', '@#%&*()+-=', '.,!?/:;"\'']
        : ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    final width = math.max(availableWidth, _numeric ? 267.0 : 445.0);
    final letterWidth = width / (_numeric ? 5 : 10);
    final commands = <Widget>[
      if (!_numeric)
        _key(
          _symbols ? 'ABC' : '123',
          width: 60,
          action: () => setState(() => _symbols = !_symbols),
        ),
      if (!_numeric)
        _key(
          'Shift',
          width: 44.5,
          icon: Icons.arrow_upward,
          semantics: 'Shift',
          selected: _shift,
          action: () => setState(() => _shift = !_shift),
        ),
      if (_numeric)
        _key('−', width: 44.5, icon: Icons.remove, action: () => _replace('-')),
      _key(
        'Move cursor left',
        width: 44.5,
        icon: Icons.keyboard_arrow_left,
        semantics: 'Move cursor left',
        action: () => _move(false, extend: _selecting),
      ),
      if (!_numeric)
        _key(
          'Space',
          width: math.max(70, width - (_multiline ? 338 : 293)),
          action: () => _replace(' '),
        ),
      if (_numeric) _key('/', width: 44.5, action: () => _replace('/')),
      if (_multiline)
        _key(
          'Return',
          width: 44.5,
          icon: Icons.keyboard_return,
          semantics: 'Return',
          action: () => _replace('\n'),
        ),
      _key(
        'Move cursor right',
        width: 44.5,
        icon: Icons.keyboard_arrow_right,
        semantics: 'Move cursor right',
        action: () => _move(true, extend: _selecting),
      ),
      _key(
        'Delete previous character',
        width: 55,
        icon: Icons.backspace_outlined,
        semantics: 'Delete previous character',
        backspace: true,
        action: _delete,
      ),
      _key(
        'Extend selection',
        width: 44.5,
        icon: Icons.select_all,
        semantics: 'Extend selection',
        selected: _selecting,
        action: () => setState(() => _selecting = !_selecting),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.characters
                    .map((c) => _key(c, width: letterWidth))
                    .toList(),
              ),
            Wrap(alignment: WrapAlignment.center, children: commands),
          ],
        ),
      ),
    );
  }

  Widget _focusedKeyboard() => TextFieldTapRegion(
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Semantics(label: _label, child: _draft(compact: true)),
          ),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Select all',
                  onPressed: _editable ? _selectAll : null,
                  icon: const Icon(Icons.select_all),
                ),
                IconButton(
                  tooltip: 'Text editing actions',
                  onPressed: _editable ? _toggleEditingMenu : null,
                  icon: const Icon(Icons.more_horiz),
                ),
                IconButton(
                  tooltip: 'Paste',
                  onPressed: _editable ? _paste : null,
                  icon: const Icon(Icons.content_paste, size: 20),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _editable ? finishField : null,
                  child: const Text('Done'),
                ),
                if (widget.onClose != null)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _editable ? widget.onClose : null,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _clipboardError != null
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          _clipboardError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _clipboardError = null),
                          child: const Text('Continue typing'),
                        ),
                      ],
                    ),
                  )
                : _editingMenu
                ? Column(
                    children: [
                      _menu(),
                      TextButton(
                        onPressed: () => setState(() => _editingMenu = false),
                        child: const Text('Continue typing'),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.topCenter,
                      child: _keyBank(constraints.maxWidth),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _formPane({bool focused = false}) => Expanded(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: focused, child: widget.child),
        if (focused) _focusedKeyboard(),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => _InputScope(
    activate: activateField,
    finish: finishField,
    canEdit: () => _editable,
    showEditingMenu: _showEditingMenu,
    child: Focus(
      focusNode: _hardwareFocus,
      onKeyEvent: (_, event) => _controller != null && _isEditingKey(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_controller == null) return Column(children: [_formPane()]);
          final short = constraints.maxHeight < 400;
          if (short) {
            // Keep the exact form and its scroll/selection state mounted while
            // dedicating the unchanged shell to typing. Done restores the form.
            return Column(children: [_formPane(focused: true)]);
          }
          // Reserve useful space for the form. The key bank scrolls inside its
          // own clearly bounded region; neither keys nor the outer shell shrink.
          final keyboardHeight = math.min(
            constraints.maxHeight - 96,
            widget.showValue ? 340.0 : 244.0,
          );
          return Column(
            children: [
              _formPane(),
              SizedBox(
                height: keyboardHeight,
                child: TextFieldTapRegion(
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child:
                                      ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: _controller!,
                                        builder: (context, value, _) => Text(
                                          _label,
                                          key: const ValueKey(
                                            'player-keyboard-context',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Select all',
                                onPressed: _editable ? _selectAll : null,
                                icon: const Icon(Icons.select_all),
                              ),
                              IconButton(
                                tooltip: 'Text editing actions',
                                onPressed: _editable
                                    ? _toggleEditingMenu
                                    : null,
                                icon: const Icon(Icons.more_horiz),
                              ),
                              IconButton(
                                tooltip: 'Paste',
                                onPressed: _editable ? _paste : null,
                                icon: const Icon(Icons.content_paste, size: 20),
                              ),
                              TextButton(
                                onPressed: _editable ? finishField : null,
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _keysScroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              key: const ValueKey('player-keyboard-scroll'),
                              controller: _keysScroll,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.showValue) _draft(),
                                    if (_clipboardError != null)
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          _clipboardError!,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    if (_editingMenu) _menu(),
                                    LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _keyBank(constraints.maxWidth),
                                    ),
                                  ],
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
            ],
          );
        },
      ),
    ),
  );
}

class _InputScope extends InheritedWidget {
  const _InputScope({
    required this.activate,
    required this.finish,
    required this.canEdit,
    required this.showEditingMenu,
    required super.child,
  });
  final Future<bool> Function(
    TextEditingController,
    String,
    bool,
    bool,
    Future<bool> Function()?,
  )
  activate;
  final Future<void> Function([TextEditingController?]) finish;
  final bool Function() canEdit;
  final VoidCallback showEditingMenu;
  bool get enabled => canEdit();
  @override
  bool updateShouldNotify(_InputScope oldWidget) =>
      oldWidget.canEdit != canEdit;
}

/// Read-only to the system IME, editable through the player-facing keyboard.
class PlayerField extends StatelessWidget {
  const PlayerField({
    super.key,
    required this.controller,
    required this.label,
    this.numeric = false,
    this.maxLines = 1,
    this.helperText,
    this.errorText,
    this.onExit,
  });
  final TextEditingController controller;
  final String label;
  final bool numeric;
  final int maxLines;
  final String? helperText;
  final String? errorText;
  final Future<bool> Function()? onExit;

  @override
  Widget build(BuildContext context) {
    final input = context.dependOnInheritedWidgetOfExactType<_InputScope>();
    Future<void> activate() async {
      if (await input?.activate(
            controller,
            label,
            numeric,
            maxLines > 1,
            onExit,
          ) !=
          true) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: .15,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Semantics(
        container: true,
        label: kIsWeb
            ? '$label. Current value: ${value.text.isEmpty ? 'empty' : value.text}'
            : label,
        value: kIsWeb ? null : value.text,
        hint: 'Opens the player-facing keyboard',
        textField: !kIsWeb,
        button: kIsWeb,
        enabled: input?.enabled ?? true,
        focusable: true,
        readOnly: false,
        onTap: activate,
        onSetText: kIsWeb
            ? null
            : (text) {
                if (input?.enabled == false) return;
                controller.value = TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
              },
        onSetSelection: (selection) {
          if (selection.start >= 0 && selection.end <= controller.text.length) {
            controller.selection = selection;
          }
        },
        child: ExcludeSemantics(
          child: TextField(
            // Do not restore an ancestor ExpansionTile's saved bool as this
            // field's scroll offset. Each editor owns its scroll identity.
            key: PageStorageKey<TextEditingController>(controller),
            enabled: input?.enabled ?? true,
            controller: controller,
            readOnly: true,
            showCursor: true,
            keyboardType: TextInputType.none,
            maxLines: maxLines,
            selectionControls: materialTextSelectionHandleControls,
            contextMenuBuilder: (_, state) {
              input?.showEditingMenu();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (state.mounted) state.hideToolbar(false);
              });
              return const SizedBox.shrink();
            },
            onTapOutside: (_) => context
                .getInheritedWidgetOfExactType<_InputScope>()
                ?.finish(controller),
            decoration: InputDecoration(
              labelText: label,
              helperText: helperText,
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
            onTap: activate,
          ),
        ),
      ),
    );
  }
}

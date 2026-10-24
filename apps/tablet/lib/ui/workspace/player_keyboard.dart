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
  });
  final Widget child;
  final bool enabled;
  final bool showValue;
  final bool Function()? canEdit;

  @override
  State<PlayerKeyboardHost> createState() => _PlayerKeyboardHostState();
}

class _PlayerKeyboardHostState extends State<PlayerKeyboardHost> {
  final FocusNode _hardwareFocus = FocusNode(debugLabel: 'Player keyboard');
  final FocusNode _draftFocus = FocusNode(debugLabel: 'Inline token draft');
  final _draftEditable = GlobalKey<EditableTextState>();
  TextEditingController? _controller;
  Future<bool> Function()? _onExit;
  bool _numeric = false;
  bool _multiline = false;
  bool _shift = false;
  bool _symbols = false;
  String _label = '';
  bool get _editable => widget.enabled && (widget.canEdit?.call() ?? true);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_hardwareHandler);
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
    if (widget.showValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller == controller) {
          _draftFocus.requestFocus();
          _revealDraft();
        }
      });
    }
    return true;
  }

  Future<void> finishField([TextEditingController? expected]) async {
    if (expected != null && expected != _controller) return;
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
    if (!widget.showValue) return;
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller == null || controller != _controller) return;
      final offset = controller.selection.extentOffset;
      if (offset < 0 || offset > controller.text.length) return;
      _draftEditable.currentState?.bringIntoView(TextPosition(offset: offset));
    });
  }

  void _focusDraft() {
    if (widget.showValue) _draftFocus.requestFocus();
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

  Future<void> _paste() async {
    final captured = _controller;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || captured != _controller || data?.text == null) return;
    _replace(data!.text!);
  }

  Future<void> _copy({bool cut = false}) async {
    final c = _controller;
    if (c == null) return;
    final selection = c.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: selection.textInside(c.text)));
    if (cut && mounted && c == _controller) _replace('');
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
    HardwareKeyboard.instance.removeHandler(_hardwareHandler);
    _controller?.removeListener(_revealDraft);
    _hardwareFocus.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  Widget _key(
    String text, {
    VoidCallback? action,
    int flex = 1,
    String? semantics,
    IconData? icon,
  }) {
    final perform =
        action ?? () => _replace(_shift ? text.toUpperCase() : text);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          label: semantics ?? text,
          button: true,
          enabled: _editable,
          onTap: _editable ? perform : null,
          child: ExcludeSemantics(
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(36, 40),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _editable ? perform : null,
              child: icon == null
                  ? Text(_shift ? text.toUpperCase() : text, maxLines: 1)
                  : Icon(icon, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _numeric
        ? ['12345', '67890']
        : _symbols
        ? ['1234567890', '@#%&*()+-=', '.,!?/:;"\'']
        : ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    return _InputScope(
      activate: activateField,
      finish: finishField,
      canEdit: () => _editable,
      child: Focus(
        focusNode: _hardwareFocus,
        // The global handler is also reached when a read-only field owns focus.
        // Consume its editing keys here so EditableText's ancestor shortcuts do
        // not apply the same cursor/selection operation for a second time.
        onKeyEvent: (_, event) => _controller != null && _isEditingKey(event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored,
        child: Column(
          children: [
            Expanded(child: widget.child),
            if (_controller != null)
              TextFieldTapRegion(
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Select all',
                              onPressed: _editable ? _selectAll : null,
                              icon: const Icon(Icons.select_all),
                            ),
                            IconButton(
                              tooltip: 'Copy selected text',
                              onPressed: _editable ? _copy : null,
                              icon: const Icon(Icons.copy, size: 20),
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
                        if (widget.showValue)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: EditableText(
                                  key: _draftEditable,
                                  controller: _controller!,
                                  focusNode: _draftFocus,
                                  readOnly: true,
                                  // Software keys return focus here after updating
                                  // the shared controller. Web/desktop defaults
                                  // would reselect that new text on focus, so the
                                  // next key replaces it. Selection is explicit.
                                  selectAllOnFocus: false,
                                  showCursor: true,
                                  keyboardType: TextInputType.none,
                                  maxLines: _multiline ? 2 : 1,
                                  style: Theme.of(context).textTheme.bodyLarge!,
                                  cursorColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  backgroundCursorColor: Colors.grey,
                                  selectionColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .3),
                                  selectionControls:
                                      materialTextSelectionControls,
                                  contextMenuBuilder: (_, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        for (final row in rows)
                          Row(
                            children: row.characters
                                .map((c) => _key(c))
                                .toList(),
                          ),
                        Row(
                          children: [
                            if (!_numeric)
                              _key(
                                _symbols ? 'ABC' : '123',
                                flex: 2,
                                action: () =>
                                    setState(() => _symbols = !_symbols),
                              ),
                            if (!_numeric)
                              _key(
                                'Shift',
                                icon: Icons.arrow_upward,
                                semantics: 'Shift',
                                action: () => setState(() => _shift = !_shift),
                              ),
                            if (_numeric)
                              _key(
                                '−',
                                icon: Icons.remove,
                                action: () => _replace('-'),
                              ),
                            _key(
                              'Move cursor left',
                              icon: Icons.keyboard_arrow_left,
                              semantics: 'Move cursor left',
                              action: () => _move(false, extend: _shift),
                            ),
                            if (!_numeric)
                              _key(
                                'Space',
                                flex: 4,
                                action: () => _replace(' '),
                              ),
                            if (_numeric)
                              _key('/', action: () => _replace('/')),
                            if (_multiline)
                              _key(
                                'Return',
                                icon: Icons.keyboard_return,
                                semantics: 'Return',
                                action: () => _replace('\n'),
                              ),
                            _key(
                              'Move cursor right',
                              icon: Icons.keyboard_arrow_right,
                              semantics: 'Move cursor right',
                              action: () => _move(true, extend: _shift),
                            ),
                            _key(
                              'Delete previous character',
                              icon: Icons.backspace_outlined,
                              semantics: 'Delete previous character',
                              flex: 2,
                              action: _delete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputScope extends InheritedWidget {
  const _InputScope({
    required this.activate,
    required this.finish,
    required this.canEdit,
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
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
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

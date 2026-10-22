import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One input surface, contained in and rotated with the active workspace.
class PlayerKeyboardHost extends StatefulWidget {
  const PlayerKeyboardHost({super.key, required this.child});
  final Widget child;

  @override
  State<PlayerKeyboardHost> createState() => _PlayerKeyboardHostState();
}

class _PlayerKeyboardHostState extends State<PlayerKeyboardHost> {
  final FocusNode _hardwareFocus = FocusNode(debugLabel: 'Player keyboard');
  TextEditingController? _controller;
  Future<bool> Function()? _onExit;
  bool _numeric = false;
  bool _shift = false;
  bool _symbols = false;
  String _label = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_hardwareHandler);
  }

  bool _hardwareHandler(KeyEvent event) =>
      _controller != null &&
      _onKey(_hardwareFocus, event) == KeyEventResult.handled;

  Future<void> activateField(
    TextEditingController controller,
    String label,
    bool numeric,
    Future<bool> Function()? onExit,
  ) async {
    if (_controller != controller) await _onExit?.call();
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _onExit = onExit;
      _label = label;
      _numeric = numeric;
    });
    _hardwareFocus.requestFocus();
  }

  Future<void> finishField([TextEditingController? expected]) async {
    if (expected != null && expected != _controller) return;
    final captured = _controller;
    await _onExit?.call();
    if (!mounted || captured != _controller) return;
    setState(() {
      _controller = null;
      _onExit = null;
    });
  }

  void _replace(String value) {
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
    final c = _controller;
    if (c != null) {
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    }
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
        key == LogicalKeyboardKey.escape) {
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
    _hardwareFocus.dispose();
    super.dispose();
  }

  Widget _key(
    String text, {
    VoidCallback? action,
    int flex = 1,
    String? semantics,
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
          enabled: true,
          onTap: perform,
          child: ExcludeSemantics(
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(36, 40),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: perform,
              child: Text(_shift ? text.toUpperCase() : text, maxLines: 1),
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
      child: Focus(
        focusNode: _hardwareFocus,
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
                              onPressed: _selectAll,
                              icon: const Icon(Icons.select_all),
                            ),
                            IconButton(
                              tooltip: 'Copy selected text',
                              onPressed: _copy,
                              icon: const Icon(Icons.copy, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Paste',
                              onPressed: _paste,
                              icon: const Icon(Icons.content_paste, size: 20),
                            ),
                            TextButton(
                              onPressed: finishField,
                              child: const Text('Done'),
                            ),
                          ],
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
                                '⇧',
                                semantics: 'Shift',
                                action: () => setState(() => _shift = !_shift),
                              ),
                            if (_numeric)
                              _key('−', action: () => _replace('-')),
                            _key(
                              '←',
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
                            _key(
                              '→',
                              semantics: 'Move cursor right',
                              action: () => _move(true, extend: _shift),
                            ),
                            _key(
                              '⌫',
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
    required super.child,
  });
  final Future<void> Function(
    TextEditingController,
    String,
    bool,
    Future<bool> Function()?,
  )
  activate;
  final Future<void> Function([TextEditingController?]) finish;
  @override
  bool updateShouldNotify(_InputScope oldWidget) => false;
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
    void activate() => context
        .getInheritedWidgetOfExactType<_InputScope>()
        ?.activate(controller, label, numeric, onExit);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Semantics(
        label: label,
        value: value.text,
        hint: 'Opens the player-facing keyboard',
        textField: true,
        readOnly: false,
        onTap: activate,
        onSetText: (text) => controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        onSetSelection: (selection) {
          if (selection.start >= 0 && selection.end <= controller.text.length) {
            controller.selection = selection;
          }
        },
        child: ExcludeSemantics(
          child: TextField(
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

part of 'table_workspace.dart';

/// A disposable app-owned draft. Only explicit Apply changes the utility;
/// leaving this route never flushes inputs or mutates the board behind it.
class _UtilityExactDialog extends StatefulWidget {
  const _UtilityExactDialog({
    required this.quarterTurns,
    required this.current,
    required this.onApply,
  });

  final int quarterTurns;
  final int current;
  final Future<void> Function(int) onApply;

  @override
  State<_UtilityExactDialog> createState() => _UtilityExactDialogState();
}

class _UtilityExactDialogState extends State<_UtilityExactDialog> {
  static const _maximum = 999999;
  final _errorKey = GlobalKey();
  String _digits = '';
  String? _error;
  bool _saving = false;

  int? _parse(String digits) => tryWholeNumber(digits, min: 0, max: _maximum);

  void _setDigits(String digits) => setState(() {
    _digits = digits;
    _error = null;
  });

  Future<void> _apply() async {
    final value = _parse(_digits);
    if (_saving || value == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onApply(value);
      // Never pop a newer route if a posture change removed this editor.
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = inputErrorMessage(error));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final errorContext = _errorKey.currentContext;
          if (errorContext != null) {
            Scrollable.ensureVisible(errorContext, alignment: 1);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _digit(int number) {
    final next = _digits == '0' ? '$number' : '$_digits$number';
    return TextButton(
      key: ValueKey('utility-digit-$number'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: _saving || next.length > 6 || _parse(next) == null
          ? null
          : () => _setDigits(next),
      child: Text('$number'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<void>(
      canPop: !_saving,
      child: TableModalFrame(
        quarterTurns: widget.quarterTurns,
        preferredWidth: 330,
        preferredHeight: 460,
        fitContentHeight: true,
        surfaceKey: const ValueKey('utility-exact-dialog'),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Set exact value',
          explicitChildNodes: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Set exact value',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close exact value editor',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Current value: ${widget.current}'),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _digits.isEmpty ? 'Enter a total' : _digits,
                            key: const ValueKey('utility-exact-draft'),
                            textAlign: TextAlign.end,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        for (final first in [1, 4, 7])
                          Row(
                            children: [
                              for (int n = first; n < first + 3; n++)
                                Expanded(child: _digit(n)),
                            ],
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _saving || _digits.isEmpty
                                    ? null
                                    : () => _setDigits(''),
                                child: const Text('Clear'),
                              ),
                            ),
                            Expanded(child: _digit(0)),
                            Expanded(
                              child: IconButton(
                                tooltip: 'Delete last digit',
                                onPressed: _saving || _digits.isEmpty
                                    ? null
                                    : () => _setDigits(
                                        _digits.substring(
                                          0,
                                          _digits.length - 1,
                                        ),
                                      ),
                                icon: const Icon(Icons.backspace_outlined),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null)
                          Semantics(
                            key: _errorKey,
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 2,
                  child: _saving ? const LinearProgressIndicator() : null,
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: _saving || _parse(_digits) == null
                          ? null
                          : _apply,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

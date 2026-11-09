import 'dart:math' as math;

import 'package:doubling_season/widgets/mana/mana_symbol.dart';
import 'package:flutter/material.dart';

/// The persisted identity stays WUBRG text; colorless is an empty identity.
class CustomTokenColorPicker extends StatelessWidget {
  const CustomTokenColorPicker({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  static const _colors = <String, String>{
    'W': 'White',
    'U': 'Blue',
    'B': 'Black',
    'R': 'Red',
    'G': 'Green',
    'C': 'Colorless',
  };

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final identity = value.text.toUpperCase();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Color identity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _colors.entries)
                    _colorButton(
                      context,
                      color.key,
                      color.value,
                      color.key == 'C'
                          ? identity.isEmpty
                          : identity.contains(color.key),
                      () {
                        if (color.key == 'C') {
                          controller.clear();
                          return;
                        }
                        final selected = identity.split('').toSet();
                        selected.contains(color.key)
                            ? selected.remove(color.key)
                            : selected.add(color.key);
                        controller.text = 'WUBRG'
                            .split('')
                            .where(selected.contains)
                            .join();
                      },
                    ),
                ],
              ),
            ],
          );
        },
      );

  Widget _colorButton(
    BuildContext context,
    String code,
    String name,
    bool selected,
    VoidCallback select,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('custom-token-color-$code'),
      label: '$name color identity',
      button: true,
      enabled: enabled,
      toggled: selected,
      onTap: enabled ? select : null,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled ? select : null,
          excludeFromSemantics: true,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: enabled ? 1 : .45,
                  child: ManaSymbol(code: code, size: 32),
                ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 15,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Validation belongs to the draft, before any catalog write is attempted.
/// Controllers are owned by the workspace so closing or changing posture keeps
/// the same recoverable draft; this widget owns only transient feedback.
class CustomTokenFormValidation extends StatefulWidget {
  const CustomTokenFormValidation({
    super.key,
    required this.name,
    required this.power,
    required this.toughness,
    required this.colors,
    required this.builder,
  });

  final TextEditingController name;
  final TextEditingController power;
  final TextEditingController toughness;
  final TextEditingController colors;
  final Widget Function(CustomTokenFormValidationState validation) builder;

  @override
  State<CustomTokenFormValidation> createState() =>
      CustomTokenFormValidationState();
}

class CustomTokenFormValidationState extends State<CustomTokenFormValidation> {
  final scrollController = ScrollController();
  final _anchors = <String, GlobalKey>{
    'name': GlobalKey(),
    'stats': GlobalKey(),
    'colors': GlobalKey(),
  };
  Map<String, String> _errors = {};
  int _attempt = 0;

  Iterable<TextEditingController> get _controllers => [
    widget.name,
    widget.power,
    widget.toughness,
    widget.colors,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_edited);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_edited);
    }
    scrollController.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (widget.name.text.trim().isEmpty) 'name': 'A token needs a name.',
    if (widget.power.text.trim().isEmpty !=
        widget.toughness.text.trim().isEmpty)
      'stats': 'Enter both power and toughness, or leave both empty.',
    if (!RegExp(
      r'^[WUBRG]*$',
    ).hasMatch(widget.colors.text.trim().toUpperCase().replaceAll(' ', '')))
      'colors': 'Choose a color identity using the symbols.',
  };

  void _edited() {
    if (_attempt == 0) return;
    final errors = _validate();
    if (errors.length == _errors.length &&
        errors.entries.every((entry) => _errors[entry.key] == entry.value)) {
      return;
    }
    setState(() => _errors = errors);
  }

  bool validate() {
    final errors = _validate();
    setState(() {
      _errors = errors;
      _attempt++;
    });
    if (errors.isEmpty) return true;
    _reveal(errors.keys.first);
    return false;
  }

  Future<void> _reveal(String field) async {
    // ListView may have disposed the first fields while Save was visible.
    if (scrollController.hasClients) scrollController.jumpTo(0);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final context = _anchors[field]!.currentContext;
    if (context != null && context.mounted) {
      await Scrollable.ensureVisible(context, alignment: .15);
    }
  }

  Widget field(String id, Widget child) => _CustomTokenValidationFeedback(
    key: _anchors[id],
    field: id,
    error: _errors[id],
    attempt: _attempt,
    child: child,
  );

  @override
  Widget build(BuildContext context) => widget.builder(this);
}

class _CustomTokenValidationFeedback extends StatelessWidget {
  const _CustomTokenValidationFeedback({
    super.key,
    required this.field,
    required this.error,
    required this.attempt,
    required this.child,
  });

  final String field;
  final String? error;
  final int attempt;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('custom-token-validation-$field-$attempt'),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 400),
    builder: (context, progress, child) => Transform.translate(
      offset: Offset(
        error == null || MediaQuery.disableAnimationsOf(context)
            ? 0
            : math.sin(progress * math.pi * 6) * 6 * (1 - progress),
        0,
      ),
      child: child,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                error!,
                key: ValueKey('custom-token-error-$field'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    ),
  );
}

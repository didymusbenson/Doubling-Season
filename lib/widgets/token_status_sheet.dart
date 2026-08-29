import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../providers/token_provider.dart';
import 'mana/mana_icons.dart';

class TokenStatusSheet extends StatefulWidget {
  const TokenStatusSheet({super.key, required this.item});

  final Item item;

  static Future<void> show(BuildContext context, Item item) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TokenStatusSheet(item: item),
      );

  @override
  State<TokenStatusSheet> createState() => _TokenStatusSheetState();
}

class _TokenStatusSheetState extends State<TokenStatusSheet> {
  void _changed(VoidCallback mutation) {
    mutation();
    context.read<TokenProvider>().updateItem(widget.item);
    setState(() {});
  }

  void _setTotal(int value) {
    final oldAmount = widget.item.amount;
    final settings = context.read<SettingsProvider>();
    _changed(() {
      widget.item.amount = value;
      if (value > oldAmount &&
          settings.summoningSicknessEnabled &&
          widget.item.hasPowerToughness &&
          !widget.item.hasHaste) {
        widget.item.summoningSick += value - oldAmount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSickness =
        context.watch<SettingsProvider>().summoningSicknessEnabled;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Token Status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _NumericSheetRow(
              icon: Icons.layers,
              label: 'Total',
              value: widget.item.amount,
              maximum: 99999999,
              onChanged: _setTotal,
            ),
            if (!widget.item.isEmblem) ...[
              _NumericSheetRow(
                icon: ManaIcons.tap,
                label: 'Tapped',
                value: widget.item.tapped,
                maximum: widget.item.amount,
                onChanged: (value) =>
                    _changed(() => widget.item.tapped = value),
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('Ready'),
                trailing: Text('${widget.item.amount - widget.item.tapped}'),
              ),
              if (showSickness)
                _NumericSheetRow(
                  icon: ManaIcons.summoningSickness,
                  label: 'Summoning sick',
                  value: widget.item.summoningSick,
                  maximum: widget.item.amount,
                  onChanged: (value) =>
                      _changed(() => widget.item.summoningSick = value),
                ),
              if (showSickness && widget.item.summoningSick > 0)
                TextButton.icon(
                  onPressed: () =>
                      _changed(() => widget.item.summoningSick = 0),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear summoning sickness'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumericSheetRow extends StatelessWidget {
  const _NumericSheetRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.maximum,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final int maximum;
  final ValueChanged<int> onChanged;

  Future<void> _enterValue(BuildContext context) async {
    final controller = TextEditingController(text: '$value');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (text) =>
              Navigator.pop(context, int.tryParse(text)?.clamp(0, maximum)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(controller.text)?.clamp(0, maximum),
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle),
          ),
          InkWell(
            onTap: () => _enterValue(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                  child: Text('$value',
                      style: Theme.of(context).textTheme.titleMedium)),
            ),
          ),
          IconButton(
            onPressed: value < maximum ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle),
          ),
        ],
      );
}

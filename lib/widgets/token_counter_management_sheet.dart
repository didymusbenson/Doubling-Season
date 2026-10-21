import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../providers/rules_provider.dart';
import '../providers/token_provider.dart';

enum CounterSheetResult { addCounter }

class TokenCounterManagementSheet extends StatefulWidget {
  const TokenCounterManagementSheet({super.key, required this.item});

  final Item item;
  static const maxCounterValue = 99999999;

  static Future<CounterSheetResult?> show(BuildContext context, Item item) =>
      showModalBottomSheet<CounterSheetResult>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TokenCounterManagementSheet(item: item),
      );

  @override
  State<TokenCounterManagementSheet> createState() =>
      _TokenCounterManagementSheetState();
}

class _TokenCounterManagementSheetState
    extends State<TokenCounterManagementSheet> {
  Future<void> _mutationQueue = Future<void>.value();

  Future<void> _mutate(VoidCallback mutation) {
    return _mutationQueue = _mutationQueue.then(
      (_) => _persistMutation(mutation),
    );
  }

  Future<void> _persistMutation(VoidCallback mutation) async {
    mutation();
    try {
      await context.read<TokenProvider>().updateItem(widget.item);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Counters could not be saved.')),
        );
      }
    }
  }

  int _counterIncrement({required bool plusOne}) => context
      .read<RulesProvider>()
      .calculateCounterAmount(1, isPlusOne: plusOne);

  Future<void> _setValue(
      String label, int current, ValueChanged<int> set) async {
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (text) => Navigator.pop(
            context,
            int.tryParse(text)
                ?.clamp(0, TokenCounterManagementSheet.maxCounterValue),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(controller.text)
                  ?.clamp(0, TokenCounterManagementSheet.maxCounterValue),
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) _mutate(() => set(value));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .78),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Counters',
                          style: Theme.of(context).textTheme.titleLarge)),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, CounterSheetResult.addCounter),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Counter'),
                  ),
                ],
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _CounterRow(
                      label: '+1/+1',
                      value: item.plusOneCounters,
                      onDecrement: item.plusOneCounters > 0
                          ? () =>
                              _mutate(() => item.addPowerToughnessCounters(-1))
                          : null,
                      onIncrement: () => _mutate(() =>
                          item.addPowerToughnessCounters(
                              _counterIncrement(plusOne: true))),
                      onSet: () => _setValue(
                          '+1/+1 counters',
                          item.plusOneCounters,
                          (value) => item.plusOneCounters = value),
                    ),
                    _CounterRow(
                      label: '-1/-1',
                      value: item.minusOneCounters,
                      onDecrement: item.minusOneCounters > 0
                          ? () =>
                              _mutate(() => item.addPowerToughnessCounters(1))
                          : null,
                      onIncrement: () => _mutate(() =>
                          item.addPowerToughnessCounters(
                              -_counterIncrement(plusOne: false))),
                      onSet: () => _setValue(
                          '-1/-1 counters',
                          item.minusOneCounters,
                          (value) => item.minusOneCounters = value),
                    ),
                    if (item.plusOnePowerCounters > 0)
                      _CounterRow(
                        label: '+1/+0',
                        value: item.plusOnePowerCounters,
                        onDecrement: () =>
                            _mutate(() => item.plusOnePowerCounters--),
                        onIncrement: () => _mutate(() =>
                            item.plusOnePowerCounters +=
                                _counterIncrement(plusOne: false)),
                        onSet: () => _setValue(
                            '+1/+0 counters',
                            item.plusOnePowerCounters,
                            (value) => item.plusOnePowerCounters = value),
                      ),
                    if (item.plusOneToughnessCounters > 0)
                      _CounterRow(
                        label: '+0/+1',
                        value: item.plusOneToughnessCounters,
                        onDecrement: () =>
                            _mutate(() => item.plusOneToughnessCounters--),
                        onIncrement: () => _mutate(() =>
                            item.plusOneToughnessCounters +=
                                _counterIncrement(plusOne: false)),
                        onSet: () => _setValue(
                            '+0/+1 counters',
                            item.plusOneToughnessCounters,
                            (value) => item.plusOneToughnessCounters = value),
                      ),
                    for (final counter in List.of(item.counters))
                      _CounterRow(
                        label: counter.name,
                        value: counter.amount,
                        onDecrement: () => _mutate(
                            () => item.removeCounter(name: counter.name)),
                        onIncrement: () => _mutate(() => item.addCounter(
                              name: counter.name,
                              amount: _counterIncrement(plusOne: false),
                            )),
                        onSet: () =>
                            _setValue(counter.name, counter.amount, (value) {
                          if (value == 0) {
                            item.counters.removeWhere(
                                (entry) => entry.name == counter.name);
                          } else {
                            counter.amount = value;
                          }
                        }),
                      ),
                    if (item.plusOneCounters == 0 &&
                        item.minusOneCounters == 0 &&
                        item.plusOnePowerCounters == 0 &&
                        item.plusOneToughnessCounters == 0 &&
                        item.counters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No counters yet')),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.onSet,
  });

  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: onDecrement, icon: const Icon(Icons.remove_circle)),
            InkWell(
              onTap: onSet,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                    child: Text('$value',
                        style: Theme.of(context).textTheme.titleMedium)),
              ),
            ),
            IconButton(
              onPressed: value < TokenCounterManagementSheet.maxCounterValue
                  ? onIncrement
                  : null,
              icon: const Icon(Icons.add_circle),
            ),
          ],
        ),
      );
}

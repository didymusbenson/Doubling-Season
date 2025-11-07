import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../utils/constants.dart';

class SplitStackSheet extends StatefulWidget {
  final Item item;
  final VoidCallback? onSplitCompleted; // Optional callback from ExpandedTokenView

  const SplitStackSheet({
    super.key,
    required this.item,
    this.onSplitCompleted,
  });

  @override
  State<SplitStackSheet> createState() => _SplitStackSheetState();
}

class _SplitStackSheetState extends State<SplitStackSheet> {
  late int _splitAmount; // How many tokens to split off
  bool _tappedFirst = false; // Whether to move tapped tokens first

  int get maxSplit => widget.item.amount > 1 ? widget.item.amount - 1 : 1;

  @override
  void initState() {
    super.initState();
    _splitAmount = 1; // Default: split off 1 token
    // Validate splitAmount doesn't exceed maxSplit
    if (_splitAmount > maxSplit) {
      _splitAmount = maxSplit.clamp(1, widget.item.amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Stack'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Splitting: ${widget.item.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current amount: ${widget.item.amount}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Tapped: ${widget.item.tapped}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Split amount selection
            const Text(
              'Number of tokens to split off:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _splitAmount > 1
                        ? () => setState(() => _splitAmount--)
                        : null,
                    icon: Icon(
                      Icons.remove_circle,
                      color: _splitAmount > 1 ? Colors.blue : Colors.grey,
                    ),
                    iconSize: 32,
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: '$_splitAmount'),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null) {
                          setState(() {
                            _splitAmount = parsed.clamp(1, maxSplit);
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _splitAmount < maxSplit
                        ? () => setState(() => _splitAmount++)
                        : null,
                    icon: Icon(
                      Icons.add_circle,
                      color: _splitAmount < maxSplit ? Colors.blue : Colors.grey,
                    ),
                    iconSize: 32,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 16),

            // Tapped first toggle
            SwitchListTile(
              title: const Text(
                'Tapped First',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'When enabled, tapped tokens will be moved to the new stack first.',
                style: TextStyle(fontSize: 12),
              ),
              value: _tappedFirst,
              onChanged: (value) => setState(() => _tappedFirst = value),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 16),

            // Preview
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'After split:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...(() {
                      final result = _calculateSplit();
                      return [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Original Stack'),
                            Text(
                              'Amount: ${result.originalAmount}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Tapped: ${result.originalTapped}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('New Stack'),
                            Text(
                              'Amount: ${result.newAmount}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Tapped: ${result.newTapped}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ];
                    })(),
                  ],
                ),
              ),
            ),

            if (widget.item.summoningSick > 0) ...[
              const SizedBox(height: 12),
              const Text(
                'Note: Splitting will remove summoning sickness from both stacks.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],

            const Spacer(),

            // Split button
            ElevatedButton(
              onPressed: _splitAmount >= widget.item.amount ? null : _performSplit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey,
              ),
              child: const Text(
                'Split Stack',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SplitResult _calculateSplit() {
    final currentTapped = widget.item.tapped;

    if (_tappedFirst) {
      // Move tapped tokens to new stack first
      final newTapped = _splitAmount < currentTapped ? _splitAmount : currentTapped;
      final originalTapped = currentTapped - newTapped;

      return SplitResult(
        originalAmount: widget.item.amount - _splitAmount,
        originalTapped: originalTapped,
        newAmount: _splitAmount,
        newTapped: newTapped,
      );
    } else {
      // Move untapped tokens to new stack first
      final availableUntapped = widget.item.amount - currentTapped;
      final newUntapped = _splitAmount < availableUntapped ? _splitAmount : availableUntapped;
      final newTapped = _splitAmount - newUntapped;
      final originalTapped = currentTapped - newTapped;

      return SplitResult(
        originalAmount: widget.item.amount - _splitAmount,
        originalTapped: originalTapped,
        newAmount: _splitAmount,
        newTapped: newTapped,
      );
    }
  }

  void _performSplit() {
    final result = _calculateSplit();

    // Capture provider reference BEFORE dismissing and async operations
    final tokenProvider = context.read<TokenProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // CRITICAL: Dismiss sheet FIRST (early dismiss pattern from SplitStackView.swift:146)
    Navigator.pop(context);

    // CRITICAL: Use Future.delayed to ensure sheet fully dismissed before Hive operations
    Future.delayed(UIConstants.sheetDismissDelay, () async {
      // Calculate fractional order for new stack (appears immediately after original)
      final items = tokenProvider.items
        ..sort((a, b) => a.order.compareTo(b.order));

      final originalIndex = items.indexWhere((i) => i.key == widget.item.key);

      double newOrder;
      if (originalIndex == items.length - 1) {
        // Original is last item - add 1.0
        newOrder = widget.item.order + 1.0;
      } else {
        // Insert between original and next item (fractional)
        final nextOrder = items[originalIndex + 1].order;
        newOrder = (widget.item.order + nextOrder) / 2.0;
      }

      // Update original stack
      widget.item.amount = result.originalAmount;
      widget.item.tapped = result.originalTapped;
      widget.item.summoningSick = 0; // Clear summoning sickness
      await tokenProvider.updateItem(widget.item);

      // Create new stack
      final newItem = widget.item.createDuplicate();
      newItem.order = newOrder; // Set fractional order

      // Add to box FIRST
      await tokenProvider.insertItemWithExplicitOrder(newItem);

      // Now apply counters from original and set amounts
      newItem.applyDuplicateCounters(widget.item);
      newItem.amount = result.newAmount;
      newItem.tapped = result.newTapped;
      newItem.summoningSick = 0; // Clear summoning sickness

      // Call completion callback if provided
      widget.onSplitCompleted?.call();

      // Use captured ScaffoldMessenger (safe without context)
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Stack split successfully')),
      );
    });
  }
}

class SplitResult {
  final int originalAmount;
  final int originalTapped;
  final int newAmount;
  final int newTapped;

  SplitResult({
    required this.originalAmount,
    required this.originalTapped,
    required this.newAmount,
    required this.newTapped,
  });
}

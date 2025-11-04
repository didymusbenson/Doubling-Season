import 'package:flutter/material.dart';
import '../database/counter_database.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import 'package:provider/provider.dart';

class CounterSearchScreen extends StatefulWidget {
  final Item item;

  const CounterSearchScreen({
    super.key,
    required this.item,
  });

  @override
  State<CounterSearchScreen> createState() => _CounterSearchScreenState();
}

class _CounterSearchScreenState extends State<CounterSearchScreen> {
  final _searchController = TextEditingController();
  final _counterDatabase = CounterDatabase();
  List<String> _filteredCounters = [];

  @override
  void initState() {
    super.initState();
    _filteredCounters = CounterDatabase.predefinedCounters;
    _searchController.addListener(_filterCounters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCounters() {
    setState(() {
      _filteredCounters = _counterDatabase.searchCounters(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Counter'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search counters...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),

          // Counter list
          Expanded(
            child: _filteredCounters.isEmpty && _searchController.text.isNotEmpty
                ? _buildCreateCustomCounter()
                : ListView.builder(
                    itemCount: _filteredCounters.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final counter = _filteredCounters[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            counter,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.add_circle, color: Colors.blue),
                          onTap: () => _showAddToAllOrOneDialog(counter),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddToAllOrOneDialog(String counterName) {
    int quantity = 1;
    final controller = TextEditingController(text: quantity.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add $counterName Counters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                IconButton(
                  onPressed: quantity > 1
                      ? () => setDialogState(() {
                            quantity--;
                            controller.text = quantity.toString();
                          })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Set Quantity'),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter quantity',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (text) {
                            final value = int.tryParse(text);
                            if (value != null && value >= 1) {
                              setDialogState(() => quantity = value);
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              final value = int.tryParse(controller.text);
                              if (value != null && value >= 1) {
                                setDialogState(() => quantity = value);
                                Navigator.pop(dialogContext);
                              }
                            },
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    '$quantity',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => setDialogState(() {
                        quantity++;
                        controller.text = quantity.toString();
                      }),
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addCounter(counterName, quantity, applyToAll: true);
                controller.dispose();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close counter search
              },
              child: const Text('Add to All'),
            ),
            TextButton(
              onPressed: () {
                _addCounter(counterName, quantity, applyToAll: false);
                controller.dispose();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close counter search
                Navigator.pop(context); // Close expanded token screen
              },
              child: const Text('Split & Add to One'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose()); // Dispose controller after dialog closes
  }

  Future<void> _addCounter(String name, int amount, {required bool applyToAll}) async {
    // Capture references BEFORE any async operations
    final tokenProvider = context.read<TokenProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Special handling for +1/+1 and -1/-1 counters
    if (name == '+1/+1' || name == '-1/-1') {
      final counterValue = name == '+1/+1' ? amount : -amount;

      if (applyToAll) {
        // Add to all tokens in stack
        widget.item.addPowerToughnessCounters(counterValue);
        tokenProvider.updateItem(widget.item);

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Added $amount $name counter(s) to all tokens')),
        );
      } else {
        // Split stack and add to one token
        if (widget.item.amount < 2) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Cannot split - only 1 token in stack')),
          );
          return;
        }

        // Create new single-token stack
        final newItem = widget.item.createDuplicate();

        // Add to box FIRST
        await tokenProvider.insertItem(newItem);

        // Apply counters and set properties
        newItem.applyDuplicateCounters(widget.item);
        newItem.amount = 1;
        newItem.tapped = 0;
        newItem.summoningSick = 0;
        newItem.addPowerToughnessCounters(counterValue);

        // Reduce original stack by 1
        widget.item.amount = widget.item.amount - 1;
        await tokenProvider.updateItem(widget.item);

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Split stack and added $amount $name counter(s) to 1 token')),
        );
      }
      return;
    }

    // Regular custom counter handling
    if (applyToAll) {
      // Add counter to entire stack
      widget.item.addCounter(name: name, amount: amount);
      tokenProvider.updateItem(widget.item);

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Added $amount $name counter(s) to all tokens')),
      );
    } else {
      // Split stack: create new item with 1 token + counter
      if (widget.item.amount < 2) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Cannot split - only 1 token in stack')),
        );
        return;
      }

      // Create new single-token stack with counter
      final newItem = widget.item.createDuplicate();

      // Add to box FIRST
      await tokenProvider.insertItem(newItem);

      // Now apply counters from original
      newItem.applyDuplicateCounters(widget.item);
      newItem.amount = 1;
      newItem.tapped = 0;
      newItem.summoningSick = 0;
      newItem.addCounter(name: name, amount: amount);

      // Reduce original stack by 1
      widget.item.amount = widget.item.amount - 1;
      await tokenProvider.updateItem(widget.item);

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Split stack and added $amount $name counter(s) to 1 token')),
      );
    }
  }

  Widget _buildCreateCustomCounter() {
    final searchText = _searchController.text.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No counters found for "$searchText"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddToAllOrOneDialog(searchText),
              icon: const Icon(Icons.add),
              label: Text('Create "$searchText"'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

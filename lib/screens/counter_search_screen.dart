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

  // CRITICAL: SwiftUI CounterSearchView shows "Add to All" vs "Add to One" choice FIRST
  void _showAddToAllOrOneDialog(String counterName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $counterName Counter'),
        content: const Text(
          'Do you want to add this counter to all tokens in the stack, '
          'or split the stack and add to just one token?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showQuantityDialog(counterName, applyToAll: true);
            },
            child: const Text('Add to All'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showQuantityDialog(counterName, applyToAll: false);
            },
            child: const Text('Split & Add to One'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(String counterName, {required bool applyToAll}) {
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add $counterName Counters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setDialogState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle),
                    iconSize: 32,
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => quantity++),
                    icon: const Icon(Icons.add_circle),
                    iconSize: 32,
                  ),
                ],
              ),
              if (!applyToAll) ...[
                const SizedBox(height: 16),
                const Text(
                  'This will split the stack and add counters to one token only',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addCounter(counterName, quantity, applyToAll: applyToAll);
                Navigator.pop(context); // Close quantity dialog
                Navigator.pop(context); // Close counter search
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCounter(String name, int amount, {required bool applyToAll}) async {
    final tokenProvider = context.read<TokenProvider>();

    // Special handling for +1/+1 and -1/-1 counters
    if (name == '+1/+1' || name == '-1/-1') {
      final counterValue = name == '+1/+1' ? amount : -amount;

      if (applyToAll) {
        // Add to all tokens in stack
        widget.item.addPowerToughnessCounters(counterValue);
        tokenProvider.updateItem(widget.item);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $amount $name counter(s) to all tokens')),
        );
      } else {
        // Split stack and add to one token
        if (widget.item.amount < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
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

        ScaffoldMessenger.of(context).showSnackBar(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $amount $name counter(s) to all tokens')),
      );
    } else {
      // Split stack: create new item with 1 token + counter
      if (widget.item.amount < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
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

      ScaffoldMessenger.of(context).showSnackBar(
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

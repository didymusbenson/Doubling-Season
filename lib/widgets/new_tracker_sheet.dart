import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/tracker_widget.dart';
import '../providers/token_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';
import 'color_selection_button.dart';

class NewTrackerSheet extends StatefulWidget {
  const NewTrackerSheet({super.key});

  @override
  State<NewTrackerSheet> createState() => _NewTrackerSheetState();
}

class _NewTrackerSheetState extends State<NewTrackerSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _defaultValue = 0;
  bool _isCreating = false;

  // Color selection
  bool _whiteSelected = false;
  bool _blueSelected = false;
  bool _blackSelected = false;
  bool _redSelected = false;
  bool _greenSelected = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getColorString() {
    String colors = '';
    if (_whiteSelected) colors += 'W';
    if (_blueSelected) colors += 'U';
    if (_blackSelected) colors += 'B';
    if (_redSelected) colors += 'R';
    if (_greenSelected) colors += 'G';
    return colors;
  }

  void _createTracker() async {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    // Calculate max order across ALL board items (tokens + trackers + toggles)
    final tokenProvider = context.read<TokenProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();

    final allOrders = <double>[];
    allOrders.addAll(tokenProvider.items.map((item) => item.order));
    allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
    allOrders.addAll(toggleProvider.toggles.map((t) => t.order));

    final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
    final newOrder = maxOrder.floor() + 1.0;

    final tracker = TrackerWidget(
      widgetId: const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? 'Custom tracker'
          : _descriptionController.text.trim(),
      colorIdentity: _getColorString(),
      order: newOrder,
      createdAt: DateTime.now(),
      currentValue: _defaultValue,
      defaultValue: _defaultValue,
      tapIncrement: 1,
      longPressIncrement: 5,
      isCustom: true,
    );

    await trackerProvider.insertTracker(tracker);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Tracker'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createTracker,
            child: Text(
              _isCreating ? 'Creating...' : 'Create',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tracker Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Track life total',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Default Value
            _buildDefaultValueField(),
            const SizedBox(height: 16),

            // Color Identity
            const Text(
              'Color Identity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ColorSelectionButton(
                  symbol: 'W',
                  isSelected: _whiteSelected,
                  color: Colors.yellow,
                  label: 'White',
                  onChanged: (value) => setState(() => _whiteSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'U',
                  isSelected: _blueSelected,
                  color: Colors.blue,
                  label: 'Blue',
                  onChanged: (value) => setState(() => _blueSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'B',
                  isSelected: _blackSelected,
                  color: Colors.purple,
                  label: 'Black',
                  onChanged: (value) => setState(() => _blackSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'R',
                  isSelected: _redSelected,
                  color: Colors.red,
                  label: 'Red',
                  onChanged: (value) => setState(() => _redSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'G',
                  isSelected: _greenSelected,
                  color: Colors.green,
                  label: 'Green',
                  onChanged: (value) => setState(() => _greenSelected = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultValueField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Default Value',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                setState(() {
                  if (_defaultValue > 0) _defaultValue--;
                });
              },
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _showValueDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_defaultValue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _defaultValue++;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showValueDialog() {
    final controller = TextEditingController(text: '$_defaultValue');
    final focusNode = FocusNode();
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Request focus after dialog is built (Android compatibility)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialogContext.mounted) {
            focusNode.requestFocus();
          }
        });
        return AlertDialog(
          title: const Text('Set Default Value'),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
            ),
            onTapOutside: (_) => FocusScope.of(dialogContext).unfocus(),
          ),
          actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? _defaultValue;
              setState(() {
                _defaultValue = newValue.clamp(0, double.maxFinite.toInt());
              });
              Navigator.of(context).pop();
            },
            child: const Text('Set'),
          ),
        ],
        );
      },
    ).then((_) {
      controller.dispose();
      focusNode.dispose();
    });
  }
}

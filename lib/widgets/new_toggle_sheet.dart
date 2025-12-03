import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/toggle_widget.dart';
import '../providers/toggle_provider.dart';
import 'color_selection_button.dart';

class NewToggleSheet extends StatefulWidget {
  const NewToggleSheet({super.key});

  @override
  State<NewToggleSheet> createState() => _NewToggleSheetState();
}

class _NewToggleSheetState extends State<NewToggleSheet> {
  final _nameController = TextEditingController();
  final _onDescriptionController = TextEditingController();
  final _offDescriptionController = TextEditingController();

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
    _onDescriptionController.dispose();
    _offDescriptionController.dispose();
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

  void _createToggle() async {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final toggleProvider = context.read<ToggleProvider>();

    // Get max order
    final maxOrder = toggleProvider.toggles.isEmpty
        ? 0.0
        : toggleProvider.toggles.map((t) => t.order).reduce((a, b) => a > b ? a : b);

    final toggle = ToggleWidget(
      widgetId: const Uuid().v4(),
      name: _nameController.text.trim(),
      colorIdentity: _getColorString(),
      order: maxOrder + 1.0,
      createdAt: DateTime.now(),
      isActive: false, // Always start in OFF state
      onDescription: _onDescriptionController.text.trim().isEmpty
          ? 'ON'
          : _onDescriptionController.text.trim(),
      offDescription: _offDescriptionController.text.trim().isEmpty
          ? 'OFF'
          : _offDescriptionController.text.trim(),
      isCustom: true,
    );

    await toggleProvider.insertToggle(toggle);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Toggle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createToggle,
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
                labelText: 'Toggle Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _onDescriptionController,
              decoration: const InputDecoration(
                labelText: 'ON Description',
                hintText: 'e.g., Effect is active',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _offDescriptionController,
              decoration: const InputDecoration(
                labelText: 'OFF Description',
                hintText: 'e.g., Effect is inactive',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
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
}

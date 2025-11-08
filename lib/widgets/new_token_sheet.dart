import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import 'color_selection_button.dart';

class NewTokenSheet extends StatefulWidget {
  const NewTokenSheet({super.key});

  @override
  State<NewTokenSheet> createState() => _NewTokenSheetState();
}

class _NewTokenSheetState extends State<NewTokenSheet> {
  final _nameController = TextEditingController();
  final _ptController = TextEditingController();
  final _typeController = TextEditingController();
  final _abilitiesController = TextEditingController();

  int _amount = 1;
  bool _createTapped = false;

  // CRITICAL: SwiftUI NewTokenSheet uses ColorSelectionButton, not TextField
  bool _whiteSelected = false;
  bool _blueSelected = false;
  bool _blackSelected = false;
  bool _redSelected = false;
  bool _greenSelected = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ptController.dispose();
    _typeController.dispose();
    _abilitiesController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Token'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _createToken,
            child: const Text(
              'Create',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                labelText: 'Token Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _ptController,
              decoration: const InputDecoration(
                labelText: 'Power/Toughness',
                hintText: 'e.g., 1/1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Type',
                hintText: 'e.g., Creature — Elf Warrior',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Color Selection (using ColorSelectionButton from Phase 2)
            const Text(
              'Colors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),

            TextField(
              controller: _abilitiesController,
              decoration: const InputDecoration(
                labelText: 'Abilities',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            const Text(
              'Quantity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                IconButton(
                  onPressed: _amount > 1 ? () => setState(() => _amount--) : null,
                  icon: const Icon(Icons.remove_circle),
                  iconSize: 32,
                ),
                Expanded(
                  child: Text(
                    '$_amount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _amount++),
                  icon: const Icon(Icons.add_circle),
                  iconSize: 32,
                ),
              ],
            ),

            if (multiplier > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Current multiplier: x$multiplier - Final amount will be ${_amount * multiplier}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text('Create Tapped'),
              subtitle: const Text('Tokens enter the battlefield tapped'),
              value: _createTapped,
              onChanged: (value) => setState(() => _createTapped = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createToken() async {
    if (_nameController.text.isEmpty) {
      return;
    }

    final tokenProvider = context.read<TokenProvider>();
    final settings = context.read<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;
    final finalAmount = _amount * multiplier;

    final item = Item(
      name: _nameController.text,
      pt: _ptController.text,
      type: _typeController.text.trim(),
      colors: _getColorString(),  // Build from color selections
      abilities: _abilitiesController.text,
      amount: finalAmount,
      tapped: _createTapped ? finalAmount : 0,
      summoningSick: settings.summoningSicknessEnabled ? finalAmount : 0,
    );

    await tokenProvider.insertItem(item);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}

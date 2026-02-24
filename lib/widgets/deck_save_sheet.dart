import 'package:flutter/material.dart';
import '../widgets/color_selection_button.dart';

/// Result returned when user saves a deck
class DeckSaveResult {
  final String name;
  final String colorIdentity;

  DeckSaveResult({required this.name, required this.colorIdentity});
}

/// Bottom sheet for naming a new deck and selecting its color identity.
/// Returns a [DeckSaveResult] on save, or null on cancel.
class DeckSaveSheet extends StatefulWidget {
  /// Pre-detected colors from the current board state
  final String suggestedColors;

  const DeckSaveSheet({super.key, this.suggestedColors = ''});

  @override
  State<DeckSaveSheet> createState() => _DeckSaveSheetState();
}

class _DeckSaveSheetState extends State<DeckSaveSheet> {
  final TextEditingController _nameController = TextEditingController();
  late Set<String> _selectedColors;

  @override
  void initState() {
    super.initState();
    // Pre-select colors from the board
    _selectedColors = {};
    for (int i = 0; i < widget.suggestedColors.length; i++) {
      final c = widget.suggestedColors[i];
      if ('WUBRG'.contains(c)) {
        _selectedColors.add(c);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _colorIdentity {
    final buffer = StringBuffer();
    for (final c in ['W', 'U', 'B', 'R', 'G']) {
      if (_selectedColors.contains(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save Deck',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Deck name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),

          // Color identity selection
          Text(
            'Color Identity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorButton('W', Colors.yellow.shade200, 'White'),
              _buildColorButton('U', Colors.blue, 'Blue'),
              _buildColorButton('B', Colors.purple, 'Black'),
              _buildColorButton('R', Colors.red, 'Red'),
              _buildColorButton('G', Colors.green, 'Green'),
            ],
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      DeckSaveResult(name: name, colorIdentity: _colorIdentity),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildColorButton(String symbol, Color color, String label) {
    return ColorSelectionButton(
      symbol: symbol,
      isSelected: _selectedColors.contains(symbol),
      color: color,
      label: label,
      onChanged: (selected) {
        setState(() {
          if (selected) {
            _selectedColors.add(symbol);
          } else {
            _selectedColors.remove(symbol);
          }
        });
      },
    );
  }
}

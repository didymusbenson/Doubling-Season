import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/counter_management_pill.dart';
import '../widgets/color_selection_button.dart';
import '../widgets/split_stack_sheet.dart';
import 'counter_search_screen.dart';

class ExpandedTokenScreen extends StatefulWidget {
  final Item item;

  const ExpandedTokenScreen({super.key, required this.item});

  @override
  State<ExpandedTokenScreen> createState() => _ExpandedTokenScreenState();
}

class _ExpandedTokenScreenState extends State<ExpandedTokenScreen> {
  EditableField? _editingField;
  final Map<EditableField, TextEditingController> _controllers = {};
  final Map<EditableField, FocusNode> _focusNodes = {};

  // CRITICAL: SwiftUI ExpandedTokenView uses ColorSelectionButton for colors
  late bool _whiteSelected;
  late bool _blueSelected;
  late bool _blackSelected;
  late bool _redSelected;
  late bool _greenSelected;

  @override
  void initState() {
    super.initState();
    for (final field in EditableField.values) {
      _controllers[field] = TextEditingController();
      _focusNodes[field] = FocusNode();
    }

    // Initialize color selections from item
    _whiteSelected = widget.item.colors.contains('W');
    _blueSelected = widget.item.colors.contains('U');
    _blackSelected = widget.item.colors.contains('B');
    _redSelected = widget.item.colors.contains('R');
    _greenSelected = widget.item.colors.contains('G');
  }

  void _updateColors() {
    String newColors = '';
    if (_whiteSelected) newColors += 'W';
    if (_blueSelected) newColors += 'U';
    if (_blackSelected) newColors += 'B';
    if (_redSelected) newColors += 'R';
    if (_greenSelected) newColors += 'G';

    widget.item.colors = newColors;
    context.read<TokenProvider>().updateItem(widget.item);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = context.watch<TokenProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_split),
            onPressed: () => _showSplitStack(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              tokenProvider.deleteItem(widget.item);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token Name
            _buildEditableField(
              label: 'Name',
              field: EditableField.name,
              value: widget.item.name,
              onSave: (value) => widget.item.name = value,
            ),

            const SizedBox(height: 16),

            // Power/Toughness
            _buildEditableField(
              label: 'Power/Toughness',
              field: EditableField.powerToughness,
              value: widget.item.pt,
              onSave: (value) => widget.item.pt = value,
            ),

            const SizedBox(height: 16),

            // Colors (using ColorSelectionButton from Phase 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colors',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
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
                        onChanged: (value) {
                          setState(() => _whiteSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'U',
                        isSelected: _blueSelected,
                        color: Colors.blue,
                        label: 'Blue',
                        onChanged: (value) {
                          setState(() => _blueSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'B',
                        isSelected: _blackSelected,
                        color: Colors.purple,
                        label: 'Black',
                        onChanged: (value) {
                          setState(() => _blackSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'R',
                        isSelected: _redSelected,
                        color: Colors.red,
                        label: 'Red',
                        onChanged: (value) {
                          setState(() => _redSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'G',
                        isSelected: _greenSelected,
                        color: Colors.green,
                        label: 'Green',
                        onChanged: (value) {
                          setState(() => _greenSelected = value);
                          _updateColors();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Abilities
            _buildEditableField(
              label: 'Abilities',
              field: EditableField.abilities,
              value: widget.item.abilities,
              onSave: (value) => widget.item.abilities = value,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Amount Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Token Counts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Total Amount
                    _buildCountRow(
                      icon: Icons.functions,
                      label: 'Total Amount',
                      value: widget.item.amount,
                      onIncrement: () {
                        widget.item.amount++;
                        tokenProvider.updateItem(widget.item);
                      },
                      onDecrement: widget.item.amount > 0
                          ? () {
                              widget.item.amount--;
                              tokenProvider.updateItem(widget.item);
                            }
                          : null,
                    ),

                    const Divider(height: 24),

                    if (!widget.item.isEmblem) ...[
                      // Untapped
                      _buildCountRow(
                        icon: Icons.crop_portrait,
                        label: 'Untapped',
                        value: widget.item.amount - widget.item.tapped,
                        showButtons: false,
                      ),

                      const SizedBox(height: 12),

                      // Tapped
                      _buildCountRow(
                        icon: Icons.crop_landscape,
                        label: 'Tapped',
                        value: widget.item.tapped,
                        onIncrement: widget.item.tapped < widget.item.amount
                            ? () {
                                widget.item.tapped++;
                                tokenProvider.updateItem(widget.item);
                              }
                            : null,
                        onDecrement: widget.item.tapped > 0
                            ? () {
                                widget.item.tapped--;
                                tokenProvider.updateItem(widget.item);
                              }
                            : null,
                      ),

                      const Divider(height: 24),

                      // Summoning Sickness
                      if (settings.summoningSicknessEnabled) ...[
                        _buildCountRow(
                          icon: Icons.hexagon_outlined,
                          label: 'Summoning Sick',
                          value: widget.item.summoningSick,
                          onIncrement:
                              widget.item.summoningSick < widget.item.amount
                                  ? () {
                                      widget.item.summoningSick++;
                                      tokenProvider.updateItem(widget.item);
                                    }
                                  : null,
                          onDecrement: widget.item.summoningSick > 0
                              ? () {
                                  widget.item.summoningSick--;
                                  tokenProvider.updateItem(widget.item);
                                }
                              : null,
                        ),
                        const Divider(height: 24),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Power/Toughness Counters Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Power/Toughness Counters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // +1/+1 Counters
                    Row(
                      children: [
                        const Expanded(child: Text('+1/+1 Counters')),
                        IconButton(
                          onPressed: widget.item.plusOneCounters > 0
                              ? () {
                                  widget.item.addPowerToughnessCounters(-1);
                                  tokenProvider.updateItem(widget.item);
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${widget.item.plusOneCounters}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            widget.item.addPowerToughnessCounters(1);
                            tokenProvider.updateItem(widget.item);
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // -1/-1 Counters
                    Row(
                      children: [
                        const Expanded(child: Text('-1/-1 Counters')),
                        IconButton(
                          onPressed: widget.item.minusOneCounters > 0
                              ? () {
                                  widget.item.addPowerToughnessCounters(1);
                                  tokenProvider.updateItem(widget.item);
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${widget.item.minusOneCounters}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            widget.item.addPowerToughnessCounters(-1);
                            tokenProvider.updateItem(widget.item);
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                    ),

                    if (widget.item.netPlusOneCounters != 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Modified P/T:'),
                            Text(
                              widget.item.formattedPowerToughness,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Custom Counters Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Custom Counters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () => _showCounterSearch(context),
                        ),
                      ],
                    ),

                    if (widget.item.counters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No custom counters',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 12),
                      ...widget.item.counters.map((counter) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CounterManagementPillView(
                            counter: counter,
                            onDecrement: () {
                              widget.item.removeCounter(name: counter.name);
                              tokenProvider.updateItem(widget.item);
                              setState(() {}); // Rebuild to update UI
                            },
                            onIncrement: () {
                              widget.item.addCounter(name: counter.name);
                              tokenProvider.updateItem(widget.item);
                              setState(() {}); // Rebuild to update UI
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required EditableField field,
    required String value,
    required ValueChanged<String> onSave,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final isEditing = _editingField == field;

    return GestureDetector(
      onTap: isEditing
          ? null
          : () {
              _controllers[field]!.text = value;
              setState(() => _editingField = field);
              _focusNodes[field]!.requestFocus();
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEditing ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEditing ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? TextField(
                    controller: _controllers[field],
                    focusNode: _focusNodes[field],
                    maxLines: maxLines,
                    textCapitalization: textCapitalization,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (newValue) {
                      onSave(newValue);
                      context.read<TokenProvider>().updateItem(widget.item);
                      setState(() => _editingField = null);
                    },
                  )
                : Text(
                    value.isEmpty ? 'Tap to edit' : value,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isEmpty ? Colors.grey : null,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow({
    required IconData icon,
    required String label,
    required int value,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    bool showButtons = true,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        if (showButtons) ...[
          IconButton(
            onPressed: onDecrement,
            icon: Icon(
              Icons.remove_circle,
              color: onDecrement != null ? Colors.red : Colors.grey,
            ),
          ),
        ],
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (showButtons) ...[
          IconButton(
            onPressed: onIncrement,
            icon: Icon(
              Icons.add_circle,
              color: onIncrement != null ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  void _showSplitStack(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SplitStackSheet(item: widget.item),
        fullscreenDialog: true,
      ),
    );
  }

  void _showCounterSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CounterSearchScreen(item: widget.item),
        fullscreenDialog: true,
      ),
    );
  }
}

enum EditableField {
  name,
  powerToughness,
  abilities,
  // Note: colors removed - uses ColorSelectionButton instead
}

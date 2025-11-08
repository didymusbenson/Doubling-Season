import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/counter_management_pill.dart';
import '../widgets/color_selection_button.dart';
import '../widgets/split_stack_sheet.dart';
import '../utils/constants.dart';
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
    // Use read instead of watch since tokenProvider is only used in callbacks
    final tokenProvider = context.read<TokenProvider>();

    // Use Selector to only rebuild when summoningSicknessEnabled changes
    return Selector<SettingsProvider, bool>(
      selector: (context, settings) => settings.summoningSicknessEnabled,
      builder: (context, summoningSicknessEnabled, child) {
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
            // Name and Stats in a row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name (75% width)
                Expanded(
                  flex: 3,
                  child: _buildEditableField(
                    label: 'Name',
                    field: EditableField.name,
                    value: widget.item.name,
                    onSave: (value) => widget.item.name = value,
                  ),
                ),
                const SizedBox(width: 12),
                // Stats (25% width)
                Expanded(
                  flex: 1,
                  child: _buildEditableField(
                    label: 'Stats',
                    field: EditableField.powerToughness,
                    value: widget.item.pt,
                    onSave: (value) => widget.item.pt = value,
                    labelAlign: TextAlign.left,
                    textAlign: TextAlign.center,
                    placeholder: 'n/a',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Type
            _buildEditableField(
              label: 'Type',
              field: EditableField.type,
              value: widget.item.type,
              onSave: (value) => widget.item.type = value,
              placeholder: 'e.g., Creature — Elf Warrior',
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

            const SizedBox(height: 16),

            // Colors (using ColorSelectionButton from Phase 2)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Colors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
            ),

            const SizedBox(height: 16),

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
                        setState(() {
                          widget.item.amount++;
                          tokenProvider.updateItem(widget.item);
                        });
                      },
                      onDecrement: widget.item.amount > 0
                          ? () {
                              setState(() {
                                widget.item.amount--;
                                tokenProvider.updateItem(widget.item);
                              });
                            }
                          : null,
                      onManualSet: (value) {
                        setState(() {
                          widget.item.amount = value;
                          tokenProvider.updateItem(widget.item);
                        });
                      },
                    ),

                    const Divider(height: 24),

                    if (!widget.item.isEmblem) ...[
                      // Untapped
                      _buildCountRow(
                        icon: Icons.screenshot,
                        label: 'Untapped',
                        value: widget.item.amount - widget.item.tapped,
                        showButtons: false,
                      ),

                      const SizedBox(height: 12),

                      // Tapped
                      _buildCountRow(
                        icon: Icons.screen_rotation,
                        label: 'Tapped',
                        value: widget.item.tapped,
                        onIncrement: widget.item.tapped < widget.item.amount
                            ? () {
                                setState(() {
                                  widget.item.tapped++;
                                  tokenProvider.updateItem(widget.item);
                                });
                              }
                            : null,
                        onDecrement: widget.item.tapped > 0
                            ? () {
                                setState(() {
                                  widget.item.tapped--;
                                  tokenProvider.updateItem(widget.item);
                                });
                              }
                            : null,
                        onManualSet: (value) {
                          setState(() {
                            if (value <= widget.item.amount) {
                              widget.item.tapped = value;
                              tokenProvider.updateItem(widget.item);
                            }
                          });
                        },
                      ),

                      const Divider(height: 24),

                      // Summoning Sickness
                      if (summoningSicknessEnabled) ...[
                        _buildCountRow(
                          icon: Icons.adjust,
                          label: 'Summoning Sick',
                          value: widget.item.summoningSick,
                          onIncrement:
                              widget.item.summoningSick < widget.item.amount
                                  ? () {
                                      setState(() {
                                        widget.item.summoningSick++;
                                        tokenProvider.updateItem(widget.item);
                                      });
                                    }
                                  : null,
                          onDecrement: widget.item.summoningSick > 0
                              ? () {
                                  setState(() {
                                    widget.item.summoningSick--;
                                    tokenProvider.updateItem(widget.item);
                                  });
                                }
                              : null,
                          onManualSet: (value) {
                            setState(() {
                              if (value <= widget.item.amount) {
                                widget.item.summoningSick = value;
                                tokenProvider.updateItem(widget.item);
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Counters Card (merged Power/Toughness and Custom)
            // CRITICAL: Use ValueListenableBuilder to reactively update when counters are added from CounterSearchScreen
            ValueListenableBuilder(
              valueListenable: tokenProvider.listenable,
              builder: (context, box, _) {
                // Find the current item in the box to get latest values
                final currentItem = box.values.firstWhere(
                  (item) => item.key == widget.item.key,
                  orElse: () => widget.item,
                );

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Counters',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                              onPressed: () => _showCounterSearch(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // +1/+1 Counters
                        Row(
                          children: [
                            const Expanded(child: Text('+1/+1 Counters')),
                            IconButton(
                              onPressed: currentItem.plusOneCounters > 0
                                  ? () {
                                      setState(() {
                                        currentItem.addPowerToughnessCounters(-1);
                                        tokenProvider.updateItem(currentItem);
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                            ),
                            GestureDetector(
                              onTap: () => _showManualInputDialog(
                                '+1/+1 Counters',
                                currentItem.plusOneCounters,
                                (value) {
                                  setState(() {
                                    currentItem.plusOneCounters = value;
                                    tokenProvider.updateItem(currentItem);
                                  });
                                },
                              ),
                              child: Container(
                                width: 40,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                ),
                                child: Text(
                                  '${currentItem.plusOneCounters}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  currentItem.addPowerToughnessCounters(1);
                                  tokenProvider.updateItem(currentItem);
                                });
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
                              onPressed: currentItem.minusOneCounters > 0
                                  ? () {
                                      setState(() {
                                        currentItem.addPowerToughnessCounters(1);
                                        tokenProvider.updateItem(currentItem);
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                            ),
                            GestureDetector(
                              onTap: () => _showManualInputDialog(
                                '-1/-1 Counters',
                                currentItem.minusOneCounters,
                                (value) {
                                  setState(() {
                                    currentItem.minusOneCounters = value;
                                    tokenProvider.updateItem(currentItem);
                                  });
                                },
                              ),
                              child: Container(
                                width: 40,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                ),
                                child: Text(
                                  '${currentItem.minusOneCounters}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  currentItem.addPowerToughnessCounters(-1);
                                  tokenProvider.updateItem(currentItem);
                                });
                              },
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                            ),
                          ],
                        ),

                        if (currentItem.netPlusOneCounters != 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Modified P/T:'),
                                Text(
                                  currentItem.formattedPowerToughness,
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

                        // Custom counters (appear below +1/+1 and -1/-1)
                        if (currentItem.counters.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...currentItem.counters.map((counter) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text('${counter.name} Counters')),
                                  IconButton(
                                    onPressed: counter.amount > 0
                                        ? () {
                                            currentItem.removeCounter(name: counter.name);
                                            tokenProvider.updateItem(currentItem);
                                            setState(() {}); // Rebuild to update UI
                                          }
                                        : null,
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showManualInputDialog(
                                      '${counter.name} Counters',
                                      counter.amount,
                                      (value) {
                                        counter.amount = value;
                                        tokenProvider.updateItem(currentItem);
                                        setState(() {}); // Rebuild to update UI
                                      },
                                    ),
                                    child: Container(
                                      width: 40,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                      ),
                                      child: Text(
                                        '${counter.amount}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      currentItem.addCounter(name: counter.name);
                                      tokenProvider.updateItem(currentItem);
                                      setState(() {}); // Rebuild to update UI
                                    },
                                    icon: const Icon(Icons.add_circle, color: Colors.green),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildEditableField({
    required String label,
    required EditableField field,
    required String value,
    required ValueChanged<String> onSave,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextAlign textAlign = TextAlign.left,
    TextAlign? labelAlign,
    String placeholder = 'Tap to edit',
  }) {
    final isEditing = _editingField == field;
    final effectiveLabelAlign = labelAlign ?? textAlign;

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
          color: isEditing ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEditing ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              alignment: effectiveLabelAlign == TextAlign.center
                  ? Alignment.center
                  : (effectiveLabelAlign == TextAlign.right
                      ? Alignment.centerRight
                      : Alignment.centerLeft),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? TextField(
                    controller: _controllers[field],
                    focusNode: _focusNodes[field],
                    maxLines: maxLines,
                    textCapitalization: textCapitalization,
                    textAlign: textAlign,
                    textInputAction: TextInputAction.done,
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
                    value.isEmpty ? placeholder : value,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isEmpty ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5) : null,
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
    Function(int)? onManualSet,
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
              color: onDecrement != null ? Colors.red : Theme.of(context).disabledColor,
            ),
          ),
        ],
        GestureDetector(
          onTap: onManualSet != null
              ? () => _showManualInputDialog(label, value, onManualSet)
              : null,
          child: Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: onManualSet != null
                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
            ),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (showButtons) ...[
          IconButton(
            onPressed: onIncrement,
            icon: Icon(
              Icons.add_circle,
              color: onIncrement != null ? Colors.green : Theme.of(context).disabledColor,
            ),
          ),
        ],
      ],
    );
  }

  void _showManualInputDialog(String label, int currentValue, Function(int) onSet) {
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Set $label'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter value',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (text) {
            final value = int.tryParse(text);
            if (value != null && value >= 0) {
              Navigator.pop(dialogContext);
              // CRITICAL: Use Future.delayed to ensure dialog fully dismissed before state update
              Future.delayed(UIConstants.sheetDismissDelay, () {
                if (mounted) {
                  onSet(value);
                }
                controller.dispose();
              });
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Dispose controller after dialog is dismissed
              Future.delayed(UIConstants.sheetDismissDelay, () {
                controller.dispose();
              });
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) {
                Navigator.pop(dialogContext);
                // CRITICAL: Use Future.delayed to ensure dialog fully dismissed before state update
                Future.delayed(UIConstants.sheetDismissDelay, () {
                  if (mounted) {
                    onSet(value);
                  }
                  controller.dispose();
                });
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showSplitStack(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SplitStackSheet(
        item: widget.item,
        onSplitCompleted: () {
          // Dismiss the ExpandedTokenScreen to return to main list
          Navigator.of(context).pop();
        },
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
  type,
  abilities,
  // Note: colors removed - uses ColorSelectionButton instead
}

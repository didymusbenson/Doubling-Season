import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/token_definition.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/color_selection_button.dart';
import '../widgets/split_stack_sheet.dart';
import '../widgets/artwork_selection_sheet.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_preference_manager.dart';
import '../database/token_database.dart';
import 'counter_search_screen.dart';

const int kMaxCounterValue = 99999999;

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

  // Numeric field editing state
  String? _editingNumericField; // null, 'amount', 'tapped', 'summoningSick', or 'counter_<name>'
  final TextEditingController _numericController = TextEditingController();

  // CRITICAL: SwiftUI ExpandedTokenView uses ColorSelectionButton for colors
  late bool _whiteSelected;
  late bool _blueSelected;
  late bool _blackSelected;
  late bool _redSelected;
  late bool _greenSelected;

  // Artwork-related state
  TokenDefinition? _tokenDefinition;

  @override
  void initState() {
    super.initState();
    for (final field in EditableField.values) {
      _controllers[field] = TextEditingController();
      _focusNodes[field] = FocusNode();
      
      // Add listener to save changes when focus is lost
      _focusNodes[field]!.addListener(() {
        if (!_focusNodes[field]!.hasFocus && _editingField == field) {
          if (mounted) {
            _saveField(field);
          }
        }
      });
    }

    // Initialize color selections from item
    _whiteSelected = widget.item.colors.contains('W');
    _blueSelected = widget.item.colors.contains('U');
    _blackSelected = widget.item.colors.contains('B');
    _redSelected = widget.item.colors.contains('R');
    _greenSelected = widget.item.colors.contains('G');

    // Load token definition to get artwork variants
    _loadTokenDefinition();
  }

  Future<void> _loadTokenDefinition() async {
    try {
      // PRIORITY 1: Use artworkOptions from item if available (persisted from creation)
      if (widget.item.artworkOptions != null && widget.item.artworkOptions!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _tokenDefinition = TokenDefinition(
              name: widget.item.name,
              abilities: widget.item.abilities,
              pt: widget.item.pt,
              colors: widget.item.colors,
              type: widget.item.type,
              popularity: 0,
              artwork: widget.item.artworkOptions!,
            );
          });
        }
        return;
      }

      // FALLBACK: Load from database (for legacy items or edited tokens)
      final database = TokenDatabase();
      await database.loadTokens();

      // Find matching token definition by comparing key properties
      final matchingToken = database.allTokens.firstWhere(
        (token) =>
            token.name == widget.item.name &&
            token.pt == widget.item.pt &&
            token.abilities == widget.item.abilities &&
            token.type == widget.item.type,
        orElse: () => TokenDefinition(
          name: widget.item.name,
          abilities: widget.item.abilities,
          pt: widget.item.pt,
          colors: widget.item.colors,
          type: widget.item.type,
          popularity: 0,
          artwork: [],
        ),
      );

      // Store artwork options on item for future use
      if (matchingToken.artwork.isNotEmpty) {
        widget.item.artworkOptions = List.from(matchingToken.artwork);
        widget.item.save();
      }

      if (mounted) {
        setState(() {
          _tokenDefinition = matchingToken;
        });
      }
    } catch (e) {
      print('Error loading token definition: $e');
    }
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

  void _showArtworkSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ArtworkSelectionSheet(
          artworkVariants: _tokenDefinition?.artwork ?? const [],
          onArtworkSelected: _handleArtworkSelected,
          onRemoveArtwork: widget.item.artworkUrl != null ? _removeArtwork : null,
          currentArtworkUrl: widget.item.artworkUrl,
          currentArtworkSet: widget.item.artworkSet,
          tokenName: widget.item.name,
          tokenIdentity: '${widget.item.name}|${widget.item.pt}|${widget.item.colors}|${widget.item.type}|${widget.item.abilities}',
        ),
      ),
    );
  }

  Future<void> _handleArtworkSelected(String url, String setCode) async {
    // Skip download for custom artwork (file:// URLs) - already local
    final isCustomArtwork = url.startsWith('file://');

    File? file;
    if (!isCustomArtwork) {
      // Download and cache Scryfall artwork if not already cached
      file = await ArtworkManager.downloadArtwork(url);
    } else {
      // Custom artwork - just verify file exists
      final localPath = url.replaceFirst('file://', '');
      final localFile = File(localPath);
      if (localFile.existsSync()) {
        file = localFile; // File exists, proceed
      }
    }

    if (file != null && mounted) {
      setState(() {
        widget.item.artworkUrl = url;
        widget.item.artworkSet = setCode;
      });

      widget.item.save();
      context.read<TokenProvider>().updateItem(widget.item);

      // Save artwork preference (Custom Artwork Feature)
      final artworkPrefManager = ArtworkPreferenceManager();
      final tokenIdentity = '${widget.item.name}|${widget.item.pt}|${widget.item.colors}|${widget.item.type}|${widget.item.abilities}';
      await artworkPrefManager.setPreferredArtwork(tokenIdentity, url);
    } else if (mounted) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCustomArtwork
            ? 'Custom artwork file not found.'
            : 'Failed to download artwork. Please check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeArtwork() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Artwork'),
        content: const Text('Are you sure you want to remove the artwork from this token?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        widget.item.artworkUrl = null;
        widget.item.artworkSet = null;
      });

      widget.item.save();
      context.read<TokenProvider>().updateItem(widget.item);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _numericController.dispose();
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
                // Name (70% width)
                Expanded(
                  flex: 7,
                  child: _buildEditableField(
                    label: 'Name',
                    field: EditableField.name,
                    value: widget.item.name,
                    onSave: (value) => widget.item.name = value,
                  ),
                ),
                const SizedBox(width: 12),
                // Stats (30% width)
                Expanded(
                  flex: 3,
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

            // Type and Artwork selection in a row
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Type (70% width)
                  Expanded(
                    flex: 7,
                    child: _buildEditableField(
                      label: 'Type',
                      field: EditableField.type,
                      value: widget.item.type,
                      onSave: (value) => widget.item.type = value,
                      placeholder: 'e.g., Creature — Elf Warrior',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Artwork selection (30% width)
                  Expanded(
                    flex: 3,
                    child: _buildArtworkSelectionBox(),
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
                      fieldId: 'amount',
                      onIncrement: () {
                        setState(() {
                          widget.item.amount++;
                          // Apply summoning sickness to new token if enabled AND token is a creature without Haste
                          if (summoningSicknessEnabled &&
                              widget.item.hasPowerToughness &&
                              !widget.item.hasHaste) {
                            widget.item.summoningSick++;
                          }
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
                          final oldAmount = widget.item.amount;
                          widget.item.amount = value;
                          // If amount increased, apply summoning sickness to new tokens
                          if (value > oldAmount &&
                              summoningSicknessEnabled &&
                              widget.item.hasPowerToughness &&
                              !widget.item.hasHaste) {
                            final addedTokens = value - oldAmount;
                            widget.item.summoningSick += addedTokens;
                          }
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
                        fieldId: 'tapped',
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
                            final clampedValue = value.clamp(0, widget.item.amount);
                            widget.item.tapped = clampedValue;
                            tokenProvider.updateItem(widget.item);
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
                          fieldId: 'summoningSick',
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
                              final clampedValue = value.clamp(0, widget.item.amount);
                              widget.item.summoningSick = clampedValue;
                              tokenProvider.updateItem(widget.item);
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
                        Builder(
                          builder: (context) {
                            final isEditingPlusOne = _editingNumericField == 'counter_plusOne';
                            return Row(
                              children: [
                                const Expanded(child: Text('+1/+1 Counters')),
                                IconButton(
                                  onPressed: isEditingPlusOne || currentItem.plusOneCounters <= 0
                                      ? null
                                      : () {
                                          if (_editingNumericField != null) {
                                            _saveNumericEdit();
                                          }
                                          setState(() {
                                            currentItem.addPowerToughnessCounters(-1);
                                            tokenProvider.updateItem(currentItem);
                                          });
                                        },
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color: isEditingPlusOne || currentItem.plusOneCounters <= 0 ? Theme.of(context).disabledColor : Colors.red,
                                  ),
                                ),
                                if (isEditingPlusOne)
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                                    child: TextField(
                                      controller: _numericController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      autofocus: true,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      onSubmitted: (_) => _saveNumericEdit((value) {
                                        setState(() {
                                          currentItem.plusOneCounters = value.clamp(0, kMaxCounterValue);
                                          tokenProvider.updateItem(currentItem);
                                        });
                                      }),
                                      onTapOutside: (_) => _saveNumericEdit((value) {
                                        setState(() {
                                          currentItem.plusOneCounters = value.clamp(0, kMaxCounterValue);
                                          tokenProvider.updateItem(currentItem);
                                        });
                                      }),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _editingNumericField = 'counter_plusOne';
                                        _numericController.text = currentItem.plusOneCounters.toString();
                                      });
                                    },
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 40),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                                  onPressed: isEditingPlusOne || currentItem.plusOneCounters >= kMaxCounterValue
                                      ? null
                                      : () {
                                          if (_editingNumericField != null) {
                                            _saveNumericEdit();
                                          }
                                          setState(() {
                                            currentItem.addPowerToughnessCounters(1);
                                            tokenProvider.updateItem(currentItem);
                                          });
                                        },
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: isEditingPlusOne || currentItem.plusOneCounters >= kMaxCounterValue ? Theme.of(context).disabledColor : Colors.green,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        // -1/-1 Counters
                        Builder(
                          builder: (context) {
                            final isEditingMinusOne = _editingNumericField == 'counter_minusOne';
                            return Row(
                              children: [
                                const Expanded(child: Text('-1/-1 Counters')),
                                IconButton(
                                  onPressed: isEditingMinusOne || currentItem.minusOneCounters <= 0
                                      ? null
                                      : () {
                                          if (_editingNumericField != null) {
                                            _saveNumericEdit();
                                          }
                                          setState(() {
                                            currentItem.addPowerToughnessCounters(1);
                                            tokenProvider.updateItem(currentItem);
                                          });
                                        },
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color: isEditingMinusOne || currentItem.minusOneCounters <= 0 ? Theme.of(context).disabledColor : Colors.red,
                                  ),
                                ),
                                if (isEditingMinusOne)
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                                    child: TextField(
                                      controller: _numericController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      autofocus: true,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      onSubmitted: (_) => _saveNumericEdit((value) {
                                        setState(() {
                                          currentItem.minusOneCounters = value.clamp(0, kMaxCounterValue);
                                          tokenProvider.updateItem(currentItem);
                                        });
                                      }),
                                      onTapOutside: (_) => _saveNumericEdit((value) {
                                        setState(() {
                                          currentItem.minusOneCounters = value.clamp(0, kMaxCounterValue);
                                          tokenProvider.updateItem(currentItem);
                                        });
                                      }),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _editingNumericField = 'counter_minusOne';
                                        _numericController.text = currentItem.minusOneCounters.toString();
                                      });
                                    },
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 40),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                                  onPressed: isEditingMinusOne || currentItem.minusOneCounters >= kMaxCounterValue
                                      ? null
                                      : () {
                                          if (_editingNumericField != null) {
                                            _saveNumericEdit();
                                          }
                                          setState(() {
                                            currentItem.addPowerToughnessCounters(-1);
                                            tokenProvider.updateItem(currentItem);
                                          });
                                        },
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: isEditingMinusOne || currentItem.minusOneCounters >= kMaxCounterValue ? Theme.of(context).disabledColor : Colors.green,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        if (currentItem.netPlusOneCounters != 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                            final counterId = 'counter_${counter.name}';
                            final isEditingCounter = _editingNumericField == counterId;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text('${counter.name} Counters')),
                                  IconButton(
                                    onPressed: isEditingCounter || counter.amount <= 0
                                        ? null
                                        : () {
                                            if (_editingNumericField != null) {
                                              _saveNumericEdit();
                                            }
                                            currentItem.removeCounter(name: counter.name);
                                            tokenProvider.updateItem(currentItem);
                                            setState(() {}); // Rebuild to update UI
                                          },
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: isEditingCounter || counter.amount <= 0 ? Theme.of(context).disabledColor : Colors.red,
                                    ),
                                  ),
                                  if (isEditingCounter)
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                                      child: TextField(
                                        controller: _numericController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        autofocus: true,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        onSubmitted: (_) => _saveNumericEdit((value) {
                                          counter.amount = value.clamp(0, kMaxCounterValue);
                                          tokenProvider.updateItem(currentItem);
                                          setState(() {}); // Rebuild to update UI
                                        }),
                                        onTapOutside: (_) => _saveNumericEdit((value) {
                                          counter.amount = value.clamp(0, kMaxCounterValue);
                                          tokenProvider.updateItem(currentItem);
                                          setState(() {}); // Rebuild to update UI
                                        }),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _editingNumericField = counterId;
                                          _numericController.text = counter.amount.toString();
                                        });
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(minWidth: 40),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                                    onPressed: isEditingCounter || counter.amount >= kMaxCounterValue
                                        ? null
                                        : () {
                                            if (_editingNumericField != null) {
                                              _saveNumericEdit();
                                            }
                                            currentItem.addCounter(name: counter.name);
                                            tokenProvider.updateItem(currentItem);
                                            setState(() {}); // Rebuild to update UI
                                          },
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: isEditingCounter || counter.amount >= kMaxCounterValue ? Theme.of(context).disabledColor : Colors.green,
                                    ),
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

  void _saveField(EditableField field) {
    // Guard against saving if widget is disposed or field is not being edited
    if (!mounted || _editingField != field) return;
    
    final newValue = _controllers[field]!.text;
    
    switch (field) {
      case EditableField.name:
        widget.item.name = newValue;
        break;
      case EditableField.powerToughness:
        widget.item.pt = newValue;
        break;
      case EditableField.type:
        widget.item.type = newValue;
        break;
      case EditableField.abilities:
        widget.item.abilities = newValue;
        break;
    }
    
    context.read<TokenProvider>().updateItem(widget.item);
    setState(() => _editingField = null);
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
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                    onSubmitted: (_) {
                      _saveField(field);
                    },
                  )
                : Text(
                    value.isEmpty ? placeholder : value,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isEmpty ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) : null,
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
    String? fieldId,
  }) {
    final isEditing = fieldId != null && _editingNumericField == fieldId;

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
            onPressed: isEditing || onDecrement == null
                ? null
                : () {
                    if (_editingNumericField != null) {
                      _saveNumericEdit();
                    }
                    onDecrement();
                  },
            icon: Icon(
              Icons.remove_circle,
              color: isEditing || onDecrement == null ? Theme.of(context).disabledColor : Colors.red,
            ),
          ),
        ],
        if (isEditing)
          Container(
            constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
            child: TextField(
              controller: _numericController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (_) => _saveNumericEdit(onManualSet),
              onTapOutside: (_) => _saveNumericEdit(onManualSet),
            ),
          )
        else
          GestureDetector(
            onTap: onManualSet != null
                ? () {
                    setState(() {
                      _editingNumericField = fieldId;
                      _numericController.text = value.toString();
                    });
                  }
                : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: onManualSet != null
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
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
            onPressed: isEditing || onIncrement == null
                ? null
                : () {
                    if (_editingNumericField != null) {
                      _saveNumericEdit();
                    }
                    onIncrement();
                  },
            icon: Icon(
              Icons.add_circle,
              color: isEditing || onIncrement == null ? Theme.of(context).disabledColor : Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  void _saveNumericEdit([Function(int)? onManualSet]) {
    final value = int.tryParse(_numericController.text);
    if (value != null && value >= 0 && onManualSet != null) {
      onManualSet(value);
    }
    setState(() {
      _editingNumericField = null;
    });
  }


  Widget _buildArtworkSelectionBox() {
    return GestureDetector(
      onTap: _showArtworkSelection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Artwork',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            // Display artwork thumbnail or "select" text
            if (widget.item.artworkUrl != null)
              FutureBuilder<File?>(
                future: ArtworkManager.getCachedArtworkFile(
                  widget.item.artworkUrl!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final file = snapshot.data!;
                    // Add unique key for custom artwork to force reload on replacement
                    final isCustomArtwork = widget.item.artworkUrl!.startsWith('file://');
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        key: isCustomArtwork ? ValueKey(file.path + file.lastModifiedSync().toString()) : null,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 60,
                      ),
                    );
                  }
                  return const SizedBox(height: 60);
                },
              )
            else
              Container(
                height: 60,
                alignment: Alignment.center,
                child: Text(
                  'select',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
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

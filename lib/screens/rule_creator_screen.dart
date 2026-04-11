import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/token_rule.dart';
import '../models/rule_trigger.dart';
import '../models/rule_outcome.dart';
import '../models/token_definition.dart' as token_models;
import '../providers/rules_provider.dart';
import 'token_search_screen.dart';
import '../utils/constants.dart';

class RuleCreatorScreen extends StatefulWidget {
  final TokenRule? existingRule;

  const RuleCreatorScreen({super.key, this.existingRule});

  @override
  State<RuleCreatorScreen> createState() => _RuleCreatorScreenState();
}

class _RuleCreatorScreenState extends State<RuleCreatorScreen> {
  final _nameController = TextEditingController();

  // Trigger state
  String _triggerType = 'any_token';
  String? _targetTokenId;
  String? _targetTokenDisplayName;
  String? _targetType;
  String? _targetColor;

  // Effects
  final List<_EffectState> _effects = [];

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingRule();
    } else {
      _effects.add(_EffectState());
    }
  }

  void _loadExistingRule() {
    final rule = widget.existingRule!;
    _nameController.text = rule.name;

    _triggerType = rule.trigger.triggerType;
    _targetTokenId = rule.trigger.targetTokenId;
    _targetType = rule.trigger.targetType;
    _targetColor = rule.trigger.targetColor;

    // Extract display name from targetTokenId (name is first segment before |)
    if (_targetTokenId != null && _targetTokenId!.contains('|')) {
      _targetTokenDisplayName = _targetTokenId!.split('|').first;
    }

    for (final outcome in rule.outcomes) {
      _effects.add(_EffectState(
        outcomeType: outcome.outcomeType,
        multiplier: outcome.multiplier,
        quantity: outcome.quantity,
        targetTokenId: outcome.targetTokenId,
        targetTokenDisplayName: outcome.targetTokenId != null &&
                outcome.targetTokenId!.contains('|')
            ? outcome.targetTokenId!.split('|').first
            : null,
      ));
    }

    if (_effects.isEmpty) {
      _effects.add(_EffectState());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_effects.isEmpty) return false;

    for (final effect in _effects) {
      if (effect.outcomeType == 'also_create' &&
          effect.targetTokenId == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rulesProvider = context.read<RulesProvider>();

    final trigger = RuleTrigger(
      triggerType: _triggerType,
      targetTokenId: _targetTokenId,
      targetType: _targetType,
      targetColor: _targetColor,
    );

    final outcomes = _effects.map((e) {
      return RuleOutcome(
        outcomeType: e.outcomeType,
        multiplier: e.multiplier,
        targetTokenId: e.targetTokenId,
        quantity: e.quantity,
      );
    }).toList();

    if (_isEditing) {
      final rule = widget.existingRule!;
      rule.name = _nameController.text.trim();
      rule.trigger = trigger;
      rule.outcomes = outcomes;
      await rulesProvider.updateRule(rule);
    } else {
      final rule = TokenRule(
        name: _nameController.text.trim(),
        trigger: trigger,
        outcomes: outcomes,
      );
      await rulesProvider.addRule(rule);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickToken({
    required void Function(String id, String displayName) onSelected,
  }) async {
    final result = await Navigator.of(context).push<token_models.TokenDefinition>(
      MaterialPageRoute(
        builder: (context) => const TokenSearchScreen(selectorMode: true),
      ),
    );

    if (result != null) {
      onSelected(result.id, result.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        leadingWidth: 80,
        title: Text(_isEditing ? 'Edit Rule' : 'New Rule'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rule name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rule Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 24),

            // Trigger section
            Text(
              'Trigger',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTriggerSection(),

            const SizedBox(height: 24),

            // Effects section
            Text(
              'Effects',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._buildEffectRows(),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _effects.add(_EffectState())),
              icon: const Icon(Icons.add),
              label: const Text('Add Effect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _triggerType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(value: 'any_token', child: Text('Any token')),
            DropdownMenuItem(
                value: 'has_pt', child: Text('A token with P/T')),
            DropdownMenuItem(
                value: 'token_type', child: Text('A token of type...')),
            DropdownMenuItem(
                value: 'color', child: Text('A token of color...')),
            DropdownMenuItem(
                value: 'specific_token',
                child: Text('A specific token...')),
          ],
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _triggerType = val;
              // Reset conditional fields
              _targetTokenId = null;
              _targetTokenDisplayName = null;
              _targetType = null;
              _targetColor = null;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildTriggerConditional(),
      ],
    );
  }

  Widget _buildTriggerConditional() {
    switch (_triggerType) {
      case 'token_type':
        return _buildTypeSelector();
      case 'color':
        return _buildColorSelector();
      case 'specific_token':
        return _buildTokenPicker();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTypeSelector() {
    final types = ['Creature', 'Artifact', 'Enchantment'];
    return Wrap(
      spacing: 8,
      children: types.map((type) {
        return FilterChip(
          label: Text(type),
          selected: _targetType == type,
          showCheckmark: false,
          onSelected: (selected) {
            setState(() => _targetType = selected ? type : null);
          },
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector() {
    final colors = {
      'W': ('White', Colors.yellow.shade700),
      'U': ('Blue', Colors.blue),
      'B': ('Black', Colors.purple),
      'R': ('Red', Colors.red),
      'G': ('Green', Colors.green),
    };

    return Wrap(
      spacing: 8,
      children: colors.entries.map((entry) {
        return FilterChip(
          label: Text(entry.value.$1),
          selected: _targetColor == entry.key,
          showCheckmark: false,
          avatar: CircleAvatar(
            backgroundColor: entry.value.$2,
            radius: 8,
          ),
          onSelected: (selected) {
            setState(() => _targetColor = selected ? entry.key : null);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTokenPicker() {
    return OutlinedButton.icon(
      onPressed: () => _pickToken(
        onSelected: (id, name) {
          setState(() {
            _targetTokenId = id;
            _targetTokenDisplayName = name;
          });
        },
      ),
      icon: const Icon(Icons.search),
      label: Text(_targetTokenDisplayName ?? 'Select Token'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  List<Widget> _buildEffectRows() {
    return List.generate(_effects.length, (index) {
      final effect = _effects[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _EffectRow(
          effect: effect,
          onChanged: () => setState(() {}),
          onPickToken: () => _pickToken(
            onSelected: (id, name) {
              setState(() {
                effect.targetTokenId = id;
                effect.targetTokenDisplayName = name;
              });
            },
          ),
          onDelete: _effects.length > 1
              ? () => setState(() => _effects.removeAt(index))
              : null,
        ),
      );
    });
  }
}

class _EffectState {
  String outcomeType;
  int multiplier;
  int quantity;
  String? targetTokenId;
  String? targetTokenDisplayName;

  _EffectState({
    this.outcomeType = 'multiply',
    this.multiplier = 2,
    this.quantity = 1,
    this.targetTokenId,
    this.targetTokenDisplayName,
  });
}

class _EffectRow extends StatelessWidget {
  final _EffectState effect;
  final VoidCallback onChanged;
  final VoidCallback onPickToken;
  final VoidCallback? onDelete;

  const _EffectRow({
    required this.effect,
    required this.onChanged,
    required this.onPickToken,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: effect.outcomeType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'multiply', child: Text('Multiply')),
                    DropdownMenuItem(
                        value: 'also_create', child: Text('Also create')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    effect.outcomeType = val;
                    onChanged();
                  },
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove effect',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (effect.outcomeType == 'multiply') _buildMultiplyRow(context),
          if (effect.outcomeType == 'also_create')
            _buildAlsoCreateRow(context),
        ],
      ),
    );
  }

  Widget _buildMultiplyRow(BuildContext context) {
    return Row(
      children: [
        const Text('Multiply by '),
        SizedBox(
          width: 60,
          child: TextFormField(
            initialValue: '${effect.multiplier}',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: (val) {
              effect.multiplier = int.tryParse(val) ?? 2;
              onChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlsoCreateRow(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: TextFormField(
            initialValue: '${effect.quantity}',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: (val) {
              effect.quantity = int.tryParse(val) ?? 1;
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickToken,
            icon: const Icon(Icons.search, size: 18),
            label: Text(
              effect.targetTokenDisplayName ?? 'Select Token',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

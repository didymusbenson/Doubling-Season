import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/krenko_utility.dart';
import '../models/token_definition.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/expanded_widget_screen.dart';
import '../utils/constants.dart';
import '../utils/color_utils.dart';
import 'cropped_artwork_widget.dart';

class KrenkoUtilityCard extends StatefulWidget {
  final KrenkoUtility krenko;

  const KrenkoUtilityCard({required this.krenko, super.key});

  @override
  State<KrenkoUtilityCard> createState() => _KrenkoUtilityCardState();
}

class _KrenkoUtilityCardState extends State<KrenkoUtilityCard> {
  bool _showArtwork = false;
  DateTime? _cardCreationTime;

  @override
  void initState() {
    super.initState();
    _cardCreationTime = DateTime.now();
    _showArtwork = widget.krenko.artworkUrl != null;
  }

  @override
  void didUpdateWidget(KrenkoUtilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.krenko.artworkUrl != oldWidget.krenko.artworkUrl) {
      setState(() {
        _showArtwork = widget.krenko.artworkUrl != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorIdentity = widget.krenko.colorIdentity;
    final gradient = ColorUtils.gradientForColors(colorIdentity);

    return GestureDetector(
      onTap: () => _openExpandedView(context),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: UIConstants.standardPadding,
          vertical: UIConstants.verticalSpacing,
        ),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: UIConstants.shadowOpacity),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: UIConstants.lightShadowOpacity),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(UIConstants.borderRadius - UIConstants.borderWidth),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(UIConstants.borderRadius - UIConstants.borderWidth),
            child: Stack(
              children: [
                // Artwork layer (if present)
                if (_showArtwork && widget.krenko.artworkUrl != null)
                  _buildArtworkLayer(context),

                // Content layer
                Padding(
                  padding: const EdgeInsets.all(UIConstants.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      _buildTextWithBackground(
                        child: Text(
                          widget.krenko.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Krenko's Power row
                      _buildValueRow(
                        label: "Krenko's Power:",
                        value: widget.krenko.krenkoPower,
                        onDecrement: () => _updatePower(-1),
                        onIncrement: () => _updatePower(1),
                        onTapValue: () => _editPowerManually(context),
                      ),
                      const SizedBox(height: 8),

                      // Nontoken Goblins row
                      _buildValueRow(
                        label: 'Nontoken Goblins:',
                        value: widget.krenko.nontokenGoblins,
                        onDecrement: () => _updateNontokenGoblins(-1),
                        onIncrement: () => _updateNontokenGoblins(1),
                        onTapValue: () => _editNontokenGoblinsManually(context),
                      ),
                      const SizedBox(height: 12),

                      // WAAAGH! Button
                      _buildTextWithBackground(
                        child: ElevatedButton(
                          onPressed: () => _showWaaaghDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'WAAAGH!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow({
    required String label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required VoidCallback onTapValue,
  }) {
    return _buildTextWithBackground(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          GestureDetector(
            onTap: onTapValue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
            iconSize: 20,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
            iconSize: 20,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextWithBackground({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }

  Widget _buildArtworkLayer(BuildContext context) {
    return Selector<SettingsProvider, String>(
      selector: (_, settings) => settings.artworkDisplayStyle,
      builder: (context, artworkDisplayStyle, _) {
        final artworkUrl = widget.krenko.artworkUrl;
        if (artworkUrl == null) return const SizedBox.shrink();

        return Positioned.fill(
          child: CroppedArtworkWidget(
            artworkUrl: artworkUrl,
            fillWidth: artworkDisplayStyle == 'fullView',
            fadeIn: DateTime.now().difference(_cardCreationTime ?? DateTime.now()).inMilliseconds > 100,
          ),
        );
      },
    );
  }

  void _updatePower(int delta) {
    setState(() {
      widget.krenko.krenkoPower = (widget.krenko.krenkoPower + delta).clamp(1, 99);
      widget.krenko.save();
    });
  }

  void _updateNontokenGoblins(int delta) {
    setState(() {
      widget.krenko.nontokenGoblins = (widget.krenko.nontokenGoblins + delta).clamp(0, 99);
      widget.krenko.save();
    });
  }

  void _editPowerManually(BuildContext context) {
    final controller = TextEditingController(text: widget.krenko.krenkoPower.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Krenko's Power"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter power (1-99)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? widget.krenko.krenkoPower;
              setState(() {
                widget.krenko.krenkoPower = newValue.clamp(1, 99);
                widget.krenko.save();
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editNontokenGoblinsManually(BuildContext context) {
    final controller = TextEditingController(text: widget.krenko.nontokenGoblins.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Nontoken Goblins'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter count (0-99)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? widget.krenko.nontokenGoblins;
              setState(() {
                widget.krenko.nontokenGoblins = newValue.clamp(0, 99);
                widget.krenko.save();
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showWaaaghDialog(BuildContext context) {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final multiplier = settingsProvider.tokenMultiplier;

    // Count token goblins
    int tokenGoblinCount = 0;
    for (final item in tokenProvider.items) {
      final type = item.type?.toLowerCase() ?? '';
      if (type.contains('goblin')) {
        tokenGoblinCount += item.amount;
      }
    }

    final byPower = widget.krenko.calculateByPower(multiplier);
    final byGoblins = widget.krenko.calculateByGoblinsControlled(tokenGoblinCount, multiplier);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Goblin Tokens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Krenko's Power: $byPower goblins",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'All Goblins: $byGoblins goblins',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _createGoblins(context, byPower);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Create $byPower Goblins'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _createGoblins(context, byGoblins);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Create $byGoblins Goblins'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGoblins(BuildContext context, int amount) async {
    final tokenProvider = context.read<TokenProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // Standard goblin token definition
    final goblinDefinition = TokenDefinition(
      name: 'Goblin',
      abilities: '',
      pt: '1/1',
      colors: 'R',
      type: 'Creature — Goblin',
    );

    // Check if matching goblin token already exists
    final existingGoblin = tokenProvider.items.where((item) {
      return item.name == 'Goblin' &&
          item.pt == '1/1' &&
          item.colors == 'R' &&
          (item.type?.toLowerCase().contains('goblin') ?? false) &&
          item.abilities.isEmpty;
    }).firstOrNull;

    if (existingGoblin != null) {
      // Add to existing token
      existingGoblin.amount += amount;
      existingGoblin.save();
    } else {
      // Create new token
      final newGoblin = goblinDefinition.toItem(
        amount: amount,
        createTapped: false,
      );
      await tokenProvider.insertItem(newGoblin);

      // Apply summoning sickness if enabled
      if (settingsProvider.summoningSicknessEnabled &&
          newGoblin.hasPowerToughness &&
          !newGoblin.hasHaste) {
        newGoblin.summoningSick = amount;
      }
    }
  }

  void _openExpandedView(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpandedWidgetScreen(widget: widget.krenko),
      ),
    );
  }
}

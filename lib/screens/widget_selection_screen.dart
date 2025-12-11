import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/widget_definition.dart';
import '../database/widget_database.dart';
import '../providers/token_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';
import '../widgets/new_tracker_sheet.dart';
import '../widgets/new_toggle_sheet.dart';
import '../utils/constants.dart';

class WidgetSelectionScreen extends StatefulWidget {
  const WidgetSelectionScreen({super.key});

  @override
  State<WidgetSelectionScreen> createState() => _WidgetSelectionScreenState();
}

class _WidgetSelectionScreenState extends State<WidgetSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final WidgetDatabase _widgetDatabase = WidgetDatabase();

  // Search debouncing
  Timer? _searchDebounceTimer;
  static const _searchDebounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _widgetDatabase.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      _widgetDatabase.searchQuery = _searchController.text;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _widgetDatabase.clearFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchFocusNode.hasFocus ? null : const Text('Select Utility'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_widgetDatabase.selectedType != null || _searchController.text.isNotEmpty)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Type Filter Chips
          _buildTypeFilter(),

          // Custom Creation Buttons
          _buildCustomCreationButtons(),

          // Widget List
          Expanded(
            child: _buildWidgetList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(UIConstants.standardPadding),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search utilities...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _widgetDatabase.searchQuery = '';
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UIConstants.standardPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', null),
            const SizedBox(width: 8),
            _buildFilterChip('Tracker', WidgetType.tracker),
            const SizedBox(width: 8),
            _buildFilterChip('Toggle', WidgetType.toggle),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, WidgetType? type) {
    final isSelected = _widgetDatabase.selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _widgetDatabase.selectedType = selected ? type : null;
        });
      },
    );
  }

  Widget _buildCustomCreationButtons() {
    return Padding(
      padding: const EdgeInsets.all(UIConstants.standardPadding),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showNewTrackerSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Tracker'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showNewToggleSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Toggle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetList() {
    return ListenableBuilder(
      listenable: _widgetDatabase,
      builder: (context, child) {
        if (!_widgetDatabase.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final widgets = _widgetDatabase.filteredWidgets;

        if (widgets.isEmpty) {
          return Center(
            child: Text(
              'No utilities found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView.builder(
          itemCount: widgets.length,
          itemBuilder: (context, index) {
            final widget = widgets[index];
            return _buildWidgetTile(widget);
          },
        );
      },
    );
  }

  Widget _buildWidgetTile(WidgetDefinition widget) {
    return ListTile(
      leading: Icon(
        widget.type == WidgetType.tracker ? Icons.show_chart : Icons.toggle_on,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(widget.name),
      subtitle: Text(
        widget.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Chip(
        label: Text(
          widget.type == WidgetType.tracker ? 'Tracker' : 'Toggle',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: widget.type == WidgetType.tracker
            ? Colors.blue.withValues(alpha: 0.2)
            : Colors.purple.withValues(alpha: 0.2),
      ),
      onTap: () => _createWidget(widget),
    );
  }

  void _createWidget(WidgetDefinition definition) async {
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

    if (definition.type == WidgetType.tracker) {
      final tracker = definition.toTrackerWidget(order: newOrder);
      await trackerProvider.insertTracker(tracker);
    } else if (definition.type == WidgetType.toggle) {
      final toggle = definition.toToggleWidget(order: newOrder);
      await toggleProvider.insertToggle(toggle);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showNewTrackerSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NewTrackerSheet(),
      ),
    );
  }

  void _showNewToggleSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NewToggleSheet(),
      ),
    );
  }
}

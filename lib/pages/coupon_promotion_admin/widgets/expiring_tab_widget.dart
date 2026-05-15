import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

typedef ExpiringCardBuilder = Widget Function(BuildContext context, Map<String, dynamic> item);

class ExpiringTabWidget extends StatelessWidget {
  const ExpiringTabWidget({
    super.key,
    required this.items,
    required this.isLoading,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.emptyIcon,
    required this.expiryFilter,
    required this.onFilterChanged,
    required this.cardBuilder,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String emptyMessage;
  final String emptySubMessage;
  final IconData emptyIcon;
  final String expiryFilter;
  final ValueChanged<String> onFilterChanged;
  final ExpiringCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(emptyMessage, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 8),
            Text(emptySubMessage, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return Column(
      children: [
        _ExpiryFilterChips(selected: expiryFilter, onSelected: onFilterChanged),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => cardBuilder(context, items[index]),
          ),
        ),
      ],
    );
  }
}

class _ExpiryFilterChips extends StatelessWidget {
  const _ExpiryFilterChips({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'key': '3days', 'label': '3 วัน', 'color': Colors.red},
      {'key': '7days', 'label': '7 วัน', 'color': Colors.orange},
      {'key': '14days', 'label': '14 วัน', 'color': Colors.yellow.shade700},
      {'key': '30days', 'label': '30 วัน', 'color': Colors.blue},
      {'key': 'expired', 'label': 'หมดอายุแล้ว', 'color': Colors.red.shade900},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) {
          final key = filter['key'] as String;
          final color = filter['color'] as Color;
          final isSelected = selected == key;
          return ChoiceChip(
            label: Text(filter['label'] as String),
            selected: isSelected,
            selectedColor: color.withOpacity(0.2),
            backgroundColor: Colors.white.withOpacity(0.1),
            labelStyle: TextStyle(color: isSelected ? color : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            onSelected: (value) {
              if (value) onSelected(key);
            },
          );
        }).toList(),
      ),
    );
  }
}

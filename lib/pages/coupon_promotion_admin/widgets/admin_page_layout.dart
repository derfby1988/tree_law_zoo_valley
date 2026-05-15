import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

class AdminPageLayout extends StatelessWidget {
  const AdminPageLayout({
    super.key,
    required this.title,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.tabLabels,
    required this.body,
    this.floatingAction,
  });

  final String title;
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final List<String> tabLabels;
  final Widget body;
  final FloatingActionButton? floatingAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      floatingActionButton: floatingAction,
      backgroundColor: AppDesignSystem.primary,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabLabels.asMap().entries.map((entry) {
                final index = entry.key;
                final label = entry.value;
                final isSelected = index == selectedTabIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabSelected(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: AppDesignSystem.primary, width: 2) : null,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppDesignSystem.primary : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

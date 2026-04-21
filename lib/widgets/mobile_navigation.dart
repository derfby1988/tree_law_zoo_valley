import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';

/// Mobile bottom navigation item
class MobileNavItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  MobileNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });
}

/// Mobile bottom navigation bar
class MobileBottomNavBar extends StatelessWidget {
  final List<MobileNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const MobileBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemSelected,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppDesignSystem.surface,
      selectedItemColor: AppDesignSystem.primary,
      unselectedItemColor: AppDesignSystem.textSecondary,
      items: items
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ))
          .toList(),
    );
  }
}

/// Mobile drawer menu
class MobileDrawerMenu extends StatelessWidget {
  final String? userEmail;
  final String? userName;
  final List<DrawerMenuItem> items;
  final VoidCallback? onLogout;

  const MobileDrawerMenu({
    super.key,
    this.userEmail,
    this.userName,
    required this.items,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppDesignSystem.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (userName != null)
                  Text(
                    userName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (userEmail != null)
                  Text(
                    userEmail!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          ...items.map((item) => ListTile(
                leading: Icon(item.icon, color: AppDesignSystem.textPrimary),
                title: Text(item.label),
                onTap: item.onTap,
              )),
          const Divider(),
          if (onLogout != null)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ออกจากระบบ'),
              onTap: onLogout,
            ),
        ],
      ),
    );
  }
}

/// Drawer menu item
class DrawerMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  DrawerMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// Mobile action menu (popup menu for actions)
class MobileActionMenu extends StatelessWidget {
  final List<MobileActionItem> items;

  const MobileActionMenu({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        final item = items.firstWhere((i) => i.id == value);
        item.onTap();
      },
      itemBuilder: (BuildContext context) => items
          .map((item) => PopupMenuItem<String>(
                value: item.id,
                child: Row(
                  children: [
                    Icon(item.icon, color: AppDesignSystem.textPrimary),
                    const SizedBox(width: 12),
                    Text(item.label),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

/// Mobile action item
class MobileActionItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  MobileActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// Mobile search bar
class MobileSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String? hintText;

  const MobileSearchBar({
    super.key,
    required this.onChanged,
    this.onClear,
    this.hintText,
  });

  @override
  State<MobileSearchBar> createState() => _MobileSearchBarState();
}

class _MobileSearchBarState extends State<MobileSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignSystem.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignSystem.border),
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'ค้นหา...',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear?.call();
                    widget.onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
      ),
    );
  }
}

/// Mobile filter chip
class MobileFilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const MobileFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<MobileFilterChip> createState() => _MobileFilterChipState();
}

class _MobileFilterChipState extends State<MobileFilterChip> {
  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(widget.label),
      selected: widget.isSelected,
      onSelected: widget.onSelected,
      backgroundColor: AppDesignSystem.background,
      selectedColor: AppDesignSystem.primary.withOpacity(0.2),
      side: BorderSide(
        color: widget.isSelected ? AppDesignSystem.primary : AppDesignSystem.border,
      ),
    );
  }
}

/// Mobile tab bar (horizontal scrollable)
class MobileTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const MobileTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          tabs.length,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(tabs[index]),
              selected: selectedIndex == index,
              onSelected: (_) => onTabSelected(index),
              backgroundColor: AppDesignSystem.background,
              selectedColor: AppDesignSystem.primary,
              labelStyle: TextStyle(
                color: selectedIndex == index ? Colors.white : AppDesignSystem.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

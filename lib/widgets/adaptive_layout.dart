import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// Adaptive layout widget that changes based on screen size
class AdaptiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const AdaptiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      return mobileLayout;
    } else if (ResponsiveHelper.isTablet(context)) {
      return tabletLayout ?? mobileLayout;
    } else {
      return desktopLayout ?? tabletLayout ?? mobileLayout;
    }
  }
}

/// Adaptive scaffold with responsive app bar and navigation
class AdaptiveScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final List<BottomNavigationBarItem>? bottomNavItems;
  final ValueChanged<int>? onBottomNavChanged;
  final int? selectedBottomNavIndex;
  final Drawer? drawer;
  final PreferredSizeWidget? bottomAppBar;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.appBarActions,
    this.floatingActionButton,
    this.bottomNavItems,
    this.onBottomNavChanged,
    this.selectedBottomNavIndex,
    this.drawer,
    this.bottomAppBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: appBarActions,
        bottom: bottomAppBar,
      ),
      body: body,
      drawer: ResponsiveHelper.isMobile(context) ? drawer : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavItems != null && onBottomNavChanged != null
          ? BottomNavigationBar(
              items: bottomNavItems!,
              currentIndex: selectedBottomNavIndex ?? 0,
              onTap: onBottomNavChanged,
              type: BottomNavigationBarType.fixed,
            )
          : null,
    );
  }
}

/// Adaptive card layout
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPadding = ResponsiveHelper.getResponsivePadding(context);
    final finalPadding = padding ?? defaultPadding;

    return Card(
      elevation: elevation ?? 0,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: finalPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Adaptive list view
class AdaptiveListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final bool shrinkWrap;

  const AdaptiveListView({
    super.key,
    required this.children,
    this.physics,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPadding = ResponsiveHelper.getResponsivePadding(context);
    final finalPadding = padding ?? defaultPadding;

    return ListView(
      padding: finalPadding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      children: children,
    );
  }
}

/// Adaptive grid view
class AdaptiveGridView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  final double? spacing;
  final bool shrinkWrap;

  const AdaptiveGridView({
    super.key,
    required this.children,
    this.padding,
    this.spacing,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.getGridColumns(context);
    final defaultSpacing = ResponsiveHelper.getResponsiveSpacing(context);
    final finalSpacing = spacing ?? defaultSpacing;
    final defaultPadding = ResponsiveHelper.getResponsivePadding(context);
    final finalPadding = padding ?? defaultPadding;

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: finalSpacing,
      mainAxisSpacing: finalSpacing,
      padding: finalPadding,
      shrinkWrap: shrinkWrap,
      childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.5 : 1.2,
      children: children,
    );
  }
}

/// Adaptive dialog
class AdaptiveDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final bool barrierDismissible;

  const AdaptiveDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      return Dialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: content,
              ),
              if (actions != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      return AlertDialog(
        title: Text(title),
        content: content,
        actions: actions,
      );
    }
  }
}

/// Adaptive button
class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            label: Text(label),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Adaptive text field
class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

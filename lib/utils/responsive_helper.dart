import 'package:flutter/material.dart';

/// Responsive breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Responsive helper class
class ResponsiveHelper {
  /// Check if device is mobile (< 600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }

  /// Check if device is tablet (600px - 900px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile && width < ResponsiveBreakpoints.tablet;
  }

  /// Check if device is desktop (>= 900px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tablet;
  }

  /// Get device type
  static String getDeviceType(BuildContext context) {
    if (isMobile(context)) return 'mobile';
    if (isTablet(context)) return 'tablet';
    return 'desktop';
  }

  /// Get responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16);
    }
    return const EdgeInsets.all(24);
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    required double mobileSize,
    double? tabletSize,
    double? desktopSize,
  }) {
    if (isMobile(context)) return mobileSize;
    if (isTablet(context)) return tabletSize ?? mobileSize + 2;
    return desktopSize ?? mobileSize + 4;
  }

  /// Get responsive width for cards
  static double getCardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isMobile(context)) return width - 32;
    if (isTablet(context)) return (width - 48) / 2;
    return (width - 72) / 3;
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context) {
    if (isMobile(context)) return 8;
    if (isTablet(context)) return 12;
    return 16;
  }

  /// Check if device is in landscape
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }
}

/// Responsive widget builder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, String deviceType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, ResponsiveHelper.getDeviceType(context));
  }
}

/// Responsive grid view
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  final double? spacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.padding,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.getGridColumns(context);
    final defaultSpacing = ResponsiveHelper.getResponsiveSpacing(context);
    final finalSpacing = spacing ?? defaultSpacing;
    final finalPadding = padding ?? ResponsiveHelper.getResponsivePadding(context);

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: finalSpacing,
      mainAxisSpacing: finalSpacing,
      padding: finalPadding,
      childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.5 : 1.2,
      children: children,
    );
  }
}

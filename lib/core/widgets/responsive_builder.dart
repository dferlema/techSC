import 'package:flutter/material.dart';

enum ScreenSize { mobile, tablet, desktop, wide }

class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
  static const double wide = 1920;

  static ScreenSize getScreenSize(double width) {
    if (width < mobile) return ScreenSize.mobile;
    if (width < tablet) return ScreenSize.tablet;
    if (width < desktop) return ScreenSize.desktop;
    return ScreenSize.wide;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = ResponsiveBreakpoints.getScreenSize(constraints.maxWidth);
        return builder(context, screenSize);
      },
    );
  }
}

class ResponsiveConstraints extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveConstraints({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final limit = maxWidth ?? 1400;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: child,
      ),
    );
  }
}

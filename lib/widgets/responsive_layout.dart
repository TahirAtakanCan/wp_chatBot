import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  static const double mobileBreakpoint = 768;

  final Widget mobile;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < mobileBreakpoint ? mobile : desktop;
  }
}

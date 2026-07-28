/// Convenience extensions used across the app.
library;
import 'package:flutter/material.dart';

/// Quick access to theme data from [BuildContext].
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Quick access to media query from [BuildContext].
extension MediaQueryExtension on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
}

/// Navigation helpers.
extension NavigationExtension on BuildContext {
  void popNavigator<T>([T? result]) => Navigator.of(this).pop(result);
}

/// String formatting helpers.
extension StringExtension on String {
  /// Pads a number string to [width] digits with leading zeros.
  String padNumber(int width) => padLeft(width, '0');
}

/// Integer formatting helpers.
extension IntExtension on int {
  /// Zero-pads this integer to [width] characters.
  String zeroPad(int width) => toString().padLeft(width, '0');
}

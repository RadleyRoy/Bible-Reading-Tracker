import 'package:flutter/material.dart';

/// App colors from the "Navigation bar" palette:
/// https://octet.design/colors/palette/navigation-bar-color-palette-1731928172/
///
/// #656567 gray · #0D51FB blue · #343537 dark gray
/// #103693 navy · #1F1F1F charcoal · #050505 black
const paletteGray = Color(0xFF656567);
const paletteBlue = Color(0xFF0D51FB);
const paletteDarkGray = Color(0xFF343537);
const paletteNavy = Color(0xFF103693);
const paletteCharcoal = Color(0xFF1F1F1F);
const paletteBlack = Color(0xFF050505);

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: paletteBlue).copyWith(
    primary: paletteBlue,
    onPrimary: Colors.white,
    secondary: paletteNavy,
    onSecondary: Colors.white,
    onSurface: paletteCharcoal,
    onSurfaceVariant: paletteDarkGray,
    outline: paletteGray,
  );
  return ThemeData(colorScheme: scheme);
}

ThemeData darkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: paletteBlue,
        brightness: Brightness.dark,
      ).copyWith(
        secondary: paletteGray,
        surface: paletteBlack,
        surfaceContainerLow: paletteCharcoal,
        surfaceContainer: paletteCharcoal,
        surfaceContainerHighest: paletteDarkGray,
        outline: paletteGray,
      );
  return ThemeData(colorScheme: scheme);
}

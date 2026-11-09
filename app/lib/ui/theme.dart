import 'package:flutter/material.dart';

import '../models/open_status.dart';
import '../models/store.dart';

abstract final class Palette {
  static const cream = Color(0xFFFFF8EE);
  static const dough = Color(0xFFF6E7D2);
  static const crust = Color(0xFFC98B4E);
  static const cocoa = Color(0xFF5B3A22);
  static const espresso = Color(0xFF3A2416);
  static const butter = Color(0xFFF3C25B);
  static const berry = Color(0xFFD9667B);
  static const mint = Color(0xFF4FA89A);
  static const muted = Color(0xFF8C7765);
}

Color categoryColor(StoreCategory c) => switch (c) {
      StoreCategory.bakery => Palette.crust,
      StoreCategory.dessert => Palette.berry,
      StoreCategory.frozen => Palette.mint,
    };

IconData categoryIcon(StoreCategory c) => switch (c) {
      StoreCategory.bakery => Icons.bakery_dining_rounded,
      StoreCategory.dessert => Icons.cake_rounded,
      StoreCategory.frozen => Icons.icecream_rounded,
    };

Color statusColor(OpenState s) => switch (s) {
      OpenState.open => const Color(0xFF3E8E5A),
      OpenState.breakTime => const Color(0xFFCC8A1E),
      OpenState.closed || OpenState.dayOff => const Color(0xFFB54A3C),
      OpenState.unknown => Palette.muted,
    };

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.cocoa,
    primary: Palette.cocoa,
    secondary: Palette.butter,
    surface: Palette.cream,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: Palette.cream);
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.cream,
      foregroundColor: Palette.espresso,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Palette.espresso, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    textTheme: base.textTheme.apply(bodyColor: Palette.espresso, displayColor: Palette.espresso),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: Palette.dough,
      side: const BorderSide(color: Palette.dough),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: Palette.espresso, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Palette.dough,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: Palette.cocoa, foregroundColor: Colors.white),
    ),
  );
}

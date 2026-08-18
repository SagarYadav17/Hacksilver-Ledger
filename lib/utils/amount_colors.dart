import 'package:flutter/material.dart';
import '../models/category.dart';

/// Finance colors stay stable when users choose a different app seed color.
abstract final class FinancialColors {
  static const _mintLight = Color(0xFF006C4C);
  static const _mintDark = Color(0xFF5DDBA7);
  static const _cyanLight = Color(0xFF006782);
  static const _cyanDark = Color(0xFF5AD8FF);
  static const _violetLight = Color(0xFF6B45B1);
  static const _violetDark = Color(0xFFD3BAFF);
  static const _redLight = Color(0xFFBA1A1A);
  static const _redDark = Color(0xFFFFB4AB);

  static Color mint(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? _mintDark : _mintLight;

  static Color cyan(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? _cyanDark : _cyanLight;

  static Color violet(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? _violetDark : _violetLight;

  static Color red(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? _redDark : _redLight;
}

Color availableColor(ColorScheme scheme) => FinancialColors.mint(scheme);
Color incomeColor(ColorScheme scheme) => FinancialColors.mint(scheme);
Color plannedColor(ColorScheme scheme) => FinancialColors.cyan(scheme);
Color groupingColor(ColorScheme scheme) => FinancialColors.violet(scheme);
Color expenseColor(ColorScheme scheme) => FinancialColors.red(scheme);
Color transferColor(ColorScheme scheme) => groupingColor(scheme);

Color amountColorForType(ColorScheme scheme, CategoryType type) {
  switch (type) {
    case CategoryType.income:
      return incomeColor(scheme);
    case CategoryType.expense:
      return expenseColor(scheme);
    case CategoryType.transfer:
      return transferColor(scheme);
  }
}

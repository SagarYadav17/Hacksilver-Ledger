import 'package:flutter/material.dart';
import '../models/category.dart';

/// Single source of truth for semantic amount colors: green=in, red=out, blue=transfer.
Color incomeColor(ColorScheme scheme) => scheme.primary;
Color expenseColor(ColorScheme scheme) => scheme.error;
Color transferColor(ColorScheme scheme) => scheme.tertiary;

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

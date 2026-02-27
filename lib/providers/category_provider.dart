import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../constants/app_constants.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  final DatabaseService _dbService = DatabaseService();

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _dbService.getCategories();
      _error = null;
    } catch (e) {
      _error = AppConstants.errorLoadingCategories;
      debugPrint('Error fetching categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(Category category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _dbService.insertCategory(category);
      await fetchCategories();
    } catch (e) {
      _error = 'Failed to add category';
      debugPrint('Error adding category: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _dbService.deleteCategory(id);
      await fetchCategories();
    } catch (e) {
      _error = 'Failed to delete category';
      debugPrint('Error deleting category: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initCategories() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await fetchCategories();

      // Seed default categories if empty
      if (_categories.isEmpty) {
        final defaultCategories = [
          Category(
            name: 'Salary',
            iconCode: 0xe4b5, // monetization_on
            colorValue: 0xFF4CAF50,
            type: CategoryType.income,
            isCustom: false,
          ),
          Category(
            name: 'Food',
            iconCode: 0xe532, // restaurant
            colorValue: 0xFFF44336,
            type: CategoryType.expense,
            isCustom: false,
          ),
          Category(
            name: 'Transport',
            iconCode: 0xe1d5, // directions_car
            colorValue: 0xFF2196F3,
            type: CategoryType.expense,
            isCustom: false,
          ),
          Category(
            name: 'Shopping', // shopping_cart
            iconCode: 0xe59c,
            colorValue: 0xFF9C27B0,
            type: CategoryType.expense,
            isCustom: false,
          ),
          Category(
            name: 'Bills', // receipt
            iconCode: 0xe896,
            colorValue: 0xFFFF9800,
            type: CategoryType.expense,
            isCustom: false,
          ),
        ];

        for (var category in defaultCategories) {
          await _dbService.insertCategory(category);
        }
        await fetchCategories();
      }

      // Ensure Transfer category exists (for existing users upgrading)
      if (!_categories.any((c) => c.type == CategoryType.transfer)) {
        await _dbService.insertCategory(
          Category(
            name: 'Transfer',
            iconCode: 0xe8d4, // swap_horiz
            colorValue: 0xFF2196F3, // blue
            type: CategoryType.transfer,
            isCustom: false,
          ),
        );
        await fetchCategories();
      }
    } catch (e) {
      _error = AppConstants.errorLoadingCategories;
      debugPrint('Error initializing categories: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

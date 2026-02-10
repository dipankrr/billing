import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

class ProductProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Product> _products = [];
  List<Product> _allProducts = []; // Master list

  List<Product> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allProducts = await _supabaseService.getProducts();
      _products = List.from(_allProducts);
    } catch (e) {
      print('Error fetching products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchProducts(String query) {
    if (query.isEmpty) {
      _products = List.from(_allProducts);
    } else {
      _products = _allProducts
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  Future<void> addProduct(String name, double price, int stock) async {
    try {
      final newProduct = await _supabaseService.addProduct(name, price, stock);
      if (newProduct != null) {
        _allProducts.add(newProduct);
        _products = List.from(_allProducts);
        notifyListeners();
      }
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _supabaseService.updateProduct(product);
      final index = _allProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _allProducts[index] = product;

        // Update filtered list too if it's there
        final filteredIndex = _products.indexWhere((p) => p.id == product.id);
        if (filteredIndex != -1) {
          _products[filteredIndex] = product;
        } else {
          // Re-apply filter logic just in case search is active
          _products = List.from(_allProducts); // Simple Reset
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _supabaseService.deleteProduct(id);
      _allProducts.removeWhere((p) => p.id == id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }
}

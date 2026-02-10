import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

class ProductProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Product> _products = [];
  List<Product> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _supabaseService.getProducts();
    } catch (e) {
      print('Error fetching products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(String name, double price, int stock) async {
    try {
      final newProduct = await _supabaseService.addProduct(name, price, stock);
      if (newProduct != null) {
        _products.add(newProduct);
        notifyListeners();
      }
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }
}

import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/supabase_service.dart';

class CustomerProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Customer> _searchResults = [];
  List<Customer> get searchResults => _searchResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return [];
    }

    _isLoading = true;
    notifyListeners();
    try {
      _searchResults = await _supabaseService.searchCustomers(query);
      return _searchResults;
    } catch (e) {
      print('Error searching customers: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer?> addCustomer(Customer customer) async {
    try {
      final newCustomer = await _supabaseService.addCustomer(customer);
      if (newCustomer != null) {
        // Optionally update local list or search results
        _searchResults.add(newCustomer);
        notifyListeners();
      }
      return newCustomer;
    } catch (e) {
      print('Error adding customer: $e');
      rethrow;
    }
  }
}

import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/supabase_service.dart';

class CustomerProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Customer> _searchResults = [];
  List<Customer> get searchResults => _searchResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchCustomers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _searchResults = await _supabaseService.getCustomers();
    } catch (e) {
      print('Error fetching customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) {
      // Revert to full list
      await fetchCustomers();
      return _searchResults;
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

  Future<void> updateCustomer(Customer customer) async {
    try {
      await _supabaseService.updateCustomer(customer);
      // We don't maintain a full list here, but we can update search results if present
      final index = _searchResults.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        // Create new object but keep previous due as we didn't update it
        final old = _searchResults[index];
        _searchResults[index] = Customer(
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          address: customer.address,
          previousDue: old.previousDue,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error updating customer: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _supabaseService.deleteCustomer(id);
      _searchResults.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting customer: $e');
      rethrow;
    }
  }
}

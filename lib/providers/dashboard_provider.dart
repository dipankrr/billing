import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DashboardProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  Map<String, int> _stats = {
    'products': 0,
    'customers': 0,
    'bills': 0,
    'lowStock': 0,
  };
  Map<String, int> get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchStats() async {
    _isLoading = true;
    notifyListeners();
    try {
      _stats = await _supabaseService.getDashboardStats();
    } catch (e) {
      print('Error fetching dashboard stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

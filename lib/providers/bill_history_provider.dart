import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../services/supabase_service.dart';

class BillHistoryProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Bill> _bills = [];
  List<Bill> get bills => _bills;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _currentPage = 0;
  final int _pageSize = 20;
  String _currentSearchQuery = '';

  Future<void> fetchBills({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _bills = [];
    }

    if (!_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final rawData = await _supabaseService.getBills(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
      );

      final List<Bill> newBills = rawData.map((json) {
        final customer = json['customers'];
        return Bill(
          id: json['id'],
          memoNo: json['memo_no'],
          customerId: json['customer_id'],
          customerName: customer != null ? customer['name'] : 'Unknown',
          createdAt: DateTime.parse(json['created_at']),
          totalAmount: (json['total_amount'] as num).toDouble(),
          discount: (json['discount'] as num).toDouble(),
          paidAmount: (json['paid_amount'] as num).toDouble(),
          dueAmount: (json['due_amount'] as num).toDouble(),
          previousDueAtTime:
              (json['previous_due_at_time'] as num? ?? 0).toDouble(),
          items: [], // Items are fetched on demand
        );
      }).toList();

      if (newBills.length < _pageSize) {
        _hasMore = false;
      }

      _bills.addAll(newBills);
      _currentPage++;
    } catch (e) {
      print('Error fetching bill history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchBills(String query) {
    _currentSearchQuery = query;
    // Debounce is usually handled in UI, but safe to call this directly
    fetchBills(refresh: true);
  }

  Future<List<BillItem>> fetchBillItems(String billId) async {
    try {
      return await _supabaseService.getBillItems(billId);
    } catch (e) {
      print('Error fetching bill items: $e');
      return [];
    }
  }

  Future<Customer?> fetchCustomer(String customerId) async {
    return await _supabaseService.getCustomerById(customerId);
  }

  Future<bool> payDue(Bill bill, double amountPaid) async {
    try {
      await _supabaseService.payBillDue(bill.id!, bill.customerId, amountPaid);
      // Refresh the list to reflect updated amounts
      await fetchBills(refresh: true);
      return true;
    } catch (e) {
      print('Error paying due: $e');
      return false;
    }
  }
}

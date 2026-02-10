import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';
import '../services/print_service.dart';

class BillProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final PrintService _printService = PrintService();

  List<BillItem> _cart = [];
  List<BillItem> get cart => _cart;

  Customer? _selectedCustomer;
  Customer? get selectedCustomer => _selectedCustomer;

  double _discount = 0.0;
  double get discount => _discount;

  double _paidAmount = 0.0;
  double get paidAmount => _paidAmount;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  // Calculated properties
  double get totalAmount => _cart.fold(0, (sum, item) => sum + item.total);
  double get dueAmount => (totalAmount - _discount) - _paidAmount;
  double get totalDueIncludingPrevious =>
      dueAmount + (_selectedCustomer?.previousDue ?? 0.0);

  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void updateDiscount(double value) {
    _discount = value;
    notifyListeners();
  }

  void updatePaidAmount(double value) {
    _paidAmount = value;
    notifyListeners();
  }

  void addToCart(Product product, int quantity) {
    // Check if product already exists
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      // Update quantity
      final existing = _cart[index];
      _cart[index] = BillItem(
        product: existing.product,
        quantity: existing.quantity + quantity,
        priceAtTime: existing.priceAtTime,
      );
    } else {
      _cart.add(BillItem(
        product: product,
        quantity: quantity,
        priceAtTime: product.price,
      ));
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  void updateCartItemQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeFromCart(index);
      return;
    }
    final item = _cart[index];
    _cart[index] = BillItem(
      product: item.product,
      quantity: quantity,
      priceAtTime: item.priceAtTime,
    );
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    _selectedCustomer = null;
    _discount = 0.0;
    _paidAmount = 0.0;
    notifyListeners();
  }

  Future<void> createAndPrintBill() async {
    if (_selectedCustomer == null || _cart.isEmpty) return;

    if (_selectedCustomer!.id == null) {
      throw Exception(
          "Selected customer has no ID. Please select a valid customer.");
    }

    _isSaving = true;
    notifyListeners();

    try {
      final bill = Bill(
        customerId: _selectedCustomer!.id!,
        createdAt: DateTime.now(),
        totalAmount: totalAmount,
        discount: discount,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
      );

      // Save to Supabase
      await _supabaseService.createBill(bill, _cart);

      // Print
      await _printService.printBill(bill, _cart, _selectedCustomer!);

      // Clear after success
      clearCart();
    } catch (e) {
      print("Error creating bill: $e");
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

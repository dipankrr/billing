import 'product.dart';

class BillItem {
  final String? id; // For DB - UUID
  final Product product;
  final int quantity;
  final double priceAtTime;

  double get total => priceAtTime * quantity;

  BillItem({
    this.id,
    required this.product,
    required this.quantity,
    required this.priceAtTime,
  });

  Map<String, dynamic> toItemJson(String billId) {
    return {
      'bill_id': billId,
      'product_id': product.id,
      'quantity': quantity,
      'price_at_time': priceAtTime,
    };
  }
}

class Bill {
  final String? id;
  final String? memoNo;
  final String customerId; // UUID
  final String? customerName; // For display
  final DateTime createdAt;
  final double totalAmount;
  final double discount;
  final double paidAmount;
  final double dueAmount;
  final List<BillItem> items;

  Bill({
    this.id,
    this.memoNo,
    required this.customerId,
    this.customerName,
    required this.createdAt,
    required this.totalAmount,
    required this.discount,
    required this.paidAmount,
    required this.dueAmount,
    this.items = const [],
  });
}

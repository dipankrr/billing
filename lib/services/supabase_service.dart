import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/customer.dart';
import '../models/bill.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // --- Products ---
  Future<List<Product>> getProducts() async {
    final response =
        await _client.from('products').select().order('name', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<Product?> addProduct(String name, double price, int stock) async {
    final response = await _client
        .from('products')
        .insert({
          'name': name,
          'price': price,
          'stock': stock,
        })
        .select()
        .single();

    return Product.fromJson(response);
  }

  Future<void> updateProduct(Product product) async {
    await _client.from('products').update({
      'name': product.name,
      'price': product.price,
      'stock': product.stock,
    }).eq('id', product.id!);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  // --- Customers ---
  Future<List<Customer>> searchCustomers(String query) async {
    final response = await _client
        .from('customers')
        .select()
        .ilike('name', '%$query%')
        .limit(10);

    final data = response as List<dynamic>;
    return data.map((json) => Customer.fromJson(json)).toList();
  }

  Future<List<Customer>> getCustomers() async {
    final response =
        await _client.from('customers').select().order('name', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => Customer.fromJson(json)).toList();
  }

  Future<Customer?> addCustomer(Customer customer) async {
    final response = await _client
        .from('customers')
        .insert({
          'name': customer.name,
          'phone': customer.phone,
          'address': customer.address,
          'previous_due': customer.previousDue,
        })
        .select()
        .single();

    return Customer.fromJson(response);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _client.from('customers').update({
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
      // Intentionally NOT updating previous_due here to avoid overwriting logic
    }).eq('id', customer.id!);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }

  Future<void> updateCustomerDue(String id, double newDue) async {
    await _client
        .from('customers')
        .update({'previous_due': newDue}).eq('id', id);
  }

  Future<Customer?> getCustomerById(String id) async {
    final response =
        await _client.from('customers').select().eq('id', id).single();
    return Customer.fromJson(response);
  }

  Future<void> payBillDue(
      String billId, String customerId, double amountPaid) async {
    // 1. Fetch current bill amounts
    final billRes = await _client
        .from('bills')
        .select('paid_amount, due_amount')
        .eq('id', billId)
        .single();

    final currentPaid = (billRes['paid_amount'] as num).toDouble();
    final currentDue = (billRes['due_amount'] as num).toDouble();

    // Clamp to not overpay
    final actualPayment = amountPaid.clamp(0, currentDue);
    final newPaid = currentPaid + actualPayment;
    final newDue = currentDue - actualPayment;

    // 2. Update bill
    await _client.from('bills').update({
      'paid_amount': newPaid,
      'due_amount': newDue,
    }).eq('id', billId);

    // 3. Update customer's total due
    final customerRes = await _client
        .from('customers')
        .select('previous_due')
        .eq('id', customerId)
        .single();
    final customerDue = (customerRes['previous_due'] as num).toDouble();
    final newCustomerDue =
        (customerDue - actualPayment).clamp(0.0, double.infinity);
    await updateCustomerDue(customerId, newCustomerDue);
  }

  // --- Bills ---
  Future<Bill> createBill(Bill bill, List<BillItem> items) async {
    // 0. Fetch customer's current due BEFORE this bill (to snapshot it)
    final customerSnapshot = await _client
        .from('customers')
        .select('previous_due')
        .eq('id', bill.customerId)
        .single();
    final previousDueAtTime =
        (customerSnapshot['previous_due'] as num).toDouble();

    // 1. Create Bill (including the snapshotted previous_due_at_time)
    final billResponse = await _client
        .from('bills')
        .insert({
          'customer_id': bill.customerId,
          'total_amount': bill.totalAmount,
          'discount': bill.discount,
          'paid_amount': bill.paidAmount,
          'due_amount': bill.dueAmount,
          'previous_due_at_time': previousDueAtTime,
        })
        .select()
        .single();

    final billId = billResponse['id'] as String;

    // 2. Create Bill Items
    final itemsData = items
        .map((item) => {
              'bill_id': billId,
              'product_id': item.product.id,
              'quantity': item.quantity,
              'price_at_time': item.priceAtTime,
            })
        .toList();

    await _client.from('bill_items').insert(itemsData);

    // 3. Update Customer Due Amount
    if (bill.dueAmount != 0) {
      await updateCustomerDue(
          bill.customerId, previousDueAtTime + bill.dueAmount);
    }

    return Bill(
      id: billResponse['id'],
      memoNo: billResponse['memo_no'],
      customerId: billResponse['customer_id'],
      createdAt: DateTime.parse(billResponse['created_at']),
      totalAmount: (billResponse['total_amount'] as num).toDouble(),
      discount: (billResponse['discount'] as num).toDouble(),
      paidAmount: (billResponse['paid_amount'] as num).toDouble(),
      dueAmount: (billResponse['due_amount'] as num).toDouble(),
      previousDueAtTime: previousDueAtTime,
    );
  }

  // --- Bill History ---
  Future<List<Map<String, dynamic>>> getBills({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // No search: simple paginated fetch
    if (searchQuery == null || searchQuery.isEmpty) {
      final response = await _client
          .from('bills')
          .select('*, customers(name)')
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(response);
    }

    // Search: run two queries and merge results
    // 1. Match by memo_no (on bills table directly)
    final memoResults = await _client
        .from('bills')
        .select('*, customers(name)')
        .ilike('memo_no', '%$searchQuery%')
        .order('created_at', ascending: false)
        .range(from, to);

    // 2. Match by customer name (inner join to filter)
    final customerResults = await _client
        .from('bills')
        .select('*, customers!inner(name)')
        .ilike('customers.name', '%$searchQuery%')
        .order('created_at', ascending: false)
        .range(from, to);

    // Merge and deduplicate by bill id
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final row in [...memoResults, ...customerResults]) {
      final id = row['id'] as String;
      if (seen.add(id)) merged.add(Map<String, dynamic>.from(row));
    }
    // Re-sort merged by created_at descending
    merged.sort((a, b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String));

    return merged;
  }

  Future<List<BillItem>> getBillItems(String billId) async {
    final response = await _client
        .from('bill_items')
        .select('*, products(name)')
        .eq('bill_id', billId);

    final data = response as List<dynamic>;
    return data.map((json) {
      // We need to construct BillItem manually because our model expects a Product object
      // but here we just joined the name.
      final productData = json['products'];
      final product = Product(
        id: json['product_id'],
        name: productData != null ? productData['name'] : 'Unknown',
        price: (json['price_at_time'] as num).toDouble(), // fallback
        stock: 0, // irrelevant for history
      );

      return BillItem(
        id: json['id'],
        product: product,
        quantity: json['quantity'],
        priceAtTime: (json['price_at_time'] as num).toDouble(),
      );
    }).toList();
  }

  Future<Map<String, int>> getDashboardStats() async {
    final productRes =
        await _client.from('products').select('*').count(CountOption.exact);
    final productCount = productRes.count;

    final customerRes =
        await _client.from('customers').select('*').count(CountOption.exact);
    final customerCount = customerRes.count;

    final billRes =
        await _client.from('bills').select('*').count(CountOption.exact);
    final billCount = billRes.count;

    // Low stock: products with stock < 10
    final lowStockRes = await _client
        .from('products')
        .select('*')
        .lt('stock', 10)
        .count(CountOption.exact);
    final lowStockCount = lowStockRes.count;

    return {
      'products': productCount,
      'customers': customerCount,
      'bills': billCount,
      'lowStock': lowStockCount,
    };
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
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

  Future<void> updateCustomerDue(String id, double newDue) async {
    await _client
        .from('customers')
        .update({'previous_due': newDue}).eq('id', id);
  }

  // --- Bills ---
  Future<void> createBill(Bill bill, List<BillItem> items) async {
    // 1. Create Bill
    final billResponse = await _client
        .from('bills')
        .insert({
          'customer_id': bill.customerId,
          'total_amount': bill.totalAmount,
          'discount': bill.discount,
          'paid_amount': bill.paidAmount,
          'due_amount': bill.dueAmount,
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
      final customerRes = await _client
          .from('customers')
          .select('previous_due')
          .eq('id', bill.customerId)
          .single();
      final currentDue = (customerRes['previous_due'] as num).toDouble();
      await updateCustomerDue(bill.customerId, currentDue + bill.dueAmount);
    }
  }
}

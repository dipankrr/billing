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

  // --- Bill History ---
  Future<List<Map<String, dynamic>>> getBills({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _client
        .from('bills')
        .select('*, customers(name)')
        .order('created_at', ascending: false)
        .range(from, to);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // NOTE: Filtering by joined table column 'customers.name' requires
      // specific syntax or view. Supabase simple filtering on joined tables
      // can be tricky.
      // A workaround is to search 'customer_id' if we knew it, or use
      // !inner join if we want to filter ONLY bills that match.
      // simpler approach for MVP: Join and Filter might need a different structure
      // or we accept we might need to filter on client side if pagination is small,
      // BUT for "lots of bills" we want server side.
      //
      // Correct Supabase syntax for filtering on joined resource:
      // .ilike('customers.name', '%$searchQuery%') works if referenced correctly.
      // However, simplified 'textSearch' or similar might be better.
      // Let's try the direct nested filter approach:
      // We'll use the `!inner` hint to ensure we only get bills with matching customers
      query = _client
          .from('bills')
          .select('*, customers!inner(name)')
          .ilike('customers.name', '%$searchQuery%')
          .order('created_at', ascending: false)
          .range(from, to);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
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

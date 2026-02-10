import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/bill_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _discountController =
      TextEditingController(text: '0');
  final TextEditingController _paidController =
      TextEditingController(text: '0');

  Product? _selectedProduct;
  TextEditingController? _productSearchController;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ProductProvider>().fetchProducts());
  }

  void _addInfoToCart() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a product first'),
          backgroundColor: AppColors.error));
      return;
    }
    final qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty > 0) {
      context.read<BillProvider>().addToCart(_selectedProduct!, qty);
      setState(() {
        _selectedProduct = null;
        _quantityController.text = '1';
        _productSearchController?.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Added to cart'),
          duration: Duration(milliseconds: 500)));
    }
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Add Customer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(label: 'Name', controller: nameController),
                  CustomTextField(label: 'Phone', controller: phoneController),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final customer = Customer(
                          name: nameController.text,
                          phone: phoneController.text);
                      try {
                        final newCustomer = await context
                            .read<CustomerProvider>()
                            .addCustomer(customer);
                        if (mounted && newCustomer != null) {
                          context
                              .read<BillProvider>()
                              .selectCustomer(newCustomer);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Customer Created & Selected!')));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error));
                        }
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<BillProvider>().clearCart(),
            tooltip: 'Clear Cart',
          )
        ],
      ),
      body: Row(
        children: [
          // Left Panel: Inputs (30% width on Desktop)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Customer Details'),
                  // Customer Search Autocomplete
                  Consumer<BillProvider>(builder: (context, billProvider, _) {
                    // If customer is selected, show details and clear button
                    if (billProvider.selectedCustomer != null) {
                      return Card(
                        color: AppColors.background,
                        child: ListTile(
                          title: Text(billProvider.selectedCustomer!.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(billProvider.selectedCustomer!.phone),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => billProvider.selectCustomer(null),
                          ),
                        ),
                      );
                    }

                    return Autocomplete<Customer>(
                      displayStringForOption: (Customer option) => option.name,
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text == '')
                          return const Iterable<Customer>.empty();

                        // Use the provider to search
                        return await context
                            .read<CustomerProvider>()
                            .searchCustomers(textEditingValue.text);
                      },
                      onSelected: (Customer selection) {
                        context.read<BillProvider>().selectCustomer(selection);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return CustomTextField(
                          label: 'Search Customer',
                          controller: controller,
                          hint: 'Type name...',
                          focusNode: focusNode,
                        );
                      },
                    );
                  }),

                  TextButton.icon(
                    onPressed: () => _showAddCustomerDialog(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('New Customer'),
                  ),

                  const Divider(height: 32),

                  _buildSectionHeader('Add Product'),
                  // Product Search Autocomplete
                  Consumer<ProductProvider>(
                    builder: (context, productProvider, _) {
                      return Autocomplete<Product>(
                        displayStringForOption: (Product option) =>
                            '${option.name} (\u20B9${option.price})',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Product>.empty();
                          }
                          return productProvider.products
                              .where((Product option) {
                            return option.name
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Product selection) {
                          setState(() {
                            _selectedProduct = selection;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          _productSearchController = controller;
                          return CustomTextField(
                            label: 'Search Product',
                            controller: controller,
                            hint: 'Type product name...',
                            focusNode: focusNode,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Quantity',
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          isNumeric: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 28.0),
                        child: PrimaryButton(
                          text: 'Add',
                          icon: Icons.add_shopping_cart,
                          onPressed: _addInfoToCart,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // Right Panel: Invoice Preview (70% width)
          Expanded(
            flex: 7,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(16),
              child: Consumer<BillProvider>(
                builder: (context, billProvider, _) {
                  return Column(
                    children: [
                      // Cart List
                      Expanded(
                        child: Card(
                          child: billProvider.cart.isEmpty
                              ? const Center(
                                  child: Text("Cart is empty",
                                      style: TextStyle(
                                          color: AppColors.textSecondary)))
                              : ListView.separated(
                                  itemCount: billProvider.cart.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final item = billProvider.cart[index];
                                    return ListTile(
                                      title: Text(item.product.name),
                                      subtitle: Text(
                                          '${item.quantity} x ${item.priceAtTime}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '₹${item.total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: AppColors.error),
                                            onPressed: () => billProvider
                                                .removeFromCart(index),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Totals & Actions
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildSummaryRow(
                                  'Subtotal', billProvider.totalAmount),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      label: 'Discount',
                                      controller: _discountController,
                                      isNumeric: true,
                                      onChanged: (val) =>
                                          billProvider.updateDiscount(
                                              double.tryParse(val) ?? 0),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      label: 'Paid Amount',
                                      controller: _paidController,
                                      isNumeric: true,
                                      onChanged: (val) =>
                                          billProvider.updatePaidAmount(
                                              double.tryParse(val) ?? 0),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildSummaryRow(
                                  'Due Amount', billProvider.dueAmount,
                                  isTotal: true),
                              if (billProvider.selectedCustomer != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Previous Due: ₹${billProvider.selectedCustomer!.previousDue} | Total Due: ₹${billProvider.totalDueIncludingPrevious}',
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  text: 'Save & Print Bill',
                                  icon: Icons.print,
                                  isLoading: billProvider.isSaving,
                                  onPressed: () async {
                                    try {
                                      await billProvider.createAndPrintBill();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content:
                                                    Text('Bill Created!')));
                                        // Clean up controllers
                                        _quantityController.text = '1';
                                        _discountController.text = '0';
                                        _paidController.text = '0';
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor:
                                                    AppColors.error));
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

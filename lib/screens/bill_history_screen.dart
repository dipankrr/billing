import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../providers/bill_history_provider.dart';
import '../services/print_service.dart';
import '../models/bill.dart';
import '../widgets/custom_text_field.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController =
      TextEditingController(); // Define search controller

  @override
  void initState() {
    super.initState();
    // Initial fetch
    Future.microtask(
        () => context.read<BillHistoryProvider>().fetchBills(refresh: true));

    // Pagination listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<BillHistoryProvider>().fetchBills();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose(); // Dispose search controller
    super.dispose();
  }

  void _showBillDetails(BuildContext context, Bill bill) async {
    // Show loading while fetching items? Or fetch inside the dialog?
    // Let's fetch inside dialog or show a loading indicator there.
    showDialog(
      context: context,
      builder: (context) => _BillDetailsDialog(bill: bill),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomTextField(
              label: 'Search Customer',
              hint: 'Enter customer name...',
              controller: _searchController, // Use the controller
              onChanged: (val) {
                // Debounce could be added here
                context.read<BillHistoryProvider>().searchBills(val);
              },
            ),
          ),
          // List
          Expanded(
            child: Consumer<BillHistoryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.bills.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.bills.isEmpty) {
                  return const Center(child: Text('No bills found.'));
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.bills.length + (provider.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == provider.bills.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final bill = provider.bills[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text(
                          bill.customerName ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy, hh:mm a')
                              .format(bill.createdAt),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${bill.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              bill.dueAmount > 0 ? 'Due' : 'Paid',
                              style: TextStyle(
                                color: bill.dueAmount > 0
                                    ? AppColors.error
                                    : Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showBillDetails(context, bill),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BillDetailsDialog extends StatefulWidget {
  final Bill bill;
  const _BillDetailsDialog({required this.bill});

  @override
  State<_BillDetailsDialog> createState() => _BillDetailsDialogState();
}

class _BillDetailsDialogState extends State<_BillDetailsDialog> {
  List<BillItem>? _items;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final items = await context
        .read<BillHistoryProvider>()
        .fetchBillItems(widget.bill.id!);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bill Details'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow('Customer:', widget.bill.customerName ?? 'Unknown'),
            _buildRow('Date:',
                DateFormat('dd MMM yyyy').format(widget.bill.createdAt)),
            const Divider(),
            if (_isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()))
            else if (_items == null || _items!.isEmpty)
              const Text('No items found.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items!.length,
                  itemBuilder: (context, index) {
                    final item = _items![index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity} x ${item.product.name}'),
                          Text('₹${item.total.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const Divider(),
            _buildRow(
                'Total:', '₹${widget.bill.totalAmount.toStringAsFixed(2)}',
                isBold: true),
            _buildRow('Paid:', '₹${widget.bill.paidAmount.toStringAsFixed(2)}'),
            _buildRow('Due:', '₹${widget.bill.dueAmount.toStringAsFixed(2)}',
                color: AppColors.error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: _items == null || _isLoading
              ? null
              : () async {
                  // Fetch customer details first
                  final customer = await context
                      .read<BillHistoryProvider>()
                      .fetchCustomer(widget.bill.customerId);

                  if (customer == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Error: Customer not found')));
                    }
                    return;
                  }

                  // Reconstruct full bill with items
                  final fullBill = Bill(
                    id: widget.bill.id,
                    customerId: widget.bill.customerId,
                    customerName: widget.bill.customerName,
                    createdAt: widget.bill.createdAt,
                    totalAmount: widget.bill.totalAmount,
                    discount: widget.bill.discount,
                    paidAmount: widget.bill.paidAmount,
                    dueAmount: widget.bill.dueAmount,
                    items: _items!,
                  );

                  await PrintService().printBill(fullBill, _items!, customer);
                },
          icon: const Icon(Icons.print),
          label: const Text('Print'),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

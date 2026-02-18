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

  void _showBillDetails(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (context) => _BillDetailsDialog(bill: bill),
    );
  }

  void _showPayDueDialog(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (context) => _PayDueDialog(bill: bill),
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
              label: 'Search Bill',
              hint: 'Enter customer name/Memo No...',
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
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: const Icon(Icons.receipt,
                                  color: Colors.white),
                            ),
                            title: Text(
                              bill.customerName ?? 'Unknown',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Colors.blue.shade100,
                                  ),
                                  child: Text(
                                    bill.memoNo.toString(),
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a')
                                      .format(bill.createdAt.toLocal()),
                                ),
                              ],
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
                                  bill.dueAmount > 0
                                      ? 'Due: ₹${bill.dueAmount.toStringAsFixed(2)}'
                                      : 'Paid',
                                  style: TextStyle(
                                    color: bill.dueAmount > 0
                                        ? AppColors.error
                                        : Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showBillDetails(context, bill),
                          ),
                          if (bill.dueAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 10),
                              child: SizedBox(
                                width: 200,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showPayDueDialog(context, bill),
                                  icon: const Icon(Icons.payments_outlined,
                                      size: 18),
                                  label: const Text('Pay Due'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                        color: AppColors.error),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                    previousDueAtTime:
                        widget.bill.previousDueAtTime, // ← historical snapshot
                    items: _items!,
                    memoNo: widget.bill.memoNo,
                  );

                  await PrintService().printBill(fullBill, _items!, customer);
                },
          icon: const Icon(Icons.print, color: Colors.white),
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

// ─── Pay Due Dialog ───────────────────────────────────────────────────────────

class _PayDueDialog extends StatefulWidget {
  final Bill bill;
  const _PayDueDialog({required this.bill});

  @override
  State<_PayDueDialog> createState() => _PayDueDialogState();
}

class _PayDueDialogState extends State<_PayDueDialog> {
  final _amountController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (amount > widget.bill.dueAmount) {
      setState(() => _error =
          'Amount cannot exceed due (₹${widget.bill.dueAmount.toStringAsFixed(2)}).');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final success =
        await context.read<BillHistoryProvider>().payDue(widget.bill, amount);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '₹${amount.toStringAsFixed(2)} payment recorded.'
              : 'Failed to record payment. Try again.'),
          backgroundColor: success ? Colors.green : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pay Due'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer: ${widget.bill.customerName ?? "Unknown"}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Outstanding Due: ₹${widget.bill.dueAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount to Pay (₹)',
              border: const OutlineInputBorder(),
              errorText: _error,
              prefixText: '₹ ',
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _confirm,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirm Payment'),
        ),
      ],
    );
  }
}

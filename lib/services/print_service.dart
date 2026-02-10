import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/product.dart';

class PrintService {
  Future<void> printBill(
      Bill bill, List<BillItem> items, Customer customer) async {
    final doc = pw.Document();

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          final grandTotal = bill.totalAmount - bill.discount;
          final previousDue = customer.previousDue;
          final totalPayable = grandTotal + previousDue;
          final paid = bill.paidAmount;
          final currentDue = totalPayable - paid;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                  child: pw.Text('MY SHOP',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 20))),
              pw.Divider(),
              pw.Text('Date: ${dateFormat.format(bill.createdAt)}'),
              pw.Text('Bill ID: ${bill.id ?? "N/A"}'),
              pw.Divider(),
              pw.Text('Customer: ${customer.name}'),
              pw.Text('Phone: ${customer.phone}'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Price',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              ...items.map((item) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(item.product.name)),
                    pw.Text('${item.quantity}'),
                    pw.Text('${item.priceAtTime}'),
                    pw.Text(
                        '${(item.priceAtTime * item.quantity).toStringAsFixed(2)}'),
                  ],
                );
              }).toList(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total:'),
                  pw.Text('${bill.totalAmount.toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount:'),
                  pw.Text('${bill.discount.toStringAsFixed(2)}'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Grand Total:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Previous Due:'),
                  pw.Text('${previousDue.toStringAsFixed(2)}'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Payable Amount:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${totalPayable.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid:'),
                  pw.Text('${paid.toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Current Due:'),
                  pw.Text('${currentDue.toStringAsFixed(2)}'),
                ],
              ),
              pw.Divider(),
              pw.Center(
                  child: pw.Text('Thank You!',
                      style: pw.TextStyle(fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Bill-${bill.id ?? "New"}',
    );
  }
}

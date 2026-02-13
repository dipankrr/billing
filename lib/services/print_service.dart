import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../constants/app_constants.dart';

class PrintService {
  Future<void> printBill(
      Bill bill, List<BillItem> items, Customer customer) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy HH:mm');

    // Load Logo
    final logoUrl =
        '${AppConstants.supabaseUrl}/storage/v1/object/public/images/logo.png';
    final logoImage = await networkImage(logoUrl);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final grandTotal = bill.totalAmount - bill.discount;
          final previousDue = customer.previousDue;
          final totalPayable = grandTotal + previousDue;
          final paid = bill.paidAmount;
          final currentDue = totalPayable - paid;

          return pw.Stack(
            children: [
              // Watermark
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.1,
                  child: pw.Image(logoImage, width: 400),
                ),
              ),

              // Main Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  /// HEADER with Logo
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Image(logoImage, width: 60, height: 60),
                      pw.SizedBox(width: 20),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "MAHASHAKTI CHANACHUR",
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "Gangarampur, Dakshin Dinajpur, 733121",
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 20),
                  pw.Divider(),

                  /// BILL INFO
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("CASH MEMO NO: ${bill.id ?? ''}",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: ${dateFormat.format(bill.createdAt)}"),
                    ],
                  ),

                  pw.SizedBox(height: 15),

                  /// CUSTOMER INFO
                  pw.Text("Customer Name: ${customer.name}",
                      style: pw.TextStyle(fontSize: 12)),
                  pw.Text("Mobile Number: ${customer.phone}",
                      style: pw.TextStyle(fontSize: 12)),

                  pw.SizedBox(height: 25),

                  /// TABLE
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(4),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(2),
                      4: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      /// TABLE HEADER
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          _tableCell("SL", isHeader: true),
                          _tableCell("PRODUCT", isHeader: true),
                          _tableCell("QTY", isHeader: true),
                          _tableCell("PRICE", isHeader: true),
                          _tableCell("TOTAL", isHeader: true),
                        ],
                      ),

                      /// ITEMS
                      ...items.asMap().entries.map((entry) {
                        int index = entry.key + 1;
                        BillItem item = entry.value;

                        return pw.TableRow(
                          children: [
                            _tableCell(index.toString()),
                            _tableCell(item.product.name),
                            _tableCell(item.quantity.toString()),
                            _tableCell(item.priceAtTime.toStringAsFixed(2)),
                            _tableCell((item.priceAtTime * item.quantity)
                                .toStringAsFixed(2)),
                          ],
                        );
                      }).toList(),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  /// TOTALS SECTION (RIGHT ALIGNED)
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      width: 250,
                      child: pw.Column(
                        children: [
                          _amountRow("Total", bill.totalAmount),
                          _amountRow("Discount", bill.discount),
                          _amountRow("Previous Due", previousDue),
                          pw.Divider(),
                          _amountRow("Total Payable", totalPayable,
                              isBold: true),
                          _amountRow("Paid", paid),
                          _amountRow("Current Due", currentDue, isBold: true),
                        ],
                      ),
                    ),
                  ),

                  pw.Spacer(),

                  pw.Center(
                    child: pw.Text(
                      "Thank You For Your Business!",
                      style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                    ),
                  ),
                ],
              ),
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

  /// Table Cell
  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 11,
        ),
      ),
    );
  }

  /// Amount Row
  pw.Widget _amountRow(String title, double value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title,
            style: isBold
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : const pw.TextStyle()),
        pw.Text(value.toStringAsFixed(2),
            style: isBold
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : const pw.TextStyle()),
      ],
    );
  }
}

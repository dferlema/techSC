import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:techsc/features/admin/widgets/reports/export_button.dart';
import 'package:techsc/features/admin/widgets/reports/report_status_badge.dart';

class SalesReportWidget extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(List<QueryDocumentSnapshot>) onExportPDF;
  final Function(List<QueryDocumentSnapshot>) onExportCSV;
  final Function(List<QueryDocumentSnapshot>) onExportExcel;

  const SalesReportWidget({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onExportPDF,
    required this.onExportCSV,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(
      endDate.add(const Duration(days: 1)),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No se encontraron ventas para este rango'),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        double totalSales = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalSales += (data['total'] ?? 0.0).toDouble();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${docs.length} ventas encontradas',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: \$${totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ExportButton(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF',
                          color: Colors.red[700]!,
                          onPressed: () => onExportPDF(docs),
                        ),
                        const SizedBox(width: 10),
                        ExportButton(
                          icon: Icons.table_chart,
                          label: 'CSV',
                          color: Colors.green[700]!,
                          onPressed: () => onExportCSV(docs),
                        ),
                        const SizedBox(width: 10),
                        ExportButton(
                          icon: Icons.grid_on,
                          label: 'Excel',
                          color: Colors.blue[700]!,
                          onPressed: () => onExportExcel(docs),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final originalQuote =
                      data['originalQuote'] as Map<String, dynamic>?;
                  final total = (data['total'] ?? 0.0).toDouble();
                  final clientName =
                      originalQuote?['clientName'] ??
                      data['userName'] ??
                      'Desconocido';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PEDIDO #${docs[index].id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo,
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                  (data['createdAt'] as Timestamp).toDate(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cliente: $clientName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pago: ${(data['paymentMethod'] ?? 'N/A').toString().toUpperCase()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ReportStatusBadge(status: data['status']),
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

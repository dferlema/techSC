import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/features/admin/widgets/reports/export_button.dart';
import 'package:tscomputer/features/admin/widgets/reports/report_status_badge.dart';

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
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
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
        double cashTotal = 0;
        double cardTotal = 0;
        int completedCount = 0;
        int pendingCount = 0;
        int cancelledCount = 0;
        int partialCount = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final total = (data['total'] ?? 0.0).toDouble();
          final status = (data['status'] ?? '').toString().toLowerCase();
          final pm = (data['paymentMethod'] ?? '').toString().toLowerCase();
          final ps = (data['paymentStatus'] ?? '').toString().toLowerCase();

          totalSales += total;
          if (pm == 'tarjeta') {
            cardTotal += total;
          } else {
            cashTotal += total;
          }

          if (status == 'completado' || status == 'entregado' || status == 'completed' || status == 'delivered') {
            completedCount++;
          } else if (status == 'cancelado' || status == 'cancelled') {
            cancelledCount++;
          } else {
            pendingCount++;
          }

          if (ps == 'partial') {
            partialCount++;
          }
        }

        final pendingAmount = docs.fold<double>(0.0, (acc, doc) {
          final d = doc.data() as Map<String, dynamic>;
          final t = (d['total'] ?? 0.0).toDouble();
          final p = (d['paymentStatus'] ?? '').toString().toLowerCase();
          if (p == 'unpaid') return acc + t;
          if (p == 'partial') {
            final paid = (d['paidAmount'] as num?)?.toDouble() ?? 0.0;
            return acc + (t - paid);
          }
          return acc;
        });

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
                  _buildKPIRow(docs.length, totalSales, completedCount, pendingCount, cancelledCount, partialCount, pendingAmount, cashTotal, cardTotal),
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
                  final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
                  final total = (data['total'] ?? 0.0).toDouble();
                  final ps = (data['paymentStatus'] ?? '').toString().toLowerCase();
                  final paidAmount = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
                  final pending = ps == 'paid' ? 0.0 : (ps == 'partial' ? total - paidAmount : total);
                  final clientName = originalQuote?['clientName'] ?? data['userName'] ?? data['clientName'] ?? 'Desconocido';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${docs[index].id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate()),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _infoRow(Icons.person_outline, 'Cliente: $clientName'),
                          const SizedBox(height: 4),
                          _infoRow(Icons.payment, 'Pago: ${(data['paymentMethod'] ?? 'N/A').toString().toUpperCase()}'),
                          const SizedBox(height: 4),
                          _infoRow(Icons.receipt, 'Estado: ${(data['paymentStatus'] ?? 'unpaid').toString().toUpperCase()}'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ReportStatusBadge(status: data['status']),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total: \$${total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  if (ps == 'partial' || ps == 'unpaid')
                                    Text(
                                      'Pendiente: \$${pending.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 13, color: Colors.orange[700], fontWeight: FontWeight.w600),
                                    ),
                                  if (paidAmount > 0)
                                    Text(
                                      'Pagado: \$${paidAmount.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 13, color: Colors.green[600]),
                                    ),
                                ],
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

  Widget _buildKPIRow(int count, double total, int completed, int pending, int cancelled, int partial, double pendingAmount, double cashTotal, double cardTotal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _kpiChip(Icons.check_circle, 'Completadas', completed.toString(), Colors.green),
              const SizedBox(width: 8),
              _kpiChip(Icons.schedule, 'Pendientes', pending.toString(), Colors.orange),
              const SizedBox(width: 8),
              _kpiChip(Icons.cancel, 'Canceladas', cancelled.toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _kpiChip(Icons.payments, 'Abonos', partial.toString(), Colors.blue),
              const SizedBox(width: 8),
              _kpiChip(Icons.money, 'Efectivo', '\$${cashTotal.toStringAsFixed(0)}', Colors.green.shade700),
              const SizedBox(width: 8),
              _kpiChip(Icons.credit_card, 'Tarjeta', '\$${cardTotal.toStringAsFixed(0)}', Colors.blue.shade700),
            ],
          ),
          if (pendingAmount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Por Cobrar Pendiente: \$${pendingAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/features/admin/widgets/reports/export_button.dart';
import 'package:tscomputer/features/admin/widgets/reports/report_status_badge.dart';

class ServicesReportWidget extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(List<QueryDocumentSnapshot>) onExportPDF;
  final Function(List<QueryDocumentSnapshot>) onExportCSV;
  final Function(List<QueryDocumentSnapshot>) onExportExcel;

  const ServicesReportWidget({
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
          .collection('reservations')
          .where('scheduledDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('scheduledDate', isLessThanOrEqualTo: endTimestamp)
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
                const Text('No se encontraron servicios para este rango'),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        int totalCount = docs.length;
        int completedCount = 0;
        int pendingCount = 0;
        int inProgressCount = 0;
        int cancelledCount = 0;
        double totalCost = 0;
        double totalParts = 0;
        double totalServices = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final cost = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
          final parts = data['partsData'] as List<dynamic>?;
          final services = data['servicesData'] as List<dynamic>?;

          totalCost += cost;

          double partsSum = 0;
          if (parts != null) {
            for (final p in parts) {
              partsSum += (p['price'] as num?)?.toDouble() ?? 0.0;
            }
          }
          totalParts += partsSum;

          double servicesSum = 0;
          if (services != null) {
            for (final s in services) {
              servicesSum += (s['price'] as num?)?.toDouble() ?? 0.0;
            }
          }
          totalServices += servicesSum;

          if (status == 'completado' || status == 'completed') {
            completedCount++;
          } else if (status == 'en_proceso' || status == 'confirmado' || status == 'aprobado' || status == 'pendiente') {
            if (status == 'en_proceso') {
              inProgressCount++;
            } else {
              pendingCount++;
            }
          } else if (status == 'cancelado' || status == 'cancelled' || status == 'rechazado') {
            cancelledCount++;
          }
        }

        final pendingReservations = docs.where((doc) {
          final s = (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
          return !(s == 'completado' || s == 'completed' || s == 'cancelado' || s == 'cancelled');
        }).length;

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
                        '$totalCount servicios encontrados',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: \$${totalCost.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildKPIRow(totalCount, completedCount, pendingCount, inProgressCount, cancelledCount, totalCost, totalParts, totalServices, pendingReservations),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ExportButton(icon: Icons.picture_as_pdf, label: 'PDF', color: Colors.red[700]!, onPressed: () => onExportPDF(docs)),
                        const SizedBox(width: 10),
                        ExportButton(icon: Icons.table_chart, label: 'CSV', color: Colors.green[700]!, onPressed: () => onExportCSV(docs)),
                        const SizedBox(width: 10),
                        ExportButton(icon: Icons.grid_on, label: 'Excel', color: Colors.blue[700]!, onPressed: () => onExportExcel(docs)),
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
                  final cost = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
                  final clientName = data['clientName'] ?? data['userName'] ?? 'Desconocido';
                  final device = data['device'] ?? 'N/A';
                  final serviceType = data['serviceType'] ?? 'N/A';
                  final parts = data['partsData'] as List<dynamic>?;
                  final services = data['servicesData'] as List<dynamic>?;

                  double partsSum = 0;
                  final partsNames = <String>[];
                  if (parts != null) {
                    for (final p in parts) {
                      partsSum += (p['price'] as num?)?.toDouble() ?? 0.0;
                      partsNames.add('${p['name']} (\$${((p['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)})');
                    }
                  }

                  double servicesSum = 0;
                  final servicesNames = <String>[];
                  if (services != null) {
                    for (final s in services) {
                      servicesSum += (s['price'] as num?)?.toDouble() ?? 0.0;
                      servicesNames.add('${s['name']} (\$${((s['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)})');
                    }
                  }

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
                                DateFormat('dd/MM/yyyy').format((data['scheduledDate'] as Timestamp).toDate()),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _infoRow(Icons.person_outline, 'Cliente: $clientName'),
                          const SizedBox(height: 4),
                          _infoRow(Icons.devices, 'Dispositivo: $device'),
                          const SizedBox(height: 4),
                          _infoRow(Icons.build_outlined, 'Servicio: $serviceType'),
                          if (servicesNames.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _infoRow(Icons.handyman, 'Mano de Obra: ${servicesNames.join(', ')}'),
                            _infoRow(Icons.monetization_on, '  Subtotal MO: \$${servicesSum.toStringAsFixed(2)}', iconColor: Colors.blue),
                          ],
                          if (partsNames.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _infoRow(Icons.inventory_2, 'Repuestos: ${partsNames.join(', ')}'),
                            _infoRow(Icons.monetization_on, '  Subtotal Rep: \$${partsSum.toStringAsFixed(2)}', iconColor: Colors.green),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ReportStatusBadge(status: data['status']),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total: \$${cost.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  if (cost > 0 && partsSum > 0 && servicesSum > 0)
                                    Text(
                                      'MO: \$${servicesSum.toStringAsFixed(2)} + Rep: \$${partsSum.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

  Widget _buildKPIRow(int total, int completed, int pending, int inProgress, int cancelled, double totalCost, double totalParts, double totalServices, int pendingReservations) {
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
              _kpiChip(Icons.check_circle, 'Completados', completed.toString(), Colors.green),
              const SizedBox(width: 8),
              _kpiChip(Icons.schedule, 'Pendientes', pending.toString(), Colors.orange),
              const SizedBox(width: 8),
              _kpiChip(Icons.play_arrow, 'En Proceso', inProgress.toString(), Colors.blue),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _kpiChip(Icons.cancel, 'Cancelados', cancelled.toString(), Colors.red),
              const SizedBox(width: 8),
              _kpiChip(Icons.inventory_2, 'En Repuestos', '\$${totalParts.toStringAsFixed(0)}', Colors.green.shade700),
              const SizedBox(width: 8),
              _kpiChip(Icons.handyman, 'Mano Obra', '\$${totalServices.toStringAsFixed(0)}', Colors.blue.shade700),
            ],
          ),
          if (pendingReservations > 0) ...[
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
                    '$pendingReservations reservaciones en estado pendiente — requieren atención',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[800], fontSize: 13),
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

  Widget _infoRow(IconData icon, String text, {Color? iconColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor ?? Colors.grey[600]),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

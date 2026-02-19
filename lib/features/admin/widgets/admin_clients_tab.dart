import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/admin/screens/client_form_page.dart';
import 'package:techsc/features/admin/widgets/role_assignment_dialog.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';

class AdminClientsTab extends ConsumerStatefulWidget {
  const AdminClientsTab({super.key});

  @override
  ConsumerState<AdminClientsTab> createState() => _AdminClientsTabState();
}

class _AdminClientsTabState extends ConsumerState<AdminClientsTab> {
  late TextEditingController _searchController;
  bool _isSearchExpanded = false;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteDocument(
    String collection,
    String docId,
    AppLocalizations l10n,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deleteSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case RoleService.ADMIN:
        return Colors.purple;
      case RoleService.SELLER:
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Future<void> _exportToCSV(AppLocalizations l10n) async {
    try {
      final clients = await ref.read(adminClientsProvider.future);
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('Cédula,Nombre,Correo,Teléfono,Tipo,Fecha Registro');

      for (var client in clients) {
        final createdAt = (client['createdAt'] as Timestamp?)?.toDate();
        buffer.writeln(
          '"${client['id'] ?? ''}",'
          '"${client['name'] ?? ''}",'
          '"${client['email'] ?? ''}",'
          '"${client['phone'] ?? ''}",'
          '"${client['type'] ?? 'particular'}",'
          '"${createdAt?.toIso8601String().split('T')[0] ?? ''}"',
        );
      }

      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/clientes_techservice.csv');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.csvSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
    }
  }

  Future<void> _exportToPDF(AppLocalizations l10n) async {
    try {
      final clients = await ref.read(adminClientsProvider.future);
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            final tableData = <List<String>>[
              ['Cédula', 'Nombre', 'Correo', 'Teléfono', 'Tipo', 'Registrado'],
              for (var client in clients)
                [
                  client['id'] ?? '—',
                  client['name'] ?? '—',
                  client['email'] ?? '—',
                  client['phone'] ?? '—',
                  (client['type'] ?? 'particular').toString(),
                  (client['createdAt'] as Timestamp?)
                          ?.toDate()
                          .toString()
                          .split(' ')[0] ??
                      '—',
                ],
            ];

            return pw.Column(
              children: [
                pw.Center(
                  child: pw.Text(
                    'TechService Pro - Reporte de Clientes',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  data: tableData,
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'clientes_techservice.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pdfError)));
    }
  }

  Widget _buildClientCard(Map<String, dynamic> client, AppLocalizations l10n) {
    final createdAt = (client['createdAt'] as Timestamp?)?.toDate();
    final role = client['role'] ?? RoleService.CLIENT;
    final roleIcon = RoleService.getRoleIcon(role);
    final roleName = RoleService.getRoleName(role);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(roleIcon, style: const TextStyle(fontSize: 16)),
        ),
        title: Text(
          client['name'] ?? '—',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.idLabel}: ${client['id'] ?? '—'}'),
            Text('${l10n.phoneLabel}: ${client['phone'] ?? '—'}'),
            Text('📧 ${client['email'] ?? '—'}'),
            if (createdAt != null)
              Text('📅 ${createdAt.day}/${createdAt.month}/${createdAt.year}'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                roleName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(role),
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.admin_panel_settings,
                size: 18,
                color: Colors.orange,
              ),
              onPressed: () async {
                final res = await showRoleAssignmentDialog(
                  context,
                  userId: client['docId'],
                  currentRole: role,
                  userName: client['name'] ?? '—',
                  userEmail: client['email'] ?? '—',
                );
                if (res == true && mounted) setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientFormPage(
                      clientId: client['docId'],
                      initialData: client,
                    ),
                  ),
                );
                if (res == true && mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteDocument('users', client['docId'], l10n),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clientsAsync = ref.watch(adminClientsProvider);
    final dateRange = ref.watch(adminClientsDateRangeProvider);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  l10n.advancedSearch,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: Icon(
                    _isSearchExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () =>
                      setState(() => _isSearchExpanded = !_isSearchExpanded),
                ),
              ),
              if (_isSearchExpanded)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchHint,
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) =>
                            ref.read(adminClientsQueryProvider.notifier).state =
                                val,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final res = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  initialDateRange: dateRange,
                                );
                                if (res != null)
                                  ref
                                          .read(
                                            adminClientsDateRangeProvider
                                                .notifier,
                                          )
                                          .state =
                                      res;
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                dateRange != null
                                    ? '${l10n.from}: ${dateRange.start.day}/${dateRange.start.month}'
                                    : l10n.startDate,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (dateRange != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  '${l10n.to}: ${dateRange.end.day}/${dateRange.end.month}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                ref
                                        .read(
                                          adminClientsQueryProvider.notifier,
                                        )
                                        .state =
                                    '';
                                ref
                                        .read(
                                          adminClientsDateRangeProvider
                                              .notifier,
                                        )
                                        .state =
                                    null;
                                setState(() => _currentPage = 0);
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(l10n.clearFilters),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _exportToCSV(l10n),
                            icon: const Icon(Icons.file_download, size: 16),
                            label: Text(l10n.exportCSV),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _exportToPDF(l10n),
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: Text(l10n.exportPDF),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClientFormPage()),
            );
            if (res == true && mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.saveSuccess)));
          },
          icon: const Icon(Icons.person_add),
          label: Text(l10n.addClient),
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                Center(child: Text('${l10n.errorPrefix}: $err')),
            data: (filteredLines) {
              if (filteredLines.isEmpty)
                return Center(child: Text(l10n.noMatchesFound));

              final start = _currentPage * _itemsPerPage;
              final end = (start + _itemsPerPage).clamp(
                0,
                filteredLines.length,
              );
              final paginated = filteredLines.sublist(start, end);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      l10n.showingCount(paginated.length, filteredLines.length),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: paginated.length,
                      itemBuilder: (context, index) =>
                          _buildClientCard(paginated[index], l10n),
                    ),
                  ),
                  if (filteredLines.length > _itemsPerPage)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        Text(
                          '${_currentPage + 1} / ${(filteredLines.length / _itemsPerPage).ceil()}',
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              (_currentPage + 1) * _itemsPerPage <
                                  filteredLines.length
                              ? () => setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

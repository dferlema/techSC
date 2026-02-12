import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/admin/screens/client_form_page.dart';
import 'package:techsc/features/admin/widgets/role_assignment_dialog.dart';

class AdminClientsTab extends StatefulWidget {
  const AdminClientsTab({super.key});

  @override
  State<AdminClientsTab> createState() => _AdminClientsTabState();
}

class _AdminClientsTabState extends State<AdminClientsTab> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  DateTime? _startDate;
  DateTime? _endDate;
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

  /// Elimina un documento de Firestore dado su ID y nombre de colección.
  Future<void> _deleteDocument(String collection, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Elemento eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  /// Retorna el color según el rol
  Color _getRoleColor(String role) {
    switch (role) {
      case RoleService.ADMIN:
        return Colors.purple;
      case RoleService.SELLER:
        return Colors.blue;
      case RoleService.CLIENT:
      default:
        return Colors.green;
    }
  }

  /// Exporta la lista completa de usuarios a un archivo CSV.
  Future<void> _exportToCSV() async {
    try {
      final docs = await FirebaseFirestore.instance.collection('users').get();
      final clients = docs.docs.map((doc) => doc.data()).toList();

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
          '"${createdAt != null ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}' : ''}"',
        );
      }

      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/clientes_techservice.csv');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ CSV guardado en documentos')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al exportar: $e')));
    }
  }

  /// Genera y comparte un reporte PDF de los clientes.
  Future<void> _exportToPDF() async {
    try {
      final docs = await FirebaseFirestore.instance.collection('users').get();
      final clients = docs.docs.map((doc) => doc.data()).toList();

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
                  tableWidth: pw.TableWidth.max,
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
      ).showSnackBar(SnackBar(content: Text('❌ Error al generar PDF: $e')));
    }
  }

  // 👤 Widget de cliente para lista
  Widget _buildClientCardForList(Map<String, dynamic> client) {
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
            Text('📌 Cédula: ${client['id'] ?? '—'}'),
            Text('📱 Tel: ${client['phone'] ?? '—'}'),
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
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              color: Colors.orange,
              tooltip: 'Cambiar rol',
              onPressed: () async {
                final result = await showRoleAssignmentDialog(
                  context,
                  userId: client['docId'],
                  currentRole: role,
                  userName: client['name'] ?? '—',
                  userEmail: client['email'] ?? '—',
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              tooltip: 'Editar',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientFormPage(
                      clientId: client['docId'],
                      initialData: client,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Cliente actualizado')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () => _deleteDocument('users', client['docId']),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔍 Búsqueda avanzada
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  '🔍 Búsqueda Avanzada',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                        decoration: const InputDecoration(
                          hintText:
                              'Buscar por cédula, nombre, correo o teléfono...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 16),
                      // 📅 Filtro por fechas
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _startDate ??
                                      DateTime.now().subtract(
                                        const Duration(days: 30),
                                      ),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _startDate = date);
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _startDate != null
                                    ? 'Desde: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                    : 'Fecha inicio',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _endDate = date);
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _endDate != null
                                    ? 'Hasta: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                    : 'Fecha fin',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _startDate = null;
                                  _endDate = null;
                                  _currentPage = 0;
                                });
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Limpiar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _exportToCSV,
                            icon: const Icon(Icons.file_download, size: 16),
                            label: const Text('CSV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _exportToPDF,
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('PDF'),
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

        // ➕ Agregar cliente
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClientFormPage()),
            );
            if (result == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Cliente guardado')),
              );
            }
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Agregar Cliente'),
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        ),
        const SizedBox(height: 24),

        // 📊 Lista o tabla de clientes
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allClients = snapshot.data!.docs
                  .map(
                    (doc) => {
                      'docId': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    },
                  )
                  .toList();

              // 🔍 Filtrar por texto
              List<Map<String, dynamic>> filtered = allClients;
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                filtered = filtered.where((client) {
                  return (client['id'] as String?)?.toLowerCase().contains(
                            query,
                          ) ==
                          true ||
                      (client['name'] as String?)?.toLowerCase().contains(
                            query,
                          ) ==
                          true ||
                      (client['email'] as String?)?.toLowerCase().contains(
                            query,
                          ) ==
                          true ||
                      (client['phone'] as String?)?.toLowerCase().contains(
                            query,
                          ) ==
                          true;
                }).toList();
              }

              // 📅 Filtrar por fechas
              if (_startDate != null || _endDate != null) {
                filtered = filtered.where((client) {
                  final createdAt = (client['createdAt'] as Timestamp?)
                      ?.toDate();
                  if (createdAt == null) return true;
                  if (_startDate != null && createdAt.isBefore(_startDate!)) {
                    return false;
                  }
                  if (_endDate != null &&
                      createdAt.isAfter(
                        _endDate!.add(const Duration(days: 1)),
                      )) {
                    return false;
                  }
                  return true;
                }).toList();
              }

              // Paginación
              final start = _currentPage * _itemsPerPage;
              final end = start + _itemsPerPage;
              final paginated = filtered.sublist(
                start,
                end > filtered.length ? filtered.length : end,
              );

              return Column(
                children: [
                  // Resumen
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Mostrando ${paginated.length} de ${filtered.length} clientes',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Lista
                  Expanded(
                    child: ListView.builder(
                      itemCount: paginated.length,
                      itemBuilder: (context, index) {
                        final client = paginated[index];
                        return _buildClientCardForList(client);
                      },
                    ),
                  ),
                  // Paginación
                  if (filtered.length > _itemsPerPage)
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text(
                            '${_currentPage + 1} / ${(filtered.length / _itemsPerPage).ceil()}',
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed:
                                (_currentPage + 1) * _itemsPerPage <
                                    filtered.length
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      ),
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

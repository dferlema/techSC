import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 Nuevo
import 'package:flutter_svg/flutter_svg.dart'; // 👈 Nuevo
import 'product_form_page.dart';
import 'service_form_page.dart';
import 'client_form_page.dart';
import '../widgets/app_drawer.dart';
import '../services/role_service.dart'; // 👈 Nuevo
import '../widgets/role_assignment_dialog.dart';
import '../services/config_service.dart';

/// Página principal del panel de administración.
///
/// Características:
/// - Validación de privilegios administrativos a través de `_isAdmin’.
/// - Gestión (CRUD) de Clientes, Productos y Servicios.
/// - Búsqueda avanzada y filtrado para clientes.
/// - exportación de PDF y CSV para los clientes.
/// - Interfaz con pestañas para facilitar la navegación.
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _checkRole();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _searchController = TextEditingController();

    // Limpiar búsqueda al cambiar de pestaña
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
          _startDate = null;
          _endDate = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _userRole = RoleService.CLIENT;
  bool _isLoadingRole = true;

  /// Verifica si es admin o vendedor
  bool get _canAccessPanel =>
      _userRole == RoleService.ADMIN || _userRole == RoleService.SELLER;

  /// Verifica si es admin
  bool get _isAdminRole => _userRole == RoleService.ADMIN;

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await RoleService().getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  /// Construye los botones de Editar y Eliminar para las tarjetas de items.
  /// Construye los botones de Editar y Eliminar (Iconos).
  Widget _buildActionButtons({
    required String collection,
    required String docId,
    required VoidCallback onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, color: Colors.blue),
          tooltip: 'Editar',
        ),
        IconButton(
          onPressed: () => _deleteDocument(collection, docId),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Eliminar',
        ),
      ],
    );
  }

  /// Construye una tarjeta visual para un Cliente en la lista.
  Widget _buildClientCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final role = data['role'] ?? RoleService.CLIENT;
    final roleIcon = RoleService.getRoleIcon(role);
    final roleName = RoleService.getRoleName(role);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(roleIcon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(data['name'] ?? '—'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cédula: ${data['id'] ?? '—'}'),
            Text('Tel: ${data['phone'] ?? '—'}'),
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
        trailing: Wrap(
          spacing: 4,
          children: [
            // Botón Cambiar Rol
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              color: Colors.orange,
              tooltip: 'Cambiar rol',
              onPressed: () async {
                final result = await showRoleAssignmentDialog(
                  context,
                  userId: doc.id,
                  currentRole: role,
                  userName: data['name'] ?? '—',
                  userEmail: data['email'] ?? '—',
                );
                if (result == true && mounted) {
                  // Refrescar la lista
                  setState(() {});
                }
              },
            ),
            // Botón Editar
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              tooltip: 'Editar',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ClientFormPage(clientId: doc.id, initialData: data),
                  ),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Cliente actualizado')),
                  );
                }
              },
            ),
            // Botón Eliminar
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () => _deleteDocument('users', doc.id),
            ),
          ],
        ),
      ),
    );
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

  /// Construye una tarjeta visual para un Producto.
  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  data['image'] ??
                      'https://via.placeholder.com/300x200?text=Producto',
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    width: 200,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data['name'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data['description'] != null) ...[
              Text(
                data['description'],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              data['specs'] ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${data['price']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionButtons(
              collection: 'products',
              docId: doc.id,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductFormPage(
                      productId: doc.id,
                      initialData: doc.data() as Map<String, dynamic>,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Producto actualizado')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una tarjeta visual para un Servicio.
  Widget _buildServiceCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              data['description'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Desde \$${data['price'] ?? '0'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildActionButtons(
              collection: 'services',
              docId: doc.id,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ServiceFormPage(serviceId: doc.id, initialData: data),
                  ),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Servicio actualizado')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el contenido de la pestaña Clientes.
  /// Incluye: Barra de búsqueda, filtros de fecha, botón de agregar y lista paginada.
  Widget _buildClientsTab() {
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
                      'docId': doc
                          .id, // 🔑 Usar clave única para el ID del documento
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
                      clientId: client['docId'], // 🔑 Usar ID de documento
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

  /// Exporta la lista completa de usuarios a un archivo CSV.
  /// El archivo se guarda en el directorio de documentos de la aplicación.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al generar PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_canAccessPanel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Solo personal autorizado puede acceder.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: AppDrawer(
        currentRoute: '/admin',
        userName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'Administrador',
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Panel de Administración',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Gestiona clientes, productos, servicios y banners',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabController.index,
        onDestinationSelected: (int index) {
          setState(() {
            _tabController.animateTo(index);
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.image_outlined),
            selectedIcon: Icon(Icons.image),
            label: 'Banners',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            selectedIcon: Icon(Icons.palette),
            label: 'Personalización',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      physics:
          const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflict with bottom nav logic if wanted, or keep it.
      // Actually, if I use TabController, I need to listen to it to update NavBar.
      // Better to just use PageView or IndexedStack.
      // Let's stick to using the existing TabController for minimal refactor of logic, but update UI.
      // To sync TabController and NavBar, I need setState in listener.
      children: [
        // 1. Clientes
        _isAdminRole
            ? _buildClientsTab()
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Solo administradores pueden gestionar clientes'),
                  ],
                ),
              ),
        // 2. Productos
        _buildTabContent(
          collection: 'products',
          builder: _buildProductCard,
          addButtonLabel: 'Agregar Producto',
        ),
        // 3. Servicios
        _buildTabContent(
          collection: 'services',
          builder: _buildServiceCard,
          addButtonLabel: 'Agregar Servicio',
        ),
        // 4. Pedidos
        _buildOrdersTab(),
        // 5. Banners
        _buildBannersTab(),
        // 6. Personalización
        _buildPersonalizationTab(),
      ],
    );
  }

  // 🖼️ Tab de Banners
  Widget _buildBannersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Input para agregar banner
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar Nuevo Banner',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              _searchController, // Reusing controller for URL input temporarily
                          decoration: const InputDecoration(
                            labelText: 'URL de la Imagen',
                            hintText: 'https://ejemplo.com/imagen.jpg',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final url = _searchController.text.trim();
                          if (url.isNotEmpty) {
                            await FirebaseFirestore.instance
                                .collection('banners')
                                .add({
                                  'imageUrl': url,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                            _searchController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Banner agregado'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Agregar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Banners Activos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Lista de banners
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('banners')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay banners activos',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1, // Full width items for better view
                    mainAxisSpacing: 16,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            data['imageUrl'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteDocument('banners', doc.id),
                            ),
                          ),
                        ),
                      ],
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

  // 🧩 Widget reutilizable para Productos y Servicios
  Widget _buildTabContent({
    required String collection,
    required Widget Function(DocumentSnapshot) builder,
    required String addButtonLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              Widget page;
              String successMessage;

              if (collection == 'products') {
                page = const ProductFormPage();
                successMessage = '✅ Producto guardado';
              } else if (collection == 'services') {
                page = const ServiceFormPage();
                successMessage = '✅ Servicio guardado';
              } else {
                return;
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
              if (result == true && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(successMessage)));
              }
            },
            icon: const Icon(Icons.add),
            label: Text(addButtonLabel),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collection)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay elementos'));
                }

                // Filtrado del lado del cliente
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final query = _searchQuery.toLowerCase();

                  if (query.isEmpty) return true;

                  // Búsqueda genérica en valores del mapa
                  return data.values.any(
                    (value) => value.toString().toLowerCase().contains(query),
                  );
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay coincidencias'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) => builder(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 📦 Tab de Pedidos
  Widget _buildOrdersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar pedido por ID...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay pedidos registrados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs.where((doc) {
                final id = doc.id.toLowerCase();
                final query = _searchQuery.toLowerCase();
                return id.contains(query);
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay pedidos con ese criterio'),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(docs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 📦 Tarjeta de Pedido
  // 📦 Tarjeta de Pedido
  Widget _buildOrderCard(DocumentSnapshot doc) {
    return OrderCard(
      doc: doc,
      onDelete: () => _deleteDocument('orders', doc.id),
      statusColorCallback: _getOrderStatusColor,
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 🎨 Tab de Personalización (Branding)
  Widget _buildPersonalizationTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ConfigService().getBrandingConfig(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final config = snapshot.data!;
        return _BrandingForm(initialConfig: config);
      },
    );
  }
}

class OrderCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final VoidCallback onDelete;
  final Color Function(String) statusColorCallback;

  const OrderCard({
    super.key,
    required this.doc,
    required this.onDelete,
    required this.statusColorCallback,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  late TextEditingController _paymentLinkController;
  late TextEditingController _institutionController;
  late TextEditingController _voucherController;
  bool _isSavingLink = false;

  // Payment Control State
  String _paymentMethod = 'efectivo';
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>;
    _paymentLinkController = TextEditingController(
      text: data['paymentLink'] ?? '',
    );
    _institutionController = TextEditingController(
      text: data['financialInstitution'] ?? '',
    );
    _voucherController = TextEditingController(
      text: data['paymentVoucher'] ?? '',
    );
    _paymentMethod = data['paymentMethod'] ?? 'efectivo';
    _isPaid = data['isPaid'] ?? false;
  }

  @override
  void dispose() {
    _paymentLinkController.dispose();
    _institutionController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(String name, String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 9 && cleanPhone.startsWith('9')) {
      cleanPhone = '593$cleanPhone';
    } else if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      cleanPhone = '593${cleanPhone.substring(1)}';
    }

    final message = Uri.encodeComponent(
      'Hola $name, le escribo respecto a su pedido #${widget.doc.id.substring(0, 5).toUpperCase()}...',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error WhatsApp: $e')));
      }
    }
  }

  Future<void> _savePaymentLink() async {
    setState(() => _isSavingLink = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({'paymentLink': _paymentLinkController.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Link de pago guardado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingLink = false);
    }
  }

  Future<void> _savePaymentDetails() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({
            'paymentMethod': _paymentMethod,
            'financialInstitution': _institutionController.text.trim(),
            'paymentVoucher': _voucherController.text.trim(),
            'isPaid': _isPaid,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Detalles de pago actualizados')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar pago: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final total = data['total'] ?? 0.0;
    final status = data['status'] ?? 'pendiente';
    final items = (data['items'] as List<dynamic>? ?? []);
    final userId = data['userId'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: widget.statusColorCallback(status),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text(
          'Pedido #${widget.doc.id.substring(0, 5).toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${date.day}/${date.month}/${date.year} - \$${total.toStringAsFixed(2)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Cliente
                if (userId != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final userName = userData?['name'] ?? 'Desconocido';
                      final userPhone = userData?['phone'] ?? '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (userPhone.isNotEmpty)
                                InkWell(
                                  onTap: () =>
                                      _launchWhatsApp(userName, userPhone),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: SvgPicture.network(
                                      'https://static.whatsapp.net/rsrc.php/yZ/r/JvsnINJ2CZv.svg',
                                      width: 24,
                                      height: 24,
                                      placeholderBuilder: (_) => const Icon(
                                        Icons.phone,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (userPhone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                userPhone,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          const Divider(),
                        ],
                      );
                    },
                  ),

                // Link de Pago
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paymentLinkController,
                        decoration: const InputDecoration(
                          labelText: 'Link de Pago',
                          hintText: 'https://...',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSavingLink
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: _savePaymentLink,
                            icon: const Icon(Icons.save, color: Colors.blue),
                            tooltip: 'Guardar Link',
                          ),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Control Section
                const Text(
                  'Control de Pagos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Pago Realizado:'),
                    Switch(
                      value: _isPaid,
                      onChanged: (val) {
                        setState(() => _isPaid = val);
                        _savePaymentDetails();
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _paymentMethod = val);
                      _savePaymentDetails();
                    }
                  },
                ),
                if (_paymentMethod == 'transferencia') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _institutionController,
                    decoration: const InputDecoration(
                      labelText: 'Institución Financiera',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _voucherController,
                    decoration: const InputDecoration(
                      labelText: 'Número de Comprobante/Voucher',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _savePaymentDetails,
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('Guardar Detalles Transferencia'),
                    ),
                  ),
                ],
                const Divider(),

                // Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estado:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value:
                          [
                            'pendiente',
                            'confirmado',
                            'entregado',
                            'cancelado',
                          ].contains(status)
                          ? status
                          : 'pendiente',
                      items:
                          ['pendiente', 'confirmado', 'entregado', 'cancelado']
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.toUpperCase(),
                                    style: TextStyle(
                                      color: widget.statusColorCallback(s),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          FirebaseFirestore.instance
                              .collection('orders')
                              .doc(widget.doc.id)
                              .update({'status': newStatus});
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                const Text(
                  'Productos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item['quantity']}x ${item['name']}'),
                        ),
                        Text('\$${(item['subtotal'] ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Eliminar Pedido',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandingForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;

  const _BrandingForm({required this.initialConfig});

  @override
  State<_BrandingForm> createState() => _BrandingFormState();
}

class _BrandingFormState extends State<_BrandingForm> {
  late Map<String, dynamic> _config;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _config = Map<String, dynamic>.from(widget.initialConfig);
  }

  void _save() async {
    setState(() => _isSaving = true);
    try {
      await ConfigService().updateBrandingConfig(_config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada correctamente'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Pantalla de Carga (Splash)'),
          _buildTextField(
            label: 'Título',
            value: _config['splash']['title'],
            onChanged: (v) => _config['splash']['title'] = v,
          ),
          _buildTextField(
            label: 'Subtítulo',
            value: _config['splash']['subtitle'],
            onChanged: (v) => _config['splash']['subtitle'] = v,
          ),
          _buildTextField(
            label: 'URL Imagen de Fondo (opcional)',
            value: _config['splash']['imageUrl'],
            onChanged: (v) => _config['splash']['imageUrl'] = v,
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Bienvenida (Onboarding)'),
          for (int i = 0; i < (_config['onboarding'] as List).length; i++) ...[
            Text(
              'Paso ${i + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            _buildTextField(
              label: 'Título',
              value: _config['onboarding'][i]['title'],
              onChanged: (v) => _config['onboarding'][i]['title'] = v,
            ),
            _buildTextField(
              label: 'Descripción',
              value: _config['onboarding'][i]['description'],
              onChanged: (v) => _config['onboarding'][i]['description'] = v,
              maxLines: 2,
            ),
            _buildTextField(
              label: 'URL Imagen Paso ${i + 1}',
              value: _config['onboarding'][i]['imageUrl'],
              onChanged: (v) => _config['onboarding'][i]['imageUrl'] = v,
            ),
            const Divider(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('GUARDAR CAMBIOS'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String? value,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value ?? '',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    );
  }
}

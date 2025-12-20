import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'product_form_page.dart';
import 'service_form_page.dart';
import 'client_form_page.dart';
import '../widgets/app_drawer.dart';
import '../services/role_service.dart'; // 👈 Nuevo
import '../widgets/role_assignment_dialog.dart'; // 👈 Nuevo

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
    _checkRole(); // 👈 Cargar rol al iniciar
    _tabController = TabController(length: 4, vsync: this);
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                'Gestiona clientes, productos y servicios',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Clientes'),
              Tab(text: 'Productos'),
              Tab(text: 'Servicios'),
              Tab(text: 'Pedidos'), // Added Pedidos tab
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // 👤 Clientes (versión mejorada)
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
            // 🛒 Productos
            _buildTabContent(
              collection: 'products',
              builder: _buildProductCard,
              addButtonLabel: 'Agregar Producto',
            ),
            // 🛠️ Servicios
            _buildTabContent(
              collection: 'services',
              builder: _buildServiceCard,
              addButtonLabel: 'Agregar Servicio',
            ),
            // 📦 Pedidos
            _buildOrdersTab(),
          ],
        ),
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
  Widget _buildOrderCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final total = data['total'] ?? 0.0;
    final status = data['status'] ?? 'pendiente';
    final items = (data['items'] as List<dynamic>? ?? []);
    final userId = data['userId'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getOrderStatusColor(status),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text(
          'Pedido #${doc.id.substring(0, 5).toUpperCase()}',
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
                                      color: _getOrderStatusColor(s),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          FirebaseFirestore.instance
                              .collection('orders')
                              .doc(doc.id)
                              .update({'status': newStatus});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente ID: $userId',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    onPressed: () => _deleteDocument('orders', doc.id),
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
}

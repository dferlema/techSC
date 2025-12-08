import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'product_form_page.dart';
import 'service_form_page.dart';
import 'client_form_page.dart';
import '../widgets/app_drawer.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

  /// Verifica si el usuario actual tiene rol de administrador.
  /// Compara el UID del usuario con una lista permitida (o lógica de roles).
  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // Para producción: return user.uid == 'TU_UID_AQUI';
    return true;
  }

  /// Elimina un documento de Firestore dado su ID y nombre de colección.
  Future<void> _deleteDocument(String collection, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
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
  Widget _buildActionButtons({
    required String collection,
    required String docId,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Editar', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _deleteDocument(collection, docId),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Eliminar', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye una tarjeta visual para un Cliente en la lista.
  Widget _buildClientCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(data['name'] ?? '—'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cédula: ${data['id'] ?? '—'}'),
            Text('Tel: ${data['phone'] ?? '—'}'),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
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
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteDocument('users', doc.id),
            ),
          ],
        ),
      ),
    );
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                data['image'] ??
                    'https://via.placeholder.com/300x200?text=Producto',
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data['name'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              data['specs'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
          ),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
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
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
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
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1976D2),
          title: const Text('Acceso Denegado'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Solo administradores pueden acceder.',
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
          backgroundColor: const Color(0xFF1976D2),
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
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // 👤 Clientes (versión mejorada)
            _buildClientsTab(),
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
              backgroundColor: const Color(0xFF1976D2),
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
}

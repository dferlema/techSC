import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/my_orders_page.dart';
import '../services/role_service.dart';
import '../services/preferences_service.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;
  final String? userName; // Permite ser null para cargar internamente

  const AppDrawer({super.key, required this.currentRoute, this.userName});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _displayName = 'Usuario';
  bool _isLoadingName = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName ?? 'Usuario';
    if (_displayName == 'Usuario') {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingName = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['name'] != null) {
        if (mounted) {
          setState(() {
            _displayName = doc.data()!['name'];
            _isLoadingName = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingName = false);
      }
    } catch (e) {
      debugPrint('Error loading user in Drawer: $e');
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  void _navigateTo(BuildContext context, String route) {
    // For these routes, we want to push them onto the stack so we can go back
    if (route == '/profile-edit' || route == '/contact') {
      if (widget.currentRoute == route) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context); // Close drawer
      Navigator.pushNamed(context, route);
      return;
    }

    if (route == '/products' ||
        route == '/services' ||
        route == '/admin' ||
        route == '/technician' ||
        route == '/reports' ||
        route == '/quotes' ||
        route == '/my-reservations' ||
        route == '/marketing' ||
        route == '/settings') {
      if (widget.currentRoute == route) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context); // Close drawer
      Navigator.pushNamed(context, route);
      return;
    }

    if (route == '/home' || route == '/reserve-service') {
      Navigator.pushReplacementNamed(context, '/main', arguments: route);
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 180, // Fijo para evitar desbordamiento
            padding: const EdgeInsets.only(left: 16, bottom: 16, top: 40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FutureBuilder<String?>(
                    future: PreferencesService().getProfileImagePath(
                      user?.uid ?? '',
                    ),
                    builder: (context, snapshot) {
                      final imagePath = snapshot.data;
                      return GestureDetector(
                        onTap: () => _navigateTo(context, '/profile-edit'),
                        child: CircleAvatar(
                          radius: 30, // Reducido un poco para ahorrar espacio
                          backgroundColor: Colors.white,
                          backgroundImage: imagePath != null
                              ? FileImage(File(imagePath))
                              : null,
                          child: imagePath == null
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _isLoadingName
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : Text(
                                _displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 18,
                        ),
                        onPressed: () => _navigateTo(context, '/profile-edit'),
                        tooltip: 'Editar Perfil',
                      ),
                    ],
                  ),
                  const Text(
                    'TechService Pro',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: widget.currentRoute == '/home',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.computer),
            title: const Text('Nuestros Productos'),
            selected: widget.currentRoute == '/products',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/products'),
          ),
          ListTile(
            leading: const Icon(Icons.build_circle),
            title: const Text('Nuestros Servicios'),
            selected: widget.currentRoute == '/services',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/services'),
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Reservar Servicio'),
            selected: widget.currentRoute == '/reserve-service',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/reserve-service'),
          ),
          if (user != null)
            FutureBuilder<String>(
              future: RoleService().getUserRole(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final role = snapshot.data!;

                // Opción para Administradores
                if (role == RoleService.ADMIN) {
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.orange,
                        ),
                        title: const Text('Panel de Administración'),
                        selected: widget.currentRoute == '/admin',
                        selectedTileColor: Colors.orange[50],
                        onTap: () => _navigateTo(context, '/admin'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.build_circle,
                          color: Colors.blueGrey,
                        ),
                        title: const Text('Panel Técnico'),
                        selected: widget.currentRoute == '/technician',
                        selectedTileColor: Colors.blueGrey[50],
                        onTap: () => _navigateTo(context, '/technician'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.assessment,
                          color: Colors.deepPurple,
                        ),
                        title: const Text('Generar Reportes'),
                        selected: widget.currentRoute == '/reports',
                        selectedTileColor: Colors.deepPurple[50],
                        onTap: () => _navigateTo(context, '/reports'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings, color: Colors.grey),
                        title: const Text('Configuraciones'),
                        selected: widget.currentRoute == '/settings',
                        selectedTileColor: Colors.grey[50],
                        onTap: () => _navigateTo(context, '/settings'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.campaign,
                          color: Colors.indigo,
                        ),
                        title: const Text('Marketing'),
                        selected: widget.currentRoute == '/marketing',
                        selectedTileColor: Colors.indigo[50],
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/marketing');
                        },
                      ),
                    ],
                  );
                }

                // Opción para Vendedores
                if (role == RoleService.SELLER) {
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.store, color: Colors.green),
                        title: const Text('Gestión de Ventas'),
                        selected: widget.currentRoute == '/admin',
                        selectedTileColor: Colors.green[50],
                        onTap: () => _navigateTo(context, '/admin'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.assessment,
                          color: Colors.green,
                        ),
                        title: const Text('Reportes de Ventas'),
                        selected: widget.currentRoute == '/reports',
                        selectedTileColor: Colors.green[50],
                        onTap: () => _navigateTo(context, '/reports'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.campaign,
                          color: Colors.indigo,
                        ),
                        title: const Text('Marketing'),
                        selected: widget.currentRoute == '/marketing',
                        selectedTileColor: Colors.indigo[50],
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/marketing');
                        },
                      ),
                    ],
                  );
                }

                // Opción para Técnicos
                if (role == RoleService.TECHNICIAN) {
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.build_circle,
                          color: Colors.blueGrey,
                        ),
                        title: const Text('Panel Técnico'),
                        selected: widget.currentRoute == '/technician',
                        selectedTileColor: Colors.blueGrey[50],
                        onTap: () => _navigateTo(context, '/technician'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.assessment,
                          color: Colors.blueGrey,
                        ),
                        title: const Text('Reportes Técnicos'),
                        selected: widget.currentRoute == '/reports',
                        selectedTileColor: Colors.blueGrey[50],
                        onTap: () => _navigateTo(context, '/reports'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.campaign,
                          color: Colors.indigo,
                        ),
                        title: const Text('Marketing'),
                        selected: widget.currentRoute == '/marketing',
                        selectedTileColor: Colors.indigo[50],
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/marketing');
                        },
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.indigo),
            title: const Text('Mis Reservas'),
            selected: widget.currentRoute == '/my-reservations',
            selectedTileColor: Colors.indigo[50],
            onTap: () => _navigateTo(context, '/my-reservations'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.blue),
            title: const Text('Mis Pedidos'),
            selected: widget.currentRoute == '/my_orders',
            selectedTileColor: Colors.blue[50],
            onTap: () {
              Navigator.pop(context); // Cerrar Drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyOrdersPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.request_quote, color: Colors.amber),
            title: const Text('Cotizaciones'),
            selected: widget.currentRoute == '/quotes',
            selectedTileColor: Colors.amber[50],
            onTap: () => _navigateTo(context, '/quotes'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.teal),
            title: const Text('Contáctanos'),
            selected: widget.currentRoute == '/contact',
            selectedTileColor: Colors.teal.withOpacity(0.1),
            onTap: () => _navigateTo(context, '/contact'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (r) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

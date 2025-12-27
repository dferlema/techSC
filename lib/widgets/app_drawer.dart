import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/my_orders_page.dart';
import '../services/role_service.dart';
import '../services/preferences_service.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final String userName;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    this.userName = 'Usuario',
  });

  void _navigateTo(BuildContext context, String route) {
    if (route == '/products' ||
        route == '/services' ||
        route == '/admin' ||
        route == '/technician' ||
        route == '/contact' ||
        route == '/profile-edit' ||
        route == '/my-reservations') {
      if (currentRoute == route) {
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacementNamed(context, route);
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
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
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
                    return CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      backgroundImage: imagePath != null
                          ? FileImage(File(imagePath))
                          : null,
                      child: imagePath == null
                          ? Icon(
                              Icons.person,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'TechService Pro',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: currentRoute == '/home',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.computer),
            title: const Text('Nuestros Productos'),
            selected: currentRoute == '/products',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/products'),
          ),
          ListTile(
            leading: const Icon(Icons.build_circle),
            title: const Text('Nuestros Servicios'),
            selected: currentRoute == '/services',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/services'),
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Reservar Servicio'),
            selected: currentRoute == '/reserve-service',
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
                        selected: currentRoute == '/admin',
                        selectedTileColor: Colors.orange[50],
                        onTap: () => _navigateTo(context, '/admin'),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.build_circle,
                          color: Colors.blueGrey,
                        ),
                        title: const Text('Panel Técnico'),
                        selected: currentRoute == '/technician',
                        selectedTileColor: Colors.blueGrey[50],
                        onTap: () => _navigateTo(context, '/technician'),
                      ),
                    ],
                  );
                }

                // Opción para Vendedores
                if (role == RoleService.SELLER) {
                  return ListTile(
                    leading: const Icon(Icons.store, color: Colors.green),
                    title: const Text('Gestión de Ventas'),
                    selected: currentRoute == '/admin',
                    selectedTileColor: Colors.green[50],
                    onTap: () => _navigateTo(context, '/admin'),
                  );
                }

                // Opción para Técnicos
                if (role == RoleService.TECHNICIAN) {
                  return ListTile(
                    leading: const Icon(
                      Icons.build_circle,
                      color: Colors.blueGrey,
                    ),
                    title: const Text('Panel Técnico'),
                    selected: currentRoute == '/technician',
                    selectedTileColor: Colors.blueGrey[50],
                    onTap: () => _navigateTo(context, '/technician'),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.indigo),
            title: const Text('Mis Reservas'),
            selected: currentRoute == '/my-reservations',
            selectedTileColor: Colors.indigo[50],
            onTap: () => _navigateTo(context, '/my-reservations'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.blue),
            title: const Text('Mis Pedidos'),
            selected: currentRoute == '/my_orders',
            selectedTileColor: Colors.blue[50],
            onTap: () {
              Navigator.pop(context); // Cerrar Drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyOrdersPage()),
              );
            },
          ),
          // Notification option moved to AppBar
          // ListTile(
          //   leading: const Icon(Icons.notifications, color: Colors.deepPurple),
          //   title: const Text('Notificaciones'),
          //   selected: currentRoute == '/notifications',
          //   selectedTileColor: Colors.deepPurple[50],
          //   onTap: () {
          //     Navigator.pop(context); // Cerrar Drawer
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => const NotificationsPage(),
          //       ),
          //     );
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.teal),
            title: const Text('Contáctanos'),
            selected: currentRoute == '/contact',
            selectedTileColor: Colors.teal.withOpacity(0.1),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.pushNamed(
                context,
                '/contact',
              ); // Push to stack to allow back nav
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.blueGrey),
            title: const Text('Editar Perfil'),
            selected: currentRoute == '/profile-edit',
            selectedTileColor: Colors.blueGrey.withOpacity(0.1),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile-edit');
            },
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

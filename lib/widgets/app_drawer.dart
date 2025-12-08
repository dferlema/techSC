import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final String userName;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    this.userName = 'Usuario',
  });

  void _navigateTo(BuildContext context, String route) {
    if (route != '/main' && route != currentRoute) {
      Navigator.pushReplacementNamed(context, route);
      return;
    }

    if (route == '/home' ||
        route == '/products' ||
        route == '/reserve-service') {
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
            decoration: const BoxDecoration(color: Color(0xFF1976D2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 48, color: Color(0xFF1976D2)),
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
            leading: const Icon(Icons.build),
            title: const Text('Reservar Servicio'),
            selected: currentRoute == '/reserve-service',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/reserve-service'),
          ),
          if (_isAdmin(user))
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

  bool _isAdmin(User? user) {
    if (user == null) return false;
    // 👇 Reemplaza con tu UID real de Firebase Auth
    final adminUids = {'zGgGzJixMIbupS5GgVRNRxDY6292', 'UID_DEL_USUARIO_ADMIN'};
    return adminUids.contains(user.uid);
  }
}

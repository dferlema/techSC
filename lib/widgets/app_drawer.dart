import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  void _navigateTo(BuildContext context, String route) {
    // Si ya está en la ruta, no navegar
    if (route == currentRoute) {
      Navigator.pop(context); // Solo cerrar el drawer
      return;
    }

    // Para pantallas principales, reemplazamos (evita pila infinita)
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 👤 Cabecera (puedes personalizar con foto de perfil más adelante)
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1976D2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'TechService Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Menú de Navegación',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // 🏠 Inicio
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: currentRoute == '/home',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/home'),
          ),

          // 🛒 Productos
          ListTile(
            leading: const Icon(Icons.computer),
            title: const Text('Nuestros Productos'),
            selected: currentRoute == '/products',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/products'),
          ),

          // 🛠️ Reservar Servicio
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Reservar Servicio'),
            selected: currentRoute == '/reserve-service',
            selectedTileColor: Colors.blue[50],
            onTap: () => _navigateTo(context, '/reserve-service'),
          ),

          // ℹ️ Sobre Nosotros (navega a HomePage y scrollea, o crea ruta /about)
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sobre Nosotros'),
            selected:
                currentRoute == '/home' &&
                ModalRoute.of(context)?.settings.arguments == 'about',
            onTap: () {
              // Opción 1: Navegar a HomePage y scrollear (requiere lógica adicional)
              // Opción 2: Crear una ruta dedicada `/about`
              // Por simplicidad, volvemos a HomePage (ya tiene la sección)
              _navigateTo(context, '/home');
              Navigator.pop(context);
            },
          ),

          const Divider(),

          // 🔐 Cerrar Sesión
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              // Aquí iría la lógica de cierre (Firebase Auth.signOut, etc.)
              // Por ahora, volvemos al login
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false, // Borra la pila de navegación
              );
            },
          ),
        ],
      ),
    );
  }
}

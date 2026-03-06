import re

path = r"d:\Diefer\Documents\UBE\aplicacionesMoviles\techservice\TechSC\techSC\lib\core\widgets\app_drawer.dart"

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_navigate = """  void _navigateTo(BuildContext context, String route) {
    if (route == '/profile-edit') {
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
        route == '/my-orders' ||
        route == '/marketing' ||
        route == '/legal' ||
        route == '/app-colors-config' ||
        route == '/settings') {
      if (widget.currentRoute == route) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context); // Close drawer
      Navigator.pushNamed(context, route);
      return;
    }

    if (route == '/home' ||
        route == '/reserve-service' ||
        route == '/contact') {
      Navigator.pushReplacementNamed(context, '/main', arguments: route);
      return;
    }

    Navigator.pop(context);
  }"""

content = re.sub(r"  void _navigateTo\(BuildContext context, String route\) \{.*?\Navigator\.pop\(context\);\n  \}", new_navigate, content, flags=re.DOTALL)

new_menu = """          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: widget.currentRoute == '/home',
            selectedTileColor: AppColors.primaryBlue.withAlpha(26),
            onTap: () => _navigateTo(context, '/home'),
          ),
          ExpansionTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Catálogo y Servicios'),
            initiallyExpanded: ['/products', '/services', '/reserve-service'].contains(widget.currentRoute),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.computer, size: 20),
                title: const Text('Nuestros Productos'),
                selected: widget.currentRoute == '/products',
                selectedTileColor: AppColors.primaryBlue.withAlpha(26),
                onTap: () => _navigateTo(context, '/products'),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.build_circle, size: 20),
                title: const Text('Nuestros Servicios'),
                selected: widget.currentRoute == '/services',
                selectedTileColor: AppColors.primaryBlue.withAlpha(26),
                onTap: () => _navigateTo(context, '/services'),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.build, size: 20),
                title: const Text('Reservar Servicio'),
                selected: widget.currentRoute == '/reserve-service',
                selectedTileColor: AppColors.primaryBlue.withAlpha(26),
                onTap: () => _navigateTo(context, '/reserve-service'),
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mis Actividades'),
            initiallyExpanded: ['/my-reservations', '/my-orders', '/quotes'].contains(widget.currentRoute),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.receipt_long, color: Colors.blue, size: 20),
                title: const Text('Mis Pedidos'),
                selected: widget.currentRoute == '/my-orders',
                selectedTileColor: Colors.blue.withAlpha(26),
                onTap: () => _navigateTo(context, '/my-orders'),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.history, color: Colors.indigo, size: 20),
                title: const Text('Mis Reservas'),
                selected: widget.currentRoute == '/my-reservations',
                selectedTileColor: Colors.indigo.withAlpha(26),
                onTap: () => _navigateTo(context, '/my-reservations'),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.request_quote, color: Colors.amber, size: 20),
                title: const Text('Mis Cotizaciones'),
                selected: widget.currentRoute == '/quotes',
                selectedTileColor: Colors.amber.withAlpha(26),
                onTap: () => _navigateTo(context, '/quotes'),
              ),
            ],
          ),
          if (user != null)
            FutureBuilder<String>(
              future: RoleService().getUserRole(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final role = snapshot.data!;
                final isAdmin = role == RoleService.ADMIN;
                final isSeller = role == RoleService.SELLER;
                final isTech = role == RoleService.TECHNICIAN;

                if (isAdmin || isSeller || isTech) {
                  return ExpansionTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Administración'),
                    initiallyExpanded: ['/admin', '/technician', '/reports', '/marketing', '/app-colors-config'].contains(widget.currentRoute),
                    children: [
                      if (isAdmin || isSeller)
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 40, right: 16),
                          leading: Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.store,
                            color: isAdmin ? AppColors.roleAdmin : AppColors.success,
                            size: 20,
                          ),
                          title: Text(isAdmin ? 'Panel de Administración' : 'Gestión de Ventas'),
                          selected: widget.currentRoute == '/admin',
                          selectedTileColor: (isAdmin ? AppColors.roleAdmin : AppColors.success).withAlpha(26),
                          onTap: () => _navigateTo(context, '/admin'),
                        ),
                      if (isAdmin || isTech)
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 40, right: 16),
                          leading: Icon(
                            Icons.build_circle,
                            color: AppColors.roleTechnician,
                            size: 20,
                          ),
                          title: const Text('Panel Técnico'),
                          selected: widget.currentRoute == '/technician',
                          selectedTileColor: AppColors.roleTechnician.withAlpha(26),
                          onTap: () => _navigateTo(context, '/technician'),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 40, right: 16),
                        leading: Icon(
                          Icons.assessment,
                          color: isAdmin ? Colors.deepPurple : (isSeller ? AppColors.success : AppColors.roleTechnician),
                          size: 20,
                        ),
                        title: const Text('Reportes'),
                        selected: widget.currentRoute == '/reports',
                        selectedTileColor: (isAdmin ? Colors.deepPurple : (isSeller ? AppColors.success : AppColors.roleTechnician)).withAlpha(26),
                        onTap: () => _navigateTo(context, '/reports'),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 40, right: 16),
                        leading: const Icon(
                          Icons.campaign,
                          color: Colors.indigo,
                          size: 20,
                        ),
                        title: const Text('Marketing'),
                        selected: widget.currentRoute == '/marketing',
                        selectedTileColor: Colors.indigo.withAlpha(26),
                        onTap: () => _navigateTo(context, '/marketing'),
                      ),
                      if (isAdmin)
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 40, right: 16),
                          leading: const Icon(
                            Icons.palette,
                            color: Colors.purple,
                            size: 20,
                          ),
                          title: const Text('Configurar Colores'),
                          selected: widget.currentRoute == '/app-colors-config',
                          selectedTileColor: Colors.purple.withAlpha(26),
                          onTap: () => _navigateTo(context, '/app-colors-config'),
                        ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Configuraciones'),
            selected: widget.currentRoute == '/settings',
            selectedTileColor: Colors.grey.withAlpha(26),
            onTap: () => _navigateTo(context, '/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.teal),
            title: const Text('Contáctanos'),
            selected: widget.currentRoute == '/contact',
            selectedTileColor: Colors.teal.withAlpha(26),
            onTap: () => _navigateTo(context, '/contact'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel, color: Colors.blueGrey),
            title: const Text('Términos y Privacidad'),
            selected: widget.currentRoute == '/legal',
            selectedTileColor: Colors.blueGrey.withAlpha(26),
            onTap: () => _navigateTo(context, '/legal'),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.error),
            title: Text(
              'Cerrar Sesión',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (r) => false,
              );
            },
          ),"""

content = re.sub(r"          ListTile\(\n            leading: const Icon\(Icons\.home\).*?(?=\n        \],\n      \),\n    \);\n  \}\n\})", new_menu, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

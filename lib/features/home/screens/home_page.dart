import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:techsc/core/widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/core/widgets/notification_icon.dart';
import 'package:techsc/features/orders/screens/my_orders_page.dart';
import 'package:techsc/features/catalog/screens/product_detail_page.dart';
import 'package:techsc/core/models/config_model.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:techsc/features/orders/screens/quote_list_page.dart';
import 'package:techsc/features/admin/screens/settings_page.dart';
import 'package:techsc/features/admin/screens/admin_panel_page.dart';
import 'package:techsc/features/admin/screens/reports_page.dart';
import 'package:techsc/features/reservations/screens/technician_dashboard.dart';

class HomePage extends StatefulWidget {
  final String routeName;
  const HomePage({super.key, this.routeName = '/home'});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _launchWhatsApp(String phone) async {
    final Uri url = Uri.parse('https://wa.me/$phone');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir WhatsApp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  // Services Data
  final List<Map<String, dynamic>> _services = [
    {
      'title': 'Hardware',
      'icon': Icons.memory_rounded,
      'color': Colors.blue,
      'desc': 'Reparación de componentes',
    },
    {
      'title': 'Software',
      'icon': Icons.terminal_rounded,
      'color': Colors.orange,
      'desc': 'Sistemas Operativos',
    },
    {
      'title': 'Limpieza',
      'icon': Icons.cleaning_services_rounded,
      'color': Colors.green,
      'desc': 'Mantenimiento Preventivo',
    },
    {
      'title': 'Redes',
      'icon': Icons.wifi_rounded,
      'color': Colors.purple,
      'desc': 'Configuración WiFi',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<ConfigModel>(
      stream: ConfigService().getConfigStream(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? ConfigModel();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: colorScheme.primary,
            title: Text(
              config.companyName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: const [
              NotificationIcon(color: Colors.white),
              SizedBox(width: 16),
            ],
          ),
          drawer: const AppDrawer(currentRoute: '/home'),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Carousel Section
                _buildCarouselSection(),

                const SizedBox(height: 24),

                // Staff Dashboard (Only visible to Admin, Seller, Technician)
                _buildStaffDashboard(context),

                const SizedBox(height: 24),

                // 2. ¿En qué te podemos ayudar hoy? (Friendly Greeting)
                _buildSectionTitle('¡Hola! ¿En qué podemos ayudarte hoy?'),
                _buildHelpSection(context),

                const SizedBox(height: 32),

                // 3. Nuestros Servicios (Horizontal List)
                _buildSectionTitle('Nuestros Servicios'),
                _buildServicesList(context),

                const SizedBox(height: 32),

                // 4. Nuestros Productos (Horizontal List)
                _buildSectionTitle(
                  'Productos Destacados',
                  onSeeMore: () => Navigator.pushNamed(context, '/products'),
                ),
                _buildProductsList(context),

                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _launchWhatsApp(config.companyPhone),
            backgroundColor: const Color(0xFF25D366),
            elevation: 4,
            child: Image.asset(
              'assets/images/whatsapp_icon.png',
              width: 35,
              height: 35,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onSeeMore}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          if (onSeeMore != null)
            TextButton(
              onPressed: onSeeMore,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Ver más',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffDashboard(BuildContext context) {
    final user = AuthService().currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<String>(
      future: RoleService().getUserRole(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final role = snapshot.data!;
        if (role == RoleService.CLIENT) return const SizedBox.shrink();

        final cards = _getDashboardCards(role, context);
        if (cards.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Panel de Control (${RoleService.getRoleName(role)})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: cards,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  List<Widget> _getDashboardCards(String role, BuildContext context) {
    List<Widget> cards = [];

    // Cotizaciones: Admin, Seller, Technician
    if (role == RoleService.ADMIN ||
        role == RoleService.SELLER ||
        role == RoleService.TECHNICIAN) {
      cards.add(
        _buildDashboardCard(
          'Cotizaciones',
          Icons.description_outlined,
          Colors.indigo,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuoteListPage()),
          ),
        ),
      );
    }

    // Panel Admin: Admin, Seller
    if (role == RoleService.ADMIN || role == RoleService.SELLER) {
      cards.add(
        _buildDashboardCard(
          'Panel de Gestión',
          Icons.admin_panel_settings_outlined,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelPage()),
          ),
        ),
      );
    }

    // Reportes: Admin, Seller
    if (role == RoleService.ADMIN || role == RoleService.SELLER) {
      cards.add(
        _buildDashboardCard(
          'Reportes',
          Icons.bar_chart_rounded,
          Colors.teal,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsPage()),
          ),
        ),
      );
    }

    // Configuraciones: Admin Only
    if (role == RoleService.ADMIN) {
      cards.add(
        _buildDashboardCard(
          'Configuraciones',
          Icons.settings_outlined,
          Colors.blueGrey,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
      );
    }

    // Panel Técnico: Admin, Technician
    if (role == RoleService.ADMIN || role == RoleService.TECHNICIAN) {
      cards.add(
        _buildDashboardCard(
          'Panel Técnico',
          Icons.build_circle_outlined,
          Colors.blue,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TechnicianDashboard()),
          ),
        ),
      );
    }

    // Marketing: Admin, Seller, Technician
    if (role == RoleService.ADMIN ||
        role == RoleService.SELLER ||
        role == RoleService.TECHNICIAN) {
      cards.add(
        _buildDashboardCard(
          'Marketing',
          Icons.campaign_outlined,
          Colors.indigo,
          () => Navigator.pushNamed(context, '/marketing'),
        ),
      );
    }

    return cards;
  }

  Widget _buildDashboardCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSection() {
    return SizedBox(
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('banners').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image, size: 50, color: Colors.white),
              ),
            );
          }
          return BannerCarousel(banners: snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context) {
    final user = AuthService().currentUser;

    return FutureBuilder<String>(
      future: user != null
          ? RoleService().getUserRole(user.uid)
          : Future.value(RoleService.CLIENT),
      builder: (context, snapshot) {
        final role = snapshot.data ?? RoleService.CLIENT;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildDashboardCard(
                'Agendar Cita',
                Icons.calendar_month_rounded,
                Colors.blue,
                () => Navigator.pushReplacementNamed(
                  context,
                  '/main',
                  arguments: '/reserve-service',
                ),
              ),
              _buildDashboardCard(
                'Mis Reservas',
                Icons.perm_contact_calendar_rounded,
                Colors.orange,
                () => Navigator.pushNamed(context, '/my-reservations'),
              ),
              _buildDashboardCard(
                'Mis Pedidos',
                Icons.shopping_bag_rounded,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                ),
              ),
              // Solo mostrar "Mis Cotizaciones" a Clientes (ya que staff tiene sus propias)
              if (role == RoleService.CLIENT)
                _buildDashboardCard(
                  'Cotizaciones',
                  Icons.description_outlined,
                  Colors.indigo,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuoteListPage()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicesList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: _services
            .map(
              (s) => _buildDashboardCard(
                s['title'],
                s['icon'],
                s['color'],
                () => Navigator.pushNamed(context, '/services'),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildProductsList(BuildContext context) {
    return SizedBox(
      height: 260, // Aumentado
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return _buildEmptyProductsState(context);
          }

          final products = snapshot.data!.docs;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ), // Padding vertical
            itemCount: products.length,
            itemBuilder: (context, index) {
              final doc = products[index];
              final product = doc.data() as Map<String, dynamic>;
              // Pass both data and ID
              return _buildProductCard(context, product, doc.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyProductsState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Catálogo pronto disponible',
              style: TextStyle(color: Colors.grey[600]),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/products'),
              child: const Text('Ir a la Tienda'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Map<String, dynamic> product,
    String id,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product, productId: id),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: product['image'] != null && product['image'].isNotEmpty
                    ? Image.network(
                        product['image'], // Fixed key from imageUrl to image
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Producto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${(product['price'] ?? 0).toString()}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product['taxStatus'] != null &&
                          product['taxStatus'] != 'Ninguno')
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Text(
                            product['taxStatus'] == 'Incluye impuesto'
                                ? '(Incl.)'
                                : '(+ Imp)',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
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
    );
  }
}

class BannerCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> banners;
  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final int middle = 5000;
    final int initialPage = middle - (middle % widget.banners.length);
    _pageController = PageController(initialPage: initialPage);
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: 10000,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index % widget.banners.length;
            });
          },
          itemBuilder: (context, index) {
            final banner = widget.banners[index % widget.banners.length];
            final data = banner.data() as Map<String, dynamic>;
            return Image.network(
              data['imageUrl'] ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
            );
          },
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

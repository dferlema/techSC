// lib/screens/main_tabs_screen.dart

import 'package:flutter/material.dart';
import 'home_page.dart';
import 'products_page.dart';
import 'service_reservation_page.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomePage(), // Índice 0 → Inicio
    const ProductsPage(), // Índice 1 → Productos
    const ServiceReservationPage(), // Índice 2 → Reservar
  ];

  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _screens.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final routeArg = ModalRoute.of(context)?.settings.arguments as String?;
      _currentIndex = _routeToIndex(routeArg ?? '/home');
      _tabController.index = _currentIndex;
      _isInit = false;
    }
  }

  // Convierte ruta a índice
  int _routeToIndex(String route) {
    switch (route) {
      case '/products':
        return 1;
      case '/reserve-service':
        return 2;
      default:
        return 0; // /home
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentIndex = _tabController.index;
    });
  }

  void _onTabTapped(int index) {
    _tabController.animateTo(index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: Colors.grey[600],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.computer_outlined),
            activeIcon: Icon(Icons.computer),
            label: 'Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Reservar',
          ),
        ],
      ),
    );
  }
}

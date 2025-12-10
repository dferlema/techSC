// lib/screens/main_tabs_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
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
  String _userName = 'Usuario';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _screens.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        setState(() => _userName = user.displayName!);
      }

      // Intentar obtener desde Firestore para asegura
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data()?['name'] != null) {
          if (mounted) {
            setState(() => _userName = doc.data()!['name']);
          }
        }
      } catch (e) {
        debugPrint('Error loading user: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      final routeName = ModalRoute.of(context)?.settings.name;
      _currentIndex = _routeToIndex(args ?? routeName ?? '/home');
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

  // Convierte índice a ruta (para el Drawer)
  String _indexToRoute(int index) {
    switch (index) {
      case 1:
        return '/products';
      case 2:
        return '/reserve-service';
      default:
        return '/home';
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
      drawer: AppDrawer(
        currentRoute: _indexToRoute(_currentIndex),
        userName: _userName,
      ),
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

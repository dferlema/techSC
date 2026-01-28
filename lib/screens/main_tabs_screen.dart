// lib/screens/main_tabs_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import '../services/preferences_service.dart';
import 'home_page.dart';
import 'service_reservation_page.dart';
import 'contact_page.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _currentIndex = 0;
  String _userName = 'Usuario';
  bool _isInit = true;

  final List<Widget> _screens = [
    const HomePage(),
    const ServiceReservationPage(),
    const ContactPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _screens.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserName();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSession();
    }
  }

  Future<void> _checkSession() async {
    final expired = await PreferencesService().isSessionExpired();
    if (expired && mounted) {
      await FirebaseAuth.instance.signOut();
      await PreferencesService().clearSession();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Su sesión ha caducado por inactividad (10 min).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        setState(() => _userName = user.displayName!);
      }

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
      } on FirebaseException catch (e) {
        debugPrint('Error loading user (Firebase): [${e.code}] ${e.message}');
        if (e.code == 'permission-denied') {
          _showErrorSnackBar(
            'Error de permisos al cargar perfil. Por favor contacte soporte.',
          );
        }
      } catch (e) {
        debugPrint('Error loading user: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      final routeName = ModalRoute.of(context)?.settings.name;
      _currentIndex = _routeToIndex(args ?? routeName ?? '/home');
      if (_tabController.length > _currentIndex) {
        _tabController.index = _currentIndex;
      }
      _isInit = false;
    }
  }

  int _routeToIndex(String route) {
    switch (route) {
      case '/reserve-service':
        return 1;
      case '/contact':
        return 2;
      default:
        return 0;
    }
  }

  String _indexToRoute(int index) {
    switch (index) {
      case 1:
        return '/reserve-service';
      case 2:
        return '/contact';
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
    WidgetsBinding.instance.removeObserver(this);
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
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
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Reservar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent_outlined),
            activeIcon: Icon(Icons.support_agent),
            label: 'Contacto',
          ),
        ],
      ),
    );
  }
}

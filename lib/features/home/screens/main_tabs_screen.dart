import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/core/platform/platform_image.dart';
import 'package:tscomputer/core/widgets/app_drawer.dart';
import 'package:tscomputer/core/widgets/web_layout.dart';
import 'package:tscomputer/core/widgets/responsive_builder.dart';
import 'package:tscomputer/core/services/preferences_service.dart';
import 'package:tscomputer/features/home/screens/home_page.dart';
import 'package:tscomputer/features/reservations/screens/service_reservation_page.dart';
import 'package:tscomputer/features/home/screens/contact_page.dart';
import 'package:tscomputer/core/widgets/offline_indicator.dart';

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
  String? _profileImagePath;
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

      final path = await PreferencesService().getProfileImagePath(user.uid);
      if (mounted && path != _profileImagePath) {
        setState(() => _profileImagePath = path);
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
    if (index == 3) {
      Navigator.pushNamed(context, '/profile-edit');
      return;
    }
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final mobileLayout = Scaffold(
      drawer: AppDrawer(
        currentRoute: _indexToRoute(_currentIndex),
        userName: _userName,
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: bottomInset > 0 ? bottomInset + 4 : 20,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(
                  4,
                  (i) => _NavItem(
                    index: i,
                    isSelected: _currentIndex == i,
                    imagePath: i == 3 ? _profileImagePath : null,
                    onTap: () => _onTabTapped(i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return ResponsiveBuilder(
      builder: (context, screenSize) {
        if (screenSize == ScreenSize.mobile) {
          return mobileLayout;
        }
        return WebLayout(
          currentIndex: _currentIndex,
          mobileChild: IndexedStack(index: _currentIndex, children: _screens),
        );
      },
    );
  }
}

const _labels = ['Inicio', 'Reservar', 'Contacto', 'Perfil'];
const _icons = [
  Icons.home_outlined,
  Icons.build_outlined,
  Icons.support_agent_outlined,
  Icons.person_outline,
];
const _activeIcons = [
  Icons.home_rounded,
  Icons.build_rounded,
  Icons.support_agent_rounded,
  Icons.person,
];

class _NavItem extends StatelessWidget {
  final int index;
  final bool isSelected;
  final String? imagePath;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.isSelected,
    this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (index == 3)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
                  backgroundImage: imagePath != null
                      ? getLocalImageProvider(imagePath!)
                      : null,
                  child: imagePath == null
                      ? Icon(
                          isSelected ? _activeIcons[index] : _icons[index],
                          size: 18,
                          color: color,
                        )
                      : null,
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? _activeIcons[index] : _icons[index],
                    key: ValueKey('nav_${index}_$isSelected'),
                    color: color,
                    size: 24,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                _labels[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

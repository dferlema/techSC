import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/widgets/responsive_builder.dart';

class WebLayout extends ConsumerStatefulWidget {
  final Widget mobileChild;
  final int currentIndex;

  const WebLayout({
    super.key,
    required this.mobileChild,
    this.currentIndex = 0,
  });

  @override
  ConsumerState<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends ConsumerState<WebLayout> {
  bool _sidebarCollapsed = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] ?? user.email ?? 'Usuario';
        });
      }
    }
  }

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio', route: '/home', index: 0),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Reservaciones', route: '/my-reservations', index: 1),
    _NavItem(icon: Icons.build_rounded, label: 'Servicios', route: '/services', index: 2),
    _NavItem(icon: Icons.contact_phone_rounded, label: 'Contacto', route: '/contact', index: 3),
    _NavItem(icon: Icons.shopping_cart_rounded, label: 'Carrito', route: '/cart', index: 4),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Pedidos', route: '/my-orders', index: 5),
    _NavItem(icon: Icons.account_balance_rounded, label: 'Contabilidad', route: '/accounting', index: 6),
    _NavItem(icon: Icons.assessment_rounded, label: 'Reportes', route: '/reports', index: 7),
    _NavItem(icon: Icons.settings_rounded, label: 'Configuración', route: '/settings', index: 8),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize) {
        if (screenSize == ScreenSize.mobile) {
          return widget.mobileChild;
        }
        return _buildDesktopLayout(screenSize);
      },
    );
  }

  Widget _buildDesktopLayout(ScreenSize screenSize) {
    final sidebarWidth = _sidebarCollapsed ? 72.0 : 260.0;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          _buildSidebar(sidebarWidth, theme),
          Expanded(
            child: Column(
              children: [
                _buildHeader(screenSize, theme),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    padding: EdgeInsets.all(screenSize == ScreenSize.wide ? 32 : 24),
                    child: widget.mobileChild,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(double width, ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(theme),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = widget.currentIndex == item.index;
                return _buildSidebarItem(item, isSelected, theme);
              },
            ),
          ),
          _buildSidebarFooter(theme),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarCollapsed ? 16 : 20,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.computer_rounded, color: Colors.white, size: 20),
          ),
          if (!_sidebarCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TechService',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              _sidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              color: Colors.white54,
              size: 20,
            ),
            onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(_NavItem item, bool isSelected, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          onTap: () => Navigator.pushNamed(context, item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarCollapsed ? 0 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _sidebarCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : Colors.white.withValues(alpha: 0.6),
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarCollapsed ? 8 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: _sidebarCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (!_sidebarCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ScreenSize screenSize, ThemeData theme) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (screenSize == ScreenSize.wide) ...[
            Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else
            const Spacer(),
          _headerIconButton(Icons.notifications_rounded, badge: 3),
          const SizedBox(width: 8),
          _headerIconButton(Icons.help_outline_rounded),
          const SizedBox(width: 8),
          _headerIconButton(Icons.dark_mode_outlined),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, {int? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, size: 22, color: Colors.grey[600]),
          onPressed: () {},
          hoverColor: AppColors.primaryBlue.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        if (badge != null)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.index,
  });
}

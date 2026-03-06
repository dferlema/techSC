import 'package:flutter/material.dart';
import 'package:techsc/core/theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTabTapped;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });

  // Rutas y datos de las pestañas
  static const List<BottomNavigationBarItem> _items = [
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
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTabTapped,
      selectedItemColor: AppColors.goldAccent,
      unselectedItemColor: AppColors.textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed, // Evita "shifting" en 3 items
      items: _items,
    );
  }
}

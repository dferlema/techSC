import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Dashboard de Configuraciones
// ---------------------------------------------------------------------------

class SettingsDashboardView extends ConsumerWidget {
  /// Callback para navegar a una sección específica desde el grid de acceso rápido.
  /// El índice corresponde al índice del [IndexedStack] en [SettingsPage]:
  ///   1=Info Empresa, 2=Banners, 3=Seguridad, 4=Márgenes, 5=Cuentas, 6=Integraciones
  final void Function(int index) onNavigateTo;
  final bool isAdmin;

  const SettingsDashboardView({
    super.key,
    required this.onNavigateTo,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(context, l10n),
          const SizedBox(height: 28),
          _buildSectionTitle(context, 'Acceso Rápido', Icons.grid_view_rounded),
          const SizedBox(height: 12),
          _buildQuickAccessGrid(context, l10n),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Banner de bienvenida
  // -------------------------------------------------------------------------
  Widget _buildWelcomeBanner(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsPageTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configura los parámetros de la aplicación',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sección: título con ícono
  // -------------------------------------------------------------------------
  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Grid de acceso rápido
  // -------------------------------------------------------------------------
  Widget _buildQuickAccessGrid(BuildContext context, AppLocalizations l10n) {
    final List<_QuickSection> sections = [];

    if (isAdmin) {
      sections.addAll([
        _QuickSection(
          index: 1,
          label: l10n.companyInfoTab,
          icon: Icons.business_outlined,
          color: const Color(0xFF1565C0),
        ),
        _QuickSection(
          index: 2,
          label: l10n.bannersTab,
          icon: Icons.image_outlined,
          color: const Color(0xFF6A1B9A),
        ),
      ]);
    }

    sections.add(
      _QuickSection(
        index: 3,
        label: l10n.securityTab,
        icon: Icons.security_outlined,
        color: const Color(0xFF00695C),
      ),
    );

    if (isAdmin) {
      sections.addAll([
        _QuickSection(
          index: 4,
          label: 'Márgenes',
          icon: Icons.trending_up_outlined,
          color: const Color(0xFFE65100),
        ),
        _QuickSection(
          index: 5,
          label: 'Cuentas',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF880E4F),
        ),
        _QuickSection(
          index: 6,
          label: l10n.integrationsTab,
          icon: Icons.integration_instructions_outlined,
          color: const Color(0xFF1B5E20),
        ),
      ]);
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final s = sections[i];
        return _QuickAccessCard(section: s, onTap: () => onNavigateTo(s.index));
      },
    );
  }
}

class _QuickSection {
  final int index;
  final String label;
  final IconData icon;
  final Color color;

  const _QuickSection({
    required this.index,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _QuickAccessCard extends StatelessWidget {
  final _QuickSection section;
  final VoidCallback onTap;

  const _QuickAccessCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [section.color, section.color.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: section.color.withOpacity(0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(section.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(
                section.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

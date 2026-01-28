import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:techsc/core/widgets/notification_icon.dart';
import 'package:techsc/core/widgets/app_drawer.dart';
import 'package:techsc/core/utils/branding_helper.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  String get _whatsappNumber {
    String phone = BrandingHelper.companyPhone;
    if (phone.startsWith('0')) {
      return '593${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/$_whatsappNumber');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _makePhoneCall() async {
    final Uri url = Uri.parse('tel:$_whatsappNumber');
    if (!await launchUrl(url)) {
      debugPrint('No se pudo realizar la llamada');
    }
  }

  Future<void> _sendEmail() async {
    final Uri url = Uri.parse('mailto:${BrandingHelper.companyEmail}');
    if (!await launchUrl(url)) {
      debugPrint('No se pudo abrir el correo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      drawer: const AppDrawer(currentRoute: '/contact'),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, colorScheme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colorScheme),
                  const SizedBox(height: 32),
                  _buildWhatsAppHero(context, colorScheme),
                  const SizedBox(height: 40),
                  Text(
                    'Otros canales de atención',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactOptions(colorScheme),
                  const SizedBox(height: 48),
                  _buildFooter(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: colorScheme.primary,
                size: 20,
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/home');
                }
              },
            )
          : Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: colorScheme.primary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      actions: [
        NotificationIcon(color: colorScheme.primary),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Hola! 👋',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¿Cómo podemos ayudarte hoy?',
          style: TextStyle(
            fontSize: 20,
            color: colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppHero(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Icon(
              Icons.bolt_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.network(
                    'https://static.whatsapp.net/rsrc.php/yZ/r/JvsnINJ2CZv.svg',
                    width: 50,
                    height: 50,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    placeholderBuilder: (context) => const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Asistencia Inmediata',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Resolvemos tus dudas técnicas por WhatsApp en tiempo real.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _launchWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Iniciar Chat Ahora',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildModernOption(
          icon: Icons.phone_forwarded_rounded,
          color: Colors.blue,
          title: 'Línea Directa',
          subtitle: BrandingHelper.companyPhone,
          onTap: _makePhoneCall,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 16),
        _buildModernOption(
          icon: Icons.alternate_email_rounded,
          color: Colors.orange,
          title: 'Correo Electrónico',
          subtitle: BrandingHelper.companyEmail,
          onTap: _sendEmail,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 16),
        _buildModernOption(
          icon: Icons.location_on_rounded,
          color: Colors.redAccent,
          title: 'Ubicación Central',
          subtitle: BrandingHelper.companyAddress,
          onTap: () {},
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildModernOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: colorScheme.onSurface.withOpacity(0.2),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Estamos disponibles 24/7 para ti',
              style: TextStyle(
                color: theme.colorScheme.primary.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

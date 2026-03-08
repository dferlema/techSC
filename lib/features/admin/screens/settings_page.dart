import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/models/config_model.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';
import 'package:techsc/features/admin/screens/profit_margin_settings_page.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/features/admin/models/bank_account_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/features/admin/widgets/settings_dashboard_view.dart';

class _NavIndex {
  static const int dashboard = 0;
  static const int companyInfo = 1;
  static const int banners = 2;
  static const int security = 3;
  static const int margins = 4;
  static const int accounts = 5;
  static const int integrations = 6;
}

class _DrawerItem {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;

  const _DrawerItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
  });
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _currentIndex = _NavIndex.dashboard;
  final ConfigService _configService = ConfigService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _profitMarginKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _payphoneTokenController;
  late TextEditingController _payphoneStoreIdController;
  late TextEditingController _vatController;

  bool _isLoading = false;
  bool _isBiometricEnabled = false;
  bool _payphoneIsSandbox = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _payphoneTokenController = TextEditingController();
    _payphoneStoreIdController = TextEditingController();
    _vatController = TextEditingController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final config = await _configService.getConfig();
    _nameController.text = config.companyName;
    _emailController.text = config.companyEmail;
    _phoneController.text = config.companyPhone;
    _addressController.text = config.companyAddress;
    _payphoneTokenController.text = config.payphoneToken;
    _payphoneStoreIdController.text = config.payphoneStoreId;
    _vatController.text = config.vatPercentage.toString();

    final biometricEnabled = await _authService.isBiometricAuthEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = biometricEnabled;
        _payphoneIsSandbox = config.payphoneIsSandbox;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (value) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.biometricEnableInstructions),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() => _isBiometricEnabled = false);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.biometricDisableDialogTitle),
          content: Text(l10n.biometricDisableDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.biometricDisableDialogAction),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _authService.disableBiometrics();
        setState(() => _isBiometricEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricDisabledSuccess),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() => _isBiometricEnabled = true);
      }
    }
  }

  void _navigate(int index) {
    setState(() => _currentIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _payphoneTokenController.dispose();
    _payphoneStoreIdController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  Future<void> _saveCompanyInfo(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final config = ConfigModel(
        companyName: _nameController.text.trim(),
        companyEmail: _emailController.text.trim(),
        companyPhone: _phoneController.text.trim(),
        companyAddress: _addressController.text.trim(),
        payphoneToken: _payphoneTokenController.text.trim(),
        payphoneStoreId: _payphoneStoreIdController.text.trim(),
        payphoneIsSandbox: _payphoneIsSandbox,
        vatPercentage: double.tryParse(_vatController.text) ?? 15.0,
      );
      await _configService.updateConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsUpdateSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addBanner(AppLocalizations l10n) async {
    final TextEditingController urlController = TextEditingController();
    final String? imageUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addBannerDialogTitle),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://ejemplo.com/imagen.jpg',
            labelText: l10n.bannerUrlLabel,
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            child: Text(l10n.addBannerDialogAction),
          ),
        ],
      ),
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _configService.addBannerByUrl(imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.bannerAddedSuccess)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBanner(
    String docId,
    String imageUrl,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteBannerDialogTitle),
        content: Text(l10n.deleteBannerDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.deleteBannerDialogAction,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _configService.deleteBanner(docId, imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.bannerDeletedSuccess)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userRoleAsync = ref.watch(currentUserRoleProvider);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return userRoleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (role) {
        final isAdmin = role == RoleService.ADMIN;

        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.settingsPageTitle),
              actions: const [CartBadge(), SizedBox(width: 8)],
            ),
            body: _buildSecurityTab(l10n),
          );
        }

        String getTitle() {
          switch (_currentIndex) {
            case _NavIndex.dashboard:
              return l10n.settingsPageTitle;
            case _NavIndex.companyInfo:
              return l10n.companyInfoTab;
            case _NavIndex.banners:
              return l10n.bannersTab;
            case _NavIndex.security:
              return l10n.securityTab;
            case _NavIndex.margins:
              return 'Márgenes de Ganancia';
            case _NavIndex.accounts:
              return 'Cuentas Bancarias';
            case _NavIndex.integrations:
              return l10n.integrationsTab;
            default:
              return l10n.settingsPageTitle;
          }
        }

        final drawerItems = [
          _DrawerItem(
            index: _NavIndex.dashboard,
            label: 'Panel',
            icon: Icons.dashboard_rounded,
            selectedIcon: Icons.dashboard,
            color: const Color(0xFF09325E),
          ),
          _DrawerItem(
            index: _NavIndex.companyInfo,
            label: l10n.companyInfoTab,
            icon: Icons.business_outlined,
            selectedIcon: Icons.business,
            color: const Color(0xFF1565C0),
          ),
          _DrawerItem(
            index: _NavIndex.banners,
            label: l10n.bannersTab,
            icon: Icons.image_outlined,
            selectedIcon: Icons.image,
            color: const Color(0xFF6A1B9A),
          ),
          _DrawerItem(
            index: _NavIndex.security,
            label: l10n.securityTab,
            icon: Icons.security_outlined,
            selectedIcon: Icons.security,
            color: const Color(0xFF00695C),
          ),
          _DrawerItem(
            index: _NavIndex.margins,
            label: 'Márgenes',
            icon: Icons.trending_up_outlined,
            selectedIcon: Icons.trending_up,
            color: const Color(0xFFE65100),
          ),
          _DrawerItem(
            index: _NavIndex.accounts,
            label: 'Cuentas',
            icon: Icons.account_balance_rounded,
            selectedIcon: Icons.account_balance,
            color: const Color(0xFF880E4F),
          ),
          _DrawerItem(
            index: _NavIndex.integrations,
            label: l10n.integrationsTab,
            icon: Icons.integration_instructions_outlined,
            selectedIcon: Icons.integration_instructions,
            color: const Color(0xFF1B5E20),
          ),
        ];

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_currentIndex != _NavIndex.dashboard) {
                  setState(() => _currentIndex = _NavIndex.dashboard);
                } else {
                  Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : Navigator.of(context).pushReplacementNamed('/main');
                }
              },
            ),
            title: Text(getTitle()),
            actions: const [CartBadge(), SizedBox(width: 8)],
          ),
          drawer: NavigationDrawer(
            selectedIndex: _currentIndex,
            onDestinationSelected: _navigate,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.accentBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configuración',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Administrador',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Divider(),
              ),
              ...drawerItems.map(
                (item) => NavigationDrawerDestination(
                  icon: Icon(item.icon, color: item.color),
                  selectedIcon: Icon(item.selectedIcon, color: item.color),
                  label: Text(item.label),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              SettingsDashboardView(onNavigateTo: _navigate, isAdmin: isAdmin),
              _buildCompanyInfoTab(l10n),
              _buildBannersTab(l10n),
              _buildSecurityTab(l10n),
              ProfitMarginSettingsPage(key: _profitMarginKey),
              _buildBankAccountsTab(context),
              _buildIntegrationsTab(l10n),
            ],
          ),
          floatingActionButton:
              _currentIndex == _NavIndex.margins ||
                  _currentIndex == _NavIndex.accounts
              ? _currentIndex == _NavIndex.margins
                    ? ref
                          .watch(profitRangesProvider)
                          .when(
                            data: (ranges) => FloatingActionButton.extended(
                              onPressed: () {
                                final state =
                                    (_profitMarginKey.currentState as dynamic);
                                if (state != null) {
                                  state.addRange(ranges);
                                }
                              },
                              label: const Text('Agregar Rango'),
                              icon: const Icon(Icons.add),
                              backgroundColor: AppColors.primaryBlue,
                            ),
                            loading: () => null,
                            error: (_, __) => null,
                          )
                    : FloatingActionButton.extended(
                        onPressed: () => _showBankAccountDialog(context),
                        label: const Text('Agregar Cuenta'),
                        icon: const Icon(Icons.add),
                        backgroundColor: AppColors.primaryBlue,
                      )
              : null,
        );
      },
    );
  }

  Widget _buildCompanyInfoTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: l10n.companyNameLabel,
              icon: Icons.store,
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: l10n.companyEmailLabel,
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: l10n.companyPhoneLabel,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              helperText: l10n.companyPhoneHelper,
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: l10n.companyAddressLabel,
              icon: Icons.location_on,
              maxLines: 2,
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _vatController,
              label: 'IVA (%)',
              icon: Icons.percent,
              keyboardType: TextInputType.number,
              l10n: l10n,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveCompanyInfo(l10n),
                icon: const Icon(Icons.save),
                label: Text(l10n.saveSettingsButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        helperText: helperText,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.requiredField;
        }
        return null;
      },
    );
  }

  Widget _buildBannersTab(AppLocalizations l10n) {
    final bannersAsync = ref.watch(bannersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _addBanner(l10n),
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(l10n.addBannerButton),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: bannersAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (err, _) => AppErrorWidget(error: err),
            data: (snapshot) {
              if (snapshot.docs.isEmpty) {
                return Center(child: Text(l10n.noBannersConfigured));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteBanner(doc.id, imageUrl, l10n),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: _isBiometricEnabled ? Colors.green : Colors.grey,
                ),
                title: Text(l10n.biometricLoginLabel),
                subtitle: Text(
                  _isBiometricEnabled
                      ? l10n.biometricEnabledStatus
                      : l10n.biometricDisabledStatus,
                ),
                trailing: Switch(
                  value: _isBiometricEnabled,
                  onChanged: _toggleBiometrics,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  _isBiometricEnabled
                      ? l10n.biometricDisableWarning
                      : l10n.biometricEnableInstructions,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntegrationsTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Payphone',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildTextField(
                    controller: _payphoneTokenController,
                    label: l10n.payphoneTokenLabel,
                    icon: Icons.vpn_key,
                    l10n: l10n,
                    helperText: 'Token de autenticación de Payphone',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _payphoneStoreIdController,
                    label: l10n.payphoneStoreIdLabel,
                    icon: Icons.store,
                    l10n: l10n,
                    helperText: 'ID de tu tienda en Payphone Developer',
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.payphoneSandboxLabel),
                    subtitle: const Text('Usar entorno de pruebas'),
                    value: _payphoneIsSandbox,
                    onChanged: (val) =>
                        setState(() => _payphoneIsSandbox = val),
                    secondary: const Icon(Icons.bug_report_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _saveCompanyInfo(l10n),
              icon: const Icon(Icons.save),
              label: Text(l10n.saveSettingsButton),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bank Account Helpers ---

  Future<void> _showBankAccountDialog(
    BuildContext context, [
    BankAccount? account,
  ]) async {
    final l10n = AppLocalizations.of(context)!;
    final bankController = TextEditingController(text: account?.bankName);
    final typeController = TextEditingController(text: account?.accountType);
    final numberController = TextEditingController(
      text: account?.accountNumber,
    );
    final holderNameController = TextEditingController(
      text: account?.holderName,
    );
    final holderIdController = TextEditingController(text: account?.holderId);
    final holderEmailController = TextEditingController(
      text: account?.holderEmail,
    );

    final result = await showDialog<BankAccount>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? 'Nueva Cuenta' : 'Editar Cuenta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Banco'),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Tipo (Ahorros/Corriente)',
                ),
              ),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Número de Cuenta',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: holderNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Titular',
                ),
              ),
              TextField(
                controller: holderIdController,
                decoration: const InputDecoration(
                  labelText: 'CI/RUC del Titular',
                ),
              ),
              TextField(
                controller: holderEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email del Titular',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                BankAccount(
                  id:
                      account?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  bankName: bankController.text,
                  accountType: typeController.text,
                  accountNumber: numberController.text,
                  holderName: holderNameController.text,
                  holderId: holderIdController.text,
                  holderEmail: holderEmailController.text,
                ),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null) {
      final currentAccounts = await _configService.getBankAccounts();
      if (account == null) {
        currentAccounts.add(result);
      } else {
        final index = currentAccounts.indexWhere((a) => a.id == account.id);
        if (index != -1) currentAccounts[index] = result;
      }
      await _saveBankAccounts(currentAccounts);
    }
  }

  Future<void> _saveBankAccounts(List<BankAccount> accounts) async {
    setState(() => _isLoading = true);
    try {
      await _configService.updateBankAccounts(accounts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuentas actualizadas con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareOnWhatsApp(BankAccount account) async {
    final message = Uri.encodeComponent(account.toWhatsAppString());
    final url = Uri.parse('https://wa.me/?text=$message');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Widget _buildBankAccountsTab(BuildContext context) {
    final accountsAsync = ref.watch(bankAccountsProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Center(child: Text('No hay cuentas configuradas'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  account.bankName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${account.accountType} - ${account.accountNumber}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.green),
                      onPressed: () => _shareOnWhatsApp(account),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showBankAccountDialog(context, account),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar Cuenta'),
                            content: const Text(
                              '¿Está seguro de eliminar esta cuenta?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          accounts.removeAt(index);
                          await _saveBankAccounts(accounts);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const AppLoadingIndicator(),
      error: (e, __) => AppErrorWidget(error: e),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/reservations/screens/service_detail_page.dart';
import 'package:techsc/features/catalog/services/category_service.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/features/cart/services/cart_service.dart';
import 'package:techsc/features/cart/screens/cart_page.dart';

class ServicesPage extends StatefulWidget {
  final String routeName;
  const ServicesPage({super.key, this.routeName = '/services'});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId; // null para 'Todos'
  late PageController _pageController;

  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await RoleService().getUserRole(user.uid);
      if (mounted) {
        setState(
          () => _canManage =
              (role == RoleService.ADMIN || role == RoleService.TECHNICIAN),
        );
      }
    }
  }

  Future<void> _deleteService(String serviceId) async {
    await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Servicio eliminado')));
  }

  void _addToCart(Map<String, dynamic> service) {
    CartService.instance.addToCart(service, type: 'service');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${service['title']} agregado al carrito'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VER',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceList(String? categoryId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allServices = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'id': doc.id};
        }).toList();

        // 1. Filtrar por categoryId (si no es null/Todos)
        var filtered = categoryId == null || categoryId.isEmpty
            ? allServices
            : allServices.where((s) => s['categoryId'] == categoryId).toList();

        // 2. Filtrar por búsqueda inteligente
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filtered = filtered.where((s) {
            final title = (s['title'] ?? '').toString().toLowerCase();
            final desc = (s['description'] ?? '').toString().toLowerCase();
            final components =
                (s['components'] as List?)?.join(' ').toLowerCase() ?? '';
            return title.contains(query) ||
                desc.contains(query) ||
                components.contains(query);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 60,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay servicios en esta categoría',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final service = filtered[index];
            return _buildServiceCard(
              service: service,
              serviceId: service['id'],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryModel>>(
      stream: CategoryService().getCategories(CategoryType.service),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        // Preparar lista con "Todos" al inicio
        final fullCategories = [
          CategoryModel(id: '', name: 'Todos', type: CategoryType.service),
          ...categories,
        ];

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isSearching) {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/main');
                }
              },
            ),
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar servicios...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuestros Servicios',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Soporte técnico experto',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
              const CartBadge(color: Colors.white),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: fullCategories.length,
                  itemBuilder: (context, index) {
                    final cat = fullCategories[index];
                    final isSelected =
                        _selectedCategoryId == cat.id ||
                        (_selectedCategoryId == null && cat.id == '');
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.indigo[900]?.withOpacity(0.7),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategoryId = cat.id);
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        selectedColor: Colors.indigo[600],
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.indigo[100]!,
                          ),
                        ),
                        elevation: isSelected ? 4 : 0,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: fullCategories.length,
            onPageChanged: (index) {
              setState(() => _selectedCategoryId = fullCategories[index].id);
            },
            itemBuilder: (context, index) {
              return _buildServiceList(fullCategories[index].id);
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceCard({
    required Map<String, dynamic> service,
    String? serviceId,
  }) {
    final theme = Theme.of(context);
    final price = service['price'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (serviceId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ServiceDetailPage(service: service, serviceId: serviceId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Stack(
                children: [
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      child: service['imageUrl'] != null
                          ? Image.network(
                              service['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildPlaceholder(size: 40),
                            )
                          : _buildPlaceholder(size: 40),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${service['rating'] ?? 4.8}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['title'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.black87,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        service['description'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          if (!_canManage)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange[700]!,
                                    Colors.orange[400]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _addToCart(service),
                                  borderRadius: BorderRadius.circular(15),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Comprar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (serviceId != null)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Usa el Panel Admin para editar',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteService(serviceId),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({double size = 50}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.build_circle_outlined,
          size: size,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

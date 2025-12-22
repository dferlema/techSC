// lib/screens/products_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import '../services/role_service.dart'; // 👈 Nuevo
import 'cart_page.dart';
import 'product_detail_page.dart';

class ProductsPage extends StatefulWidget {
  final String routeName;
  const ProductsPage({super.key, this.routeName = '/products'});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, String> _categoryIds = {
    'Todos': '',
    'Computadoras': 'computadoras',
    'Accesorios': 'accesorios',
    'Repuestos': 'repuestos',
  };

  // Permisos de gestión
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryIds.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final canManage = await RoleService().canManageProducts(user.uid);
      if (mounted) setState(() => _canManage = canManage);
    }
  }

  void _addToCart(Map<String, dynamic>? product) {
    if (product == null) return;

    CartService.instance.addToCart(product);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${product['name']} agregado al carrito')),
    );
  }

  // 🗑️ Eliminar producto
  Future<void> _deleteProduct(String productId) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
  }

  // 🎨 Widget de tarjeta de producto (Rediseñado)
  Widget _buildProductCard({
    required Map<String, dynamic> product,
    String? productId,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ Imagen Centrada y Adaptada
            Center(
              child: GestureDetector(
                onTap: () {
                  if (productId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailPage(
                          product: product,
                          productId: productId,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Hero(
                    tag: 'product-image-${productId ?? "unknown"}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        product['image'] ??
                            'https://via.placeholder.com/300x200?text=Sin+Imagen',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 📝 Información del Producto
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product['name'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // ⭐ Rating
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${product['rating'] ?? 4.5}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 📄 Descripción
            if (product['description'] != null &&
                product['description'].toString().isNotEmpty) ...[
              Text(
                product['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],

            Text(
              product['specs'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 💰 Precio y Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${product['price'] ?? 0}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                // 👇 Botones de Acción
                if (!_canManage)
                  ElevatedButton.icon(
                    onPressed: () => _addToCart(product),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else if (productId != null)
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // Navegar a editar (esto requeriría importar ProductFormPage o similar)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Usa el Panel Admin para editar'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        onPressed: () => _deleteProduct(productId),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 📦 Lista de productos (por categoría)
  Widget _buildProductList(String categoryId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allProducts = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'id': doc.id};
        }).toList();

        // Filtrar por categoría (si no es "Todos")
        final filtered = categoryId.isEmpty
            ? allProducts
            : allProducts.where((p) => p['category'] == categoryId).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No hay productos en esta categoría',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return _buildProductCard(
              product: product,
              productId: product['id'],
            );
          },
        );
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/main');
            }
          },
        ),
        actions: [
          // 🛒 Botón del Carrito con Badge
          AnimatedBuilder(
            animation: CartService.instance,
            builder: (context, child) {
              final itemCount = CartService.instance.itemCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartPage(),
                        ),
                      );
                    },
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$itemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuestros Productos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Encuentra las mejores computadoras, accesorios y repuestos',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      // drawer: AppDrawer(currentRoute: widget.routeName), // Removido
      body: TabBarView(
        controller: _tabController,
        children: _categoryIds.values.map((id) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildProductList(id),
          );
        }).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabController.index,
        onDestinationSelected: (int index) {
          setState(() {
            _tabController.animateTo(index);
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Todos',
          ),
          NavigationDestination(
            icon: Icon(Icons.computer_outlined),
            selectedIcon: Icon(Icons.computer),
            label: 'Computadoras',
          ),
          NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            selectedIcon: Icon(Icons.headphones),
            label: 'Accesorios',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Repuestos',
          ),
        ],
      ),
      // 👇 Botones flotantes SOLO para administradores/vendedores
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Crear nuevo producto')),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

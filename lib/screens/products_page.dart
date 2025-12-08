// lib/screens/products_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_drawer.dart';

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

  // Determinar si es admin
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryIds.length, vsync: this);
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isAdmin = false);
      return;
    }

    // 🔐 Verificación segura: leer rol desde Firestore
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userData.data()?['role'] ?? 'cliente';
      setState(() => _isAdmin = (role == 'admin'));
    } catch (e) {
      setState(() => _isAdmin = false);
    }
  }

  void _addToCart(Map<String, dynamic>? product) {
    if (product == null) return;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
  }

  // 🎨 Widget de tarjeta de producto (dual-mode)
  Widget _buildProductCard({
    required Map<String, dynamic> product,
    String? productId,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              product['image'] ??
                  'https://via.placeholder.com/300x200?text=Sin+Imagen',
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image, size: 40)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text(
                      '${product['rating'] ?? 4.5}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${product['price'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // 👇 Modo Cliente: Botón "Agregar"
                if (!_isAdmin)
                  ElevatedButton.icon(
                    onPressed: () => _addToCart(product),
                    icon: const Icon(Icons.shopping_cart, size: 16),
                    label: const Text(
                      'Agregar',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),

                // 👇 Modo Administrador: Botones Editar/Eliminar
                if (_isAdmin && productId != null)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Editar: ${product['name']}'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text(
                          'Editar',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _deleteProduct(productId),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categoryIds.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1976D2),
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
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: _categoryIds.keys
                .map((category) => Tab(text: category))
                .toList(),
          ),
        ),
        drawer: AppDrawer(currentRoute: widget.routeName),
        body: TabBarView(
          controller: _tabController,
          children: _categoryIds.values.map((id) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildProductList(id),
            );
          }).toList(),
        ),
        // 👇 Botón flotante SOLO para administradores
        floatingActionButton: _isAdmin
            ? FloatingActionButton(
                backgroundColor: const Color(0xFF1976D2),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Crear nuevo producto')),
                  );
                },
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}

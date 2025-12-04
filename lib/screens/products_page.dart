// lib/screens/products_page.dart

import 'package:flutter/material.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Datos de productos por categoría
  final Map<String, List<Map<String, dynamic>>> _productCategories = {
    'Todos': [
      {
        'name': 'Laptop Gaming MSI',
        'price': 1299,
        'rating': 4.8,
        'image': 'https://via.placeholder.com/300x200?text=Laptop+Gaming',
      },
      {
        'name': 'Teclado Mecánico RGB',
        'price': 89,
        'rating': 4.5,
        'image': 'https://via.placeholder.com/300x200?text=Teclado',
      },
      {
        'name': 'Monitor 27" 144Hz',
        'price': 299,
        'rating': 4.7,
        'image': 'https://via.placeholder.com/300x200?text=Monitor',
      },
      {
        'name': 'Fuente de Poder 850W',
        'price': 159,
        'rating': 4.9,
        'image': 'https://via.placeholder.com/300x200?text=Fuente',
      },
    ],
    'Computadoras': [
      {
        'name': 'Laptop Gaming MSI',
        'price': 1299,
        'rating': 4.8,
        'image': 'https://via.placeholder.com/300x200?text=Laptop+Gaming',
      },
      {
        'name': 'PC de Escritorio Intel i9',
        'price': 1899,
        'rating': 4.6,
        'image': 'https://via.placeholder.com/300x200?text=PC+i9',
      },
    ],
    'Accesorios': [
      {
        'name': 'Teclado Mecánico RGB',
        'price': 89,
        'rating': 4.5,
        'image': 'https://via.placeholder.com/300x200?text=Teclado',
      },
      {
        'name': 'Mouse Inalámbrico Logitech',
        'price': 45,
        'rating': 4.3,
        'image': 'https://via.placeholder.com/300x200?text=Mouse',
      },
      {
        'name': 'Audífonos Gaming',
        'price': 120,
        'rating': 4.4,
        'image': 'https://via.placeholder.com/300x200?text=Audífonos',
      },
    ],
    'Repuestos': [
      {
        'name': 'Fuente de Poder 850W',
        'price': 159,
        'rating': 4.9,
        'image': 'https://via.placeholder.com/300x200?text=Fuente',
      },
      {
        'name': 'Disco SSD 1TB',
        'price': 99,
        'rating': 4.8,
        'image': 'https://via.placeholder.com/300x200?text=SSD',
      },
      {
        'name': 'Memoria RAM 16GB DDR4',
        'price': 65,
        'rating': 4.7,
        'image': 'https://via.placeholder.com/300x200?text=RAM',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _productCategories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addToCart(Map<String, dynamic> product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${product['name']} agregado al carrito')),
    );
  }

  // Widget reutilizable para una lista de productos
  Widget _buildProductList(List<Map<String, dynamic>> products) {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  product['image'],
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Imagen no disponible')),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(
                          '${product['rating']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${product['price']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _addToCart(product),
                      icon: const Icon(Icons.shopping_cart, size: 16),
                      label: const Text(
                        'Agregar',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _productCategories.length,
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
            isScrollable:
                true, // 👈 Permite desplazar pestañas en pantallas pequeñas
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            tabs: _productCategories.keys.map((category) {
              return Tab(text: category);
            }).toList(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: _productCategories.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildProductList(entry.value),
            );
          }).toList(),
        ),
      ),
    );
  }
}

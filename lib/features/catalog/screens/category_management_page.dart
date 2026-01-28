import 'package:flutter/material.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/features/catalog/services/category_service.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final CategoryService _categoryService = CategoryService();
  CategoryType _selectedType = CategoryType.product;

  void _showCategoryDialog({CategoryModel? category, CategoryType? type}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final isEditing = category != null;
    final categoryType = type ?? category?.type ?? _selectedType;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tipo: ${categoryType == CategoryType.product ? "Producto" : "Servicio"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la categoría',
                  border: const OutlineInputBorder(),
                  enabled: !isLoading,
                ),
                autofocus: true,
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      setDialogState(() => isLoading = true);
                      try {
                        if (isEditing) {
                          await _categoryService.updateCategory(
                            category.id,
                            name,
                          );
                        } else {
                          await _categoryService.addCategory(
                            name,
                            categoryType,
                          );
                        }
                        if (mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? 'Categoría actualizada'
                                  : 'Categoría creada con éxito',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: Text(isEditing ? 'Actualizar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestión de Categorías'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTypeChip(
                  'Productos',
                  CategoryType.product,
                  Icons.inventory_2,
                ),
                const SizedBox(width: 12),
                _buildTypeChip('Servicios', CategoryType.service, Icons.build),
              ],
            ),
          ),
        ),
      ),
      body: _buildCategoryList(_selectedType),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(type: _selectedType),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTypeChip(String label, CategoryType type, IconData icon) {
    final isSelected = _selectedType == type;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : Colors.indigo[900]?.withOpacity(0.5),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : Colors.indigo[900]?.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedType = type);
        }
      },
      selectedColor: Colors.indigo[600],
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.indigo[100]!,
        ),
      ),
      elevation: isSelected ? 4 : 0,
      pressElevation: 2,
    );
  }

  Widget _buildCategoryList(CategoryType type) {
    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryService.getCategories(type),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error al cargar categorías',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                if (snapshot.error.toString().contains('index'))
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'TIP: Si el error menciona un "index", es necesario crearlo en la consola de Firebase. Haz clic en el enlace que suele aparecer en el log de depuración.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No hay categorías de ${type == CategoryType.product ? "productos" : "servicios"}',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        final categories = snapshot.data!;
        return ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(category.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showCategoryDialog(category: category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteDialog(category),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Estás seguro de eliminar "${category.name}"? '
          'Los productos/servicios asociados podrían quedar sin categoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _categoryService.deleteCategory(category.id);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/role_service.dart';

/// Diálogo para asignar o cambiar el rol de un usuario
class RoleAssignmentDialog extends StatefulWidget {
  final String userId;
  final String currentRole;
  final String userName;
  final String userEmail;

  const RoleAssignmentDialog({
    super.key,
    required this.userId,
    required this.currentRole,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<RoleAssignmentDialog> {
  late String _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  Future<void> _assignRole() async {
    if (_selectedRole == widget.currentRole) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await RoleService().assignRole(
        targetUserId: widget.userId,
        newRole: _selectedRole,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Rol actualizado a ${RoleService.getRoleName(_selectedRole)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Asignar Rol de Usuario',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del usuario
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.userEmail,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rol actual
            Row(
              children: [
                const Text(
                  'Rol actual: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${RoleService.getRoleIcon(widget.currentRole)} ${RoleService.getRoleName(widget.currentRole)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Selector de nuevo rol
            const Text(
              'Seleccionar nuevo rol:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Opciones de roles
            _buildRoleOption(RoleService.CLIENT),
            const SizedBox(height: 8),
            _buildRoleOption(RoleService.SELLER),
            const SizedBox(height: 8),
            _buildRoleOption(RoleService.ADMIN),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignRole,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Asignar Rol'),
        ),
      ],
    );
  }

  Widget _buildRoleOption(String role) {
    final isSelected = _selectedRole == role;
    final roleName = RoleService.getRoleName(role);
    final roleIcon = RoleService.getRoleIcon(role);
    final roleDescription = RoleService.getRoleDescription(role);

    return InkWell(
      onTap: _isLoading ? null : () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: role,
              groupValue: _selectedRole,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _selectedRole = value!),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$roleIcon $roleName',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleDescription,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Función helper para mostrar el diálogo
Future<bool?> showRoleAssignmentDialog(
  BuildContext context, {
  required String userId,
  required String currentRole,
  required String userName,
  required String userEmail,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => RoleAssignmentDialog(
      userId: userId,
      currentRole: currentRole,
      userName: userName,
      userEmail: userEmail,
    ),
  );
}

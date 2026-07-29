import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { lastSyncOk, offlineOnly }

class UserManagementDialogs {
  /// Diálogo para la creación de usuarios con sincronización local/remota
  static Future<void> showCreateUserDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String currentOperatorRole,
    required Future<SyncStatus> Function(String username, String password, String role) onCreateUser,
  }) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Cajero';

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Crear Nuevo Usuario'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Usuario',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol de Usuario',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Cajero',
                          child: Text('Cajero'),
                        ),
                        DropdownMenuItem(
                          value: 'Administrador',
                          child: Text('Administrador'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedRole = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final username = usernameController.text.trim();
                    final password = passwordController.text.trim();

                    if (username.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Todos los campos son obligatorios.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final status = await onCreateUser(username, password, selectedRole);

                    if (!dialogContext.mounted) return;

                    final messenger = ScaffoldMessenger.of(dialogContext);
                    Navigator.of(dialogContext).pop();

                    final isSynced = status == SyncStatus.lastSyncOk;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          isSynced
                              ? 'Usuario "$username" creado y sincronizado en la nube.'
                              : 'Usuario "$username" guardado localmente (sin conexión).',
                        ),
                        backgroundColor: isSynced ? Colors.green : Colors.orange,
                      ),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Diálogo para visualizar el reporte diario de ventas
  static Future<void> showSalesReportDialog({
    required BuildContext context,
    required double totalSales,
    required int totalTransactions,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assessment, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Reporte de Ventas'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.greenAccent,
                  child: Icon(Icons.monetization_on, color: Colors.green),
                ),
                title: const Text('Ventas Totales'),
                subtitle: Text(
                  '\$${totalSales.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.lightBlueAccent,
                  child: Icon(Icons.receipt_long, color: Colors.blue),
                ),
                title: const Text('Transacciones Realizadas'),
                subtitle: Text(
                  '$totalTransactions operaciones',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }
}
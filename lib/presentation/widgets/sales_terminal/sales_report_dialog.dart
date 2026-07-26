import 'package:flutter/material.dart';
import '../../../core/sync_status.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/sales_repository.dart';

/// Diálogo para crear una nueva cuenta de empleado (cajero/administrador).
///
/// Extraído de `SalesTerminalScreen._showCreateUserDialog`. Se abre desde
/// dentro de [showSalesReportDialog], por eso recibe el `setDialogState`
/// del diálogo padre: así la lista de usuarios se refresca sin tener que
/// cerrar y reabrir todo el panel.
void showCreateUserDialog(
  BuildContext context, {
  required String currentOperatorRole,
  required Future<void> Function() onCreated,
}) {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String selectedRole = 'Cajero';

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setInnerState) => AlertDialog(
        title: const Text('Nueva Cuenta de Empleado', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de Usuario', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Puesto', prefixIcon: Icon(Icons.badge)),
              items: const [
                DropdownMenuItem(value: 'Cajero', child: Text('Cajero')),
                DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
              ],
              onChanged: (val) {
                if (val != null) setInnerState(() => selectedRole = val);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
            onPressed: () async {
              if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
              try {
                await AuthRepository.instance.registerUser(
                  currentOperatorRole: currentOperatorRole,
                  newUsername: userCtrl.text.trim(),
                  newPassword: passCtrl.text,
                  newRole: selectedRole,
                );
                Navigator.pop(dialogContext);
                await onCreated();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      SyncStatus.lastSyncOk
                          ? 'Cuenta creada y sincronizada con Supabase.'
                          : '⚠️ Cuenta creada solo en este equipo: no se pudo sincronizar con Supabase.',
                    ),
                    backgroundColor: SyncStatus.lastSyncOk ? Colors.green : Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

/// Panel de control de la Terminal de Ventas: corte de caja del día y,
/// para administradores, gestión de personal (crear/dar de baja cuentas).
///
/// Extraído de `SalesTerminalScreen._showSalesReport`. Es el bloque más
/// grande que tenía el widget original -- se movió tal cual, incluyendo
/// su propio `StatefulBuilder` interno para refrescar sales/users sin
/// cerrar el diálogo.
void showSalesReportDialog(BuildContext context, {required String userRole}) async {
  List<Map<String, dynamic>> sales = await SalesRepository.instance.getSales();
  List<Map<String, dynamic>> users = await AuthRepository.instance.getUsers();

  double granTotal = 0.0;
  for (var sale in sales) {
    granTotal += sale['total'] ?? 0.0;
  }

  if (!context.mounted) return;
  final isAdmin = userRole == 'Administrador' || userRole == 'admin';

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => DefaultTabController(
        length: isAdmin ? 2 : 1,
        child: AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics, color: Color(0xFF232D37)),
                  SizedBox(width: 10),
                  Text('Panel de Control', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  // Botón para reintentar la sincronización con Supabase
                  // sin tener que cerrar y reabrir el panel.
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Sincronizar con Supabase',
                    onPressed: () async {
                      final freshSales = await SalesRepository.instance.getSales();
                      final freshUsers = await AuthRepository.instance.getUsers();
                      double freshTotal = 0.0;
                      for (var sale in freshSales) {
                        freshTotal += sale['total'] ?? 0.0;
                      }
                      final syncOk = SyncStatus.lastSyncOk;
                      setDialogState(() {
                        sales = freshSales;
                        users = freshUsers;
                        granTotal = freshTotal;
                      });
                      if (!syncOk && dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('⚠️ No se pudo sincronizar con Supabase.'), backgroundColor: Colors.orange),
                        );
                      }
                    },
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            height: 400,
            child: Column(
              children: [
                TabBar(
                  labelColor: const Color(0xFF232D37),
                  indicatorColor: const Color(0xFF232D37),
                  tabs: [
                    const Tab(text: 'Corte de Caja'),
                    if (isAdmin) const Tab(text: 'Gestión de Personal'),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [
                      Column(
                        children: [
                          Card(
                            color: Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('VENTAS ACUMULADAS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('\$${granTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: sales.isEmpty
                                ? const Center(child: Text('Sin movimientos hoy.'))
                                : ListView.builder(
                                    itemCount: sales.length,
                                    itemBuilder: (context, index) {
                                      final sale = sales[index];
                                      final saleId = sale['id'] as int;
                                      return ExpansionTile(
                                        leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                                        title: Text('Ticket ID: #$saleId'),
                                        subtitle: Text(sale['date'].toString().substring(11, 19)),
                                        trailing: Text('\$${(sale['total'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        // Al desplegar el ticket se muestra el desglose de
                                        // productos vendidos, sincronizado desde Supabase.
                                        children: [
                                          FutureBuilder<List<Map<String, dynamic>>>(
                                            future: SalesRepository.instance.getSaleDetails(saleId),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                );
                                              }
                                              final details = snapshot.data ?? [];
                                              if (details.isEmpty) {
                                                return const Padding(
                                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                                  child: Text('Sin desglose disponible para este ticket.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                );
                                              }
                                              return Column(
                                                children: details.map((item) {
                                                  final qty = item['quantity'] ?? 0;
                                                  final price = (item['price'] ?? 0.0) as num;
                                                  return Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text('${item['product_name']} x$qty', style: const TextStyle(fontSize: 13)),
                                                        ),
                                                        Text('\$${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                      if (isAdmin)
                        Column(
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Nueva cuenta'),
                                onPressed: () => showCreateUserDialog(
                                  dialogContext,
                                  currentOperatorRole: userRole,
                                  onCreated: () async {
                                    final updatedUsers = await AuthRepository.instance.getUsers();
                                    setDialogState(() { users = updatedUsers; });
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: users.isEmpty
                                  ? const Center(child: Text('No hay cuentas creadas.'))
                                  : ListView.builder(
                                      itemCount: users.length,
                                      itemBuilder: (context, index) {
                                        final user = users[index];
                                        return ListTile(
                                          leading: const Icon(Icons.person_outline, color: Color(0xFF232D37)),
                                          title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Puesto: ${user['role']}'),
                                          trailing: user['role'] == 'Administrador' || user['username'] == 'admin'
                                              ? const Tooltip(message: 'Cuenta Raíz Protegida', child: Icon(Icons.shield, color: Colors.amber))
                                              : IconButton(
                                                  icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                                  tooltip: 'Dar de baja inmediatamente',
                                                  onPressed: () async {
                                                    await AuthRepository.instance.deleteUser(user['username']);
                                                    final updatedUsers = await AuthRepository.instance.getUsers();
                                                    setDialogState(() { users = updatedUsers; });
                                                  },
                                                ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
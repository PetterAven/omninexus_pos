import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync_status.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../domain/entities/sale_detail.dart';
import '../../providers/auth_controller.dart';
import '../../providers/sales_controller.dart';
import '../../providers/user_controller.dart';

/// Diálogo para crear una nueva cuenta de empleado (cajero/administrador).
///
/// Llama a userControllerProvider.addUser(), que ya trae su propia
/// validación de autorización y su propio refresh() de la lista.
void showCreateUserDialog(
  BuildContext context,
  WidgetRef ref, {
  required String currentOperatorRole,
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
              initialValue: selectedRole,
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
                final result = await ref.read(userControllerProvider.notifier).addUser(
                      currentOperatorRole: currentOperatorRole,
                      username: userCtrl.text.trim(),
                      password: passCtrl.text,
                      role: selectedRole,
                    );

                if (!dialogContext.mounted) return;

                if (result == UserSaveResult.notAuthorized) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Acceso Denegado: Tu rol actual ($currentOperatorRole) no tiene autorización para dar de alta cuentas.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext);
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
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
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
/// CORREGIDO: tanto el corte de caja como la lista de personal ya no
/// viven como variables locales del StatefulBuilder -- ambas pestañas
/// se envuelven en su propio Consumer y leen directo de
/// salesControllerProvider / userControllerProvider. El botón de
/// refresh ya no hace su propio fetch+setDialogState: solo llama a
/// refresh() de los controllers correspondientes.
void showSalesReportDialog(BuildContext context, WidgetRef ref) async {
  final userRole = ref.read(currentUserProvider)?.role ?? 'Cajero';
  final isAdmin = userRole == 'Administrador' || userRole == 'admin';

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (dialogContext) => DefaultTabController(
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
                    await ref.read(salesControllerProvider.notifier).refresh();
                    if (isAdmin) {
                      await ref.read(userControllerProvider.notifier).refresh();
                    }
                    if (!SyncStatus.lastSyncOk && dialogContext.mounted) {
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
                    Consumer(
                      builder: (context, ref, _) {
                        final salesAsync = ref.watch(salesControllerProvider);
                        final granTotal = ref.watch(salesTotalProvider);

                        return Column(
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
                              child: salesAsync.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (error, stackTrace) => Center(
                                  child: Text('No se pudo cargar el corte de caja: $error'),
                                ),
                                data: (sales) {
                                  if (sales.isEmpty) {
                                    return const Center(child: Text('Sin movimientos hoy.'));
                                  }
                                  return ListView.builder(
                                    itemCount: sales.length,
                                    itemBuilder: (context, index) {
                                      final sale = sales[index];
                                      final saleId = sale.id;
                                      return ExpansionTile(
                                        leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                                        title: Text('Ticket ID: #$saleId'),
                                        subtitle: Text(sale.date.substring(11, 19)),
                                        trailing: Text('\$${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        // Al desplegar el ticket se muestra el desglose de
                                        // productos vendidos, sincronizado desde Supabase.
                                        // Esto se queda como FutureBuilder puntual -- no hay
                                        // necesidad de un controller para un detalle que solo
                                        // se consulta al expandir un ticket.
                                        children: [
                                          FutureBuilder<List<SaleDetail>>(
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
                                                  final qty = item.quantity;
                                                  final price = item.price;
                                                  return Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text('${item.productName} x$qty', style: const TextStyle(fontSize: 13)),
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
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (isAdmin)
                      Consumer(
                        builder: (context, ref, _) {
                          final usersAsync = ref.watch(userControllerProvider);
                          return Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text('Nueva cuenta'),
                                  onPressed: () => showCreateUserDialog(
                                    dialogContext,
                                    ref,
                                    currentOperatorRole: userRole,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: usersAsync.when(
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (error, stackTrace) => Center(
                                    child: Text('No se pudo cargar el personal: $error'),
                                  ),
                                  data: (users) {
                                    if (users.isEmpty) {
                                      return const Center(child: Text('No hay cuentas creadas.'));
                                    }
                                    return ListView.builder(
                                      itemCount: users.length,
                                      itemBuilder: (context, index) {
                                        final user = users[index];
                                        return ListTile(
                                          leading: const Icon(Icons.person_outline, color: Color(0xFF232D37)),
                                          title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Puesto: ${user.role}'),
                                          trailing: user.role == 'Administrador' || user.username == 'admin'
                                              ? const Tooltip(message: 'Cuenta Raíz Protegida', child: Icon(Icons.shield, color: Colors.amber))
                                              : IconButton(
                                                  icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                                  tooltip: 'Dar de baja inmediatamente',
                                                  onPressed: () async {
                                                    await ref.read(userControllerProvider.notifier).deleteUser(user.username);
                                                  },
                                                ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
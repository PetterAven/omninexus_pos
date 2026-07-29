import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync_status.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../domain/entities/sale_detail.dart';
import '../../providers/auth_controller.dart';
import '../../providers/sales_controller.dart';
import '../../providers/user_controller.dart';
import 'sales_export_service.dart';

// --- 1. DIÁLOGO PARA CREAR USUARIOS ---

class CreateUserDialog extends ConsumerStatefulWidget {
  final String currentOperatorRole;

  const CreateUserDialog({
    super.key,
    required this.currentOperatorRole,
  });

  @override
  ConsumerState<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;

  String _selectedRole = 'Cajero';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController();
    _passCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(userControllerProvider.notifier).addUser(
            currentOperatorRole: widget.currentOperatorRole,
            username: _userCtrl.text.trim(),
            password: _passCtrl.text,
            role: _selectedRole,
          );

      if (!mounted) return;

      if (result == UserSaveResult.notAuthorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Acceso Denegado: Tu rol actual (${widget.currentOperatorRole}) no tiene autorización.',
            ),
          ),
        );
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Nueva Cuenta de Empleado',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de Usuario',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'El nombre de usuario es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'La contraseña es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Puesto',
                prefixIcon: Icon(Icons.badge),
              ),
              items: const [
                DropdownMenuItem(value: 'Cajero', child: Text('Cajero')),
                DropdownMenuItem(
                  value: 'Administrador',
                  child: Text('Administrador'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF232D37),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Crear', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

Future<void> showCreateUserDialog(
  BuildContext context,
  WidgetRef ref, {
  required String currentOperatorRole,
}) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => CreateUserDialog(
      currentOperatorRole: currentOperatorRole,
    ),
  );

  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SyncStatus.lastSyncOk
              ? 'Cuenta creada y sincronizada con Supabase.'
              : '⚠️ Cuenta creada localmente: sin conexión a Supabase.',
        ),
        backgroundColor: SyncStatus.lastSyncOk ? Colors.green : Colors.orange,
      ),
    );
  }
}

// --- 2. ELEMENTO DESPLEGABLE DE VENTAS (DESGLOSE) ---

class SaleTileItem extends StatefulWidget {
  final dynamic sale;

  const SaleTileItem({super.key, required this.sale});

  @override
  State<SaleTileItem> createState() => _SaleTileItemState();
}

class _SaleTileItemState extends State<SaleTileItem> {
  Future<List<SaleDetail>>? _detailsFuture;

  @override
  Widget build(BuildContext context) {
    final saleId = widget.sale.id;

    return ExpansionTile(
      leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
      title: Text('Ticket ID: #$saleId'),
      subtitle: Text(
        widget.sale.date.length >= 19
            ? widget.sale.date.substring(11, 19)
            : widget.sale.date,
      ),
      trailing: Text(
        '\$${widget.sale.total.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onExpansionChanged: (expanded) {
        if (expanded && _detailsFuture == null && mounted) {
          setState(() {
            _detailsFuture = SalesRepository.instance.getSaleDetails(saleId);
          });
        }
      },
      children: [
        if (_detailsFuture == null)
          const SizedBox.shrink()
        else
          FutureBuilder<List<SaleDetail>>(
            future: _detailsFuture,
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
                  child: Text(
                    'Sin desglose disponible para este ticket.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
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
                          child: Text(
                            '${item.productName} x$qty',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '\$${(price * qty).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

// --- 3. PANEL DE CONTROL Y CORTE DE CAJA ---

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
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Sincronizar',
                  onPressed: () async {
                    await ref.read(salesControllerProvider.notifier).refresh();
                    if (isAdmin) {
                      await ref.read(userControllerProvider.notifier).refresh();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
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
                        final sales = salesAsync.value ?? [];

                        return Column(
                          children: [
                            Card(
                              color: Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('VENTAS ACUMULADAS:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      '\$${granTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.file_download, size: 18),
                                label: const Text('Exportar corte de caja'),
                                onPressed: sales.isEmpty ? null : () => exportSalesReport(dialogContext, sales),
                              ),
                            ),
                            Expanded(
                              child: salesAsync.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (err, _) => Center(child: Text('Error: $err')),
                                data: (sales) {
                                  if (sales.isEmpty) {
                                    return const Center(child: Text('Sin movimientos hoy.'));
                                  }
                                  return ListView.builder(
                                    itemCount: sales.length,
                                    itemBuilder: (context, index) => SaleTileItem(sale: sales[index]),
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
                                  error: (err, _) => Center(child: Text('Error: $err')),
                                  data: (users) {
                                    if (users.isEmpty) {
                                      return const Center(child: Text('No hay cuentas creadas.'));
                                    }
                                    return ListView.builder(
                                      itemCount: users.length,
                                      itemBuilder: (context, index) {
                                        final user = users[index];
                                        return ListTile(
                                          leading: const Icon(Icons.person_outline),
                                          title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Puesto: ${user.role}'),
                                          trailing: user.role == 'Administrador' || user.username == 'admin'
                                              ? const Icon(Icons.shield, color: Colors.amber)
                                              : IconButton(
                                                  icon: const Icon(Icons.person_remove, color: Colors.redAccent),
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync_status.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../domain/entities/sale_detail.dart';
import '../../providers/auth_controller.dart';
import '../../providers/sales_controller.dart';
import '../../providers/user_controller.dart';
import 'sales_export_service.dart';

/// Enum para definir qué pestaña se debe abrir por defecto
enum SalesReportTab {
  corte,
  users,
}

// ============================================================================
// 1. MENÚ PRINCIPAL DEL PANEL DE CONTROL (MODAL DE 3 OPCIONES)
// ============================================================================

/// Función para invocar el menú desplegable del Panel de Control.
void showControlPanelMenu(BuildContext context, WidgetRef ref) {
  final userRole = ref.read(currentUserProvider)?.role ?? 'Cajero';
  final isAdmin = userRole == 'Administrador' || userRole == 'admin';

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.dashboard_customize_outlined, color: Color(0xFF232D37)),
          SizedBox(width: 10),
          Text(
            'Panel de Control',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. CORTE DE CAJA
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: Colors.green),
            title: const Text('Corte de caja'),
            onTap: () {
              Navigator.pop(dialogContext);
              showSalesReportDialog(
                context,
                ref,
                initialTab: SalesReportTab.corte,
              );
            },
          ),
          const Divider(height: 1),

          // 2. REPORTES (Exportación rápida)
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.blue),
            title: const Text('Reportes'),
            onTap: () async {
              Navigator.pop(dialogContext);
              final sales = ref.read(salesControllerProvider).value ?? [];
              if (sales.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No hay ventas registradas hoy para exportar.'),
                  ),
                );
              } else {
                await exportSalesReport(context, sales);
              }
            },
          ),

          // 3. ADMINISTRAR USUARIOS
          if (isAdmin) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.people_alt, color: Colors.orange),
              title: const Text('Administrar usuarios'),
              onTap: () {
                Navigator.pop(dialogContext);
                showSalesReportDialog(
                  context,
                  ref,
                  initialTab: SalesReportTab.users,
                );
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

// ============================================================================
// 2. DIÁLOGO PARA CREAR USUARIOS
// ============================================================================

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
              initialValue: _selectedRole,
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

// ============================================================================
// 3. ELEMENTO DESPLEGABLE DE VENTAS (DESGLOSE DE TICKET)
// ============================================================================

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

// ============================================================================
// 4. PANEL CON PESTAÑAS (CORTE DE CAJA Y GESTIÓN DE PERSONAL)
// ============================================================================

void showSalesReportDialog(
  BuildContext context,
  WidgetRef ref, {
  SalesReportTab initialTab = SalesReportTab.corte,
}) async {
  final userRole = ref.read(currentUserProvider)?.role ?? 'Cajero';
  final isAdmin = userRole == 'Administrador' || userRole == 'admin';

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (dialogContext) => _ControlPanelDialog(
      isAdmin: isAdmin,
      userRole: userRole,
      initialTab: initialTab,
    ),
  );
}

class _ControlPanelDialog extends ConsumerStatefulWidget {
  final bool isAdmin;
  final String userRole;
  final SalesReportTab initialTab;

  const _ControlPanelDialog({
    required this.isAdmin,
    required this.userRole,
    required this.initialTab,
  });

  @override
  ConsumerState<_ControlPanelDialog> createState() =>
      _ControlPanelDialogState();
}

class _ControlPanelDialogState extends ConsumerState<_ControlPanelDialog> {
  // 0 = Corte de Caja, 1 = Gestión de Personal
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    // Establece la pestaña inicial según el parámetro enviado
    _selectedTab = (widget.initialTab == SalesReportTab.users && widget.isAdmin) ? 1 : 0;
  }

  Widget _buildSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _sectionButton(
              index: 0,
              icon: Icons.point_of_sale,
              label: 'Corte de Caja',
            ),
          ),
          if (widget.isAdmin)
            Expanded(
              child: _sectionButton(
                index: 1,
                icon: Icons.groups,
                label: 'Gestión de Personal',
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab != index) setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF232D37) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdmin;

    return AlertDialog(
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
                icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                tooltip: 'Sincronizar',
                onPressed: () async {
                  await ref.read(salesControllerProvider.notifier).refresh();
                  if (isAdmin) {
                    await ref.read(userControllerProvider.notifier).refresh();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
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
            if (isAdmin) _buildSectionSwitcher(),
            if (isAdmin) const SizedBox(height: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: (!isAdmin || _selectedTab == 0)
                    ? Consumer(
                        key: const ValueKey('corte_de_caja'),
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
                                  onPressed: sales.isEmpty ? null : () => exportSalesReport(context, sales),
                                ),
                              ),
                               Expanded(
                                 child: salesAsync.when(
                                   loading: () => const SalesSkeletonLoader(),
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
                      )
                    : Consumer(
                        key: const ValueKey('gestion_personal'),
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
                                    context,
                                    ref,
                                    currentOperatorRole: widget.userRole,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: usersAsync.when(
                                    loading: () => const SalesSkeletonLoader(),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SalesSkeletonLoader extends StatefulWidget {
  const SalesSkeletonLoader({super.key});

  @override
  State<SalesSkeletonLoader> createState() => _SalesSkeletonLoaderState();
}

class _SalesSkeletonLoaderState extends State<SalesSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.3 + (_controller.value * 0.4);
        return ListView.builder(
          itemCount: 4,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: opacity * 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
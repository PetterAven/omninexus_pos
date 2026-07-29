import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/product.dart';
import '../../providers/cart_controller.dart';

const List<String> kRechargeCompanies = ['Telcel', 'Movistar', 'AT&T', 'Unefon'];
const List<double> kRechargeQuickAmounts = [20, 30, 50, 100, 150, 200, 300, 500];

void showRechargeDialog(BuildContext context, WidgetRef ref) {
  String selectedCompany = kRechargeCompanies.first;
  final phoneController = TextEditingController();
  final amountController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text('Recarga de Tiempo Aire', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCompany,
                decoration: const InputDecoration(labelText: 'Compañía'),
                items: kRechargeCompanies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selectedCompany = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Número a 10 dígitos',
                  counterText: '',
                  prefixIcon: Icon(Icons.dialpad),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Monto', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kRechargeQuickAmounts.map((amount) {
                  final selected = amountController.text == amount.toStringAsFixed(0);
                  return ChoiceChip(
                    label: Text('\$${amount.toStringAsFixed(0)}'),
                    selected: selected,
                    onSelected: (_) => setDialogState(() {
                      amountController.text = amount.toStringAsFixed(0);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto exacto',
                  prefixText: '\$ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              final phone = phoneController.text.trim();
              final amount = double.tryParse(amountController.text.trim());

              if (phone.length != 10 || int.tryParse(phone) == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('El número debe tener exactamente 10 dígitos.'), backgroundColor: Colors.red),
                );
                return;
              }
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Ingresa un monto válido.'), backgroundColor: Colors.red),
                );
                return;
              }

              // Producto sintético: no se guarda en el catálogo, solo viaja
              // por el carrito para reusar todo el flujo de cobro/ticket
              // que ya existe. El código es único por timestamp para no
              // chocar con otra recarga en el mismo turno.
              final rechargeProduct = Product(
                code: 'RECARGA-${DateTime.now().millisecondsSinceEpoch}',
                name: 'Recarga $selectedCompany · $phone',
                price: amount,
                stock: 1,
                isWeighted: false,
                unit: 'Servicio',
              );

              ref.read(cartControllerProvider.notifier).addProduct(rechargeProduct, quantity: 1);
              Navigator.pop(dialogContext);
            },
            child: const Text('Agregar al Carrito'),
          ),
        ],
      ),
    ),
  );
}
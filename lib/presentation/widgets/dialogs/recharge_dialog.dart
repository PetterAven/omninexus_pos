import 'package:flutter/material.dart';

class RechargeDialog extends StatefulWidget {
  const RechargeDialog({super.key});

  @override
  State<RechargeDialog> createState() => _RechargeDialogState();
}

class _RechargeDialogState extends State<RechargeDialog> {
  final _phoneController = TextEditingController();
  final _confirmPhoneController = TextEditingController();

  String _selectedCarrier = 'Telcel';
  double _selectedAmount = 100.0;

  final List<String> _carriers = ['Telcel', 'Movistar', 'AT&T', 'Bait', 'Unefon'];
  final List<double> _amounts = [20.0, 30.0, 50.0, 100.0, 150.0, 200.0, 500.0];

  @override
  void dispose() {
    _phoneController.dispose();
    _confirmPhoneController.dispose();
    super.dispose();
  }

  void _processRecharge() {
    final phone = _phoneController.text.trim();
    final confirmPhone = _confirmPhoneController.text.trim();

    if (phone.length != 10) {
      _showError('El número debe tener exactamente 10 dígitos.');
      return;
    }

    if (phone != confirmPhone) {
      _showError('Los números ingresados no coinciden.');
      return;
    }

    // Aquí irá la conexión a la API en producción
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('Recarga de \$$_selectedAmount a $phone ($_selectedCarrier) procesada con éxito.'),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.phone_android, color: Colors.blue),
          SizedBox(width: 8),
          Text('Recargas y Paquetes'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de Compañía
              DropdownButtonFormField<String>(
                value: _selectedCarrier,
                decoration: const InputDecoration(
                  labelText: 'Compañía Telefónica',
                  border: OutlineInputBorder(),
                ),
                items: _carriers.map((carrier) {
                  return DropdownMenuItem(value: carrier, child: Text(carrier));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCarrier = val);
                },
              ),
              const SizedBox(height: 16),

              // Número Telefónico
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Número telefónico (10 dígitos)',
                  prefixIcon: Icon(Icons.dialpad),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              // Confirmación de Número (Seguridad para evitar errores)
              TextField(
                controller: _confirmPhoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Confirmar número telefónico',
                  prefixIcon: Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Monto / Paquete:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Enrejado de Montos
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _amounts.map((amount) {
                  final isSelected = _selectedAmount == amount;
                  return ChoiceChip(
                    label: Text('\$${amount.toInt()}'),
                    selected: isSelected,
                    selectedColor: Colors.blue.shade100,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedAmount = amount);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _processRecharge,
          child: const Text('Vender Recarga', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Función auxiliar para invocar el diálogo fácilmente
void showRechargeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const RechargeDialog(),
  );
}
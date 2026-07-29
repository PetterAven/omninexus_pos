import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RechargeDialog extends StatefulWidget {
  final Function(String carrier, String phone, double amount) onProcessRecharge;

  const RechargeDialog({
    super.key,
    required this.onProcessRecharge,
  });

  @override
  State<RechargeDialog> createState() => _RechargeDialogState();
}

class _RechargeDialogState extends State<RechargeDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _confirmPhoneController = TextEditingController();

  String? _selectedCarrier;
  double? _selectedAmount;

  final List<String> _carriers = ['Telcel', 'Movistar', 'AT&T', 'Unefon', 'Bait'];
  final List<double> _amounts = [20, 30, 50, 100, 150, 200, 300, 500];

  @override
  void dispose() {
    _phoneController.dispose();
    _confirmPhoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = _phoneController.text.trim();
    final confirmPhone = _confirmPhoneController.text.trim();

    if (_selectedCarrier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una compañía.')),
      );
      return;
    }

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número debe contener exactamente 10 dígitos.')),
      );
      return;
    }

    if (phone != confirmPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los números ingresados no coinciden.')),
      );
      return;
    }

    if (_selectedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona el monto de la recarga.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    widget.onProcessRecharge(_selectedCarrier!, phone, _selectedAmount!);
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text('Recarga de \$$_selectedAmount para $phone ($_selectedCarrier) procesada.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.phone_android, color: Colors.blue),
          SizedBox(width: 8),
          Text('Recarga Telefónica'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compañía:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _carriers.map((carrier) {
                final isSelected = _selectedCarrier == carrier;
                return ChoiceChip(
                  label: Text(carrier),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCarrier = selected ? carrier : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Número Telefónico (10 dígitos)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirmar Número',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Monto:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _amounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return ChoiceChip(
                  label: Text('\$${amount.toInt()}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedAmount = selected ? amount : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Realizar Recarga'),
        ),
      ],
    );
  }
}
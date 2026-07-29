import 'package:flutter/material.dart';
import '../../services/payment_terminal_service.dart';

class PaymentTerminalSettingsScreen extends StatefulWidget {
  const PaymentTerminalSettingsScreen({super.key});

  @override
  State<PaymentTerminalSettingsScreen> createState() => _PaymentTerminalSettingsScreenState();
}

class _PaymentTerminalSettingsScreenState extends State<PaymentTerminalSettingsScreen> {
  PaymentProvider? _selectedProvider;
  final _apiKeyController = TextEditingController();
  final _terminalIdController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final provider = await PaymentTerminalService.instance.getActiveProvider();
    if (provider != null) {
      final creds = await PaymentTerminalService.instance.getCredentials(provider);
      _apiKeyController.text = creds.apiKey;
      _terminalIdController.text = creds.terminalId;
    }
    if (!mounted) return;
    setState(() {
      _selectedProvider = provider;
      _loading = false;
    });
  }

  Future<void> _onProviderChanged(PaymentProvider? provider) async {
    setState(() => _selectedProvider = provider);
    if (provider == null) return;
    final creds = await PaymentTerminalService.instance.getCredentials(provider);
    _apiKeyController.text = creds.apiKey;
    _terminalIdController.text = creds.terminalId;
  }

  Future<void> _save() async {
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una terminal antes de guardar.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    await PaymentTerminalService.instance.setActiveProvider(_selectedProvider);
    await PaymentTerminalService.instance.saveCredentials(
      _selectedProvider!,
      PaymentTerminalCredentials(
        apiKey: _apiKeyController.text.trim(),
        terminalId: _terminalIdController.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Configuración de terminal guardada.'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Terminal de Cobro')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona la terminal física con la que vas a cobrar tarjetas y guarda sus credenciales. Por ahora esto es un cascarón: el cobro se simula hasta que conectemos el SDK real de cada proveedor.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<PaymentProvider>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(labelText: 'Terminal / Proveedor', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: PaymentProvider.clip, child: Text('Clip')),
                DropdownMenuItem(value: PaymentProvider.mercadoPago, child: Text('Mercado Pago Point')),
              ],
              onChanged: _onProviderChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API Key / Access Token', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _terminalIdController,
              decoration: const InputDecoration(labelText: 'ID de Terminal / Device ID', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF232D37),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
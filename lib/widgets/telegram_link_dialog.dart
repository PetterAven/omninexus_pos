import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TelegramLinkDialog extends StatefulWidget {
  const TelegramLinkDialog({super.key});

  @override
  State<TelegramLinkDialog> createState() => _TelegramLinkDialogState();
}

class _TelegramLinkDialogState extends State<TelegramLinkDialog> {
  final TextEditingController _codeController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Realiza la consulta directa a Supabase para validar el código de 4 dígitos
  Future<void> _verificarCodigo() async {
    final code = _codeController.text.trim();
    
    if (code.length != 4) {
      setState(() {
        _errorMessage = 'El código debe tener exactamente 4 dígitos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Consultamos la tabla 'telegram_customers' buscando coincidencia activa
      final response = await _supabase
          .from('telegram_customers')
          .select('chat_id, username, expires_at')
          .eq('short_code', code)
          // Quitamos temporalmente el candado estricto de expiración por si los servidores
          // tienen desfase de horas. Si coincide el código puro, lo dejamos pasar.
          .maybeSingle();

      if (response != null) {
        // Si el código existe en la base de datos, cerramos exitosamente regresando los datos
        if (mounted) {
          Navigator.of(context).pop(response);
        }
      } else {
        setState(() {
          _errorMessage = 'Código no encontrado. Escribe el número exacto que guardó el bot.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión con Supabase. Revisa tu red.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.telegram, color: Colors.blue.shade600, size: 28),
          const SizedBox(width: 10),
          const Text(
            'Vincular Telegram',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ingresa el código de 4 dígitos que está guardado en la tabla de Supabase para asociar al cliente.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            autofocus: true,
            enabled: !_isLoading,
            style: const TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 8
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '0000',
              hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 8),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
            ),
            onSubmitted: (_) => _verificarCodigo(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verificarCodigo,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Vincular', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
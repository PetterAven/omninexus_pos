import 'package:flutter/material.dart';
import '../../../data/repositories/sync_repository.dart';

/// Diálogo para ver/editar el código de sincronización que empareja el
/// escáner del teléfono con la Terminal de Ventas de la PC.
///
/// Extraído de `SalesTerminalScreen._showSyncCodeDialog`. Recibe
/// [onCodeUpdated] para que quien lo invoque pueda reabrir su propia
/// escucha de `SyncRepository.listenToRemoteCart` con el nuevo código,
/// ya que esa suscripción vive en el estado del carrito, no aquí.
Future<void> showSyncCodeDialog(
  BuildContext context, {
  required VoidCallback onCodeUpdated,
}) async {
  final currentCode = await SyncRepository.instance.getSyncCode();
  if (!context.mounted) return;

  final codeController = TextEditingController(text: currentCode);

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.sync_alt, color: Color(0xFF232D37)),
          SizedBox(width: 10),
          Text('Código de Sincronización', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'El escáner del teléfono solo se conecta con las PCs que tengan ESTE MISMO código. '
            'Si tienes una sola caja, no necesitas cambiarlo. Si tienes varias cajas, dale un código distinto a cada una.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código (ej. CAJA1)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
          onPressed: () async {
            final newCode = codeController.text.trim();
            if (newCode.isEmpty) return;
            await SyncRepository.instance.setSyncCode(newCode);
            onCodeUpdated();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Código actualizado a "$newCode". Ponlo igual en el teléfono.')),
              );
            }
          },
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
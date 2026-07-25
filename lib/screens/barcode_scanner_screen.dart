import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla de escaneo de código de barras con la cámara.
/// Se usa desde la Terminal de Ventas (botón junto al buscador) y desde
/// Inventario (botón junto al campo "Código de Barras" al dar de alta un
/// producto). Al detectar un código, regresa el valor con Navigator.pop.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false; // evita procesar el mismo código varias veces seguidas

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    _handled = true;
    Navigator.pop(context, code.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código de barras'),
        backgroundColor: const Color(0xFF232D37),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Cambiar cámara',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Marco visual para guiar al usuario a centrar el código
          Center(
            child: Container(
              width: 270,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Text(
              'Apunta la cámara al código de barras del producto',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Colors.black.withOpacity(0.8))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
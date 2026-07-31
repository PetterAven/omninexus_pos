import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla de escaneo de código de barras con la cámara.
/// Se usa desde la Terminal de Ventas (botón junto al buscador) y desde
/// Inventario (botón junto al campo "Código de Barras" al dar de alta un
/// producto). Al detectar un código, regresa el valor con Navigator.pop.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  // CORREGIDO: antes el controller no tenía ninguna configuración, así que
  // mobile_scanner analizaba TODA la imagen de la cámara (incluyendo zonas
  // fuera de foco) sin límite de formatos ni de velocidad, y eso es lo que
  // se sentía como "falla mucho". Ahora se limita a los formatos de barras
  // que realmente usa un POS y se activa el modo "sin duplicados" para que
  // no se dispare el mismo código 10 veces por segundo.
  //
  // MEJORADO: la mayoría de fallas de lectura NO son por el tamaño del
  // recuadro sino por resolución de cámara baja (la imagen llega borrosa a
  // ML Kit) y por no acercarse automáticamente a códigos chicos o lejanos.
  // `cameraResolution` pide una resolución alta a la cámara (no siempre se
  // obtiene exacta, pero sube el techo) y `autoZoom` hace zoom digital solo
  // cuando detecta un código muy pequeño dentro del cuadro, sin que el
  // cajero tenga que acercar el celular a mano.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
    facing: CameraFacing.back,
    torchEnabled: false,
    cameraResolution: const Size(1920, 1080),
    autoZoom: true,
  );

  // NUEVO: animación de la línea láser roja, para que el cajero vea
  // exactamente el "barrido" de lectura, como en los lectores dedicados.
  late final AnimationController _laserController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  bool _handled = false; // evita procesar el mismo código varias veces seguidas
  bool _torchOn = false;

  // CORREGIDO/NUEVO: el marco verde antes era decorativo (270x170 fijo) y no
  // coincidía con el área que realmente se escaneaba, lo que hacía que la
  // lectura fuera lenta/imprecisa y que el recuadro se viera "chico" en
  // pantallas grandes. Ahora se calcula según el tamaño real de la pantalla
  // y se lo pasamos a MobileScanner como `scanWindow`, así lo que el
  // cajero ve es EXACTAMENTE el área que se está analizando.
  Rect _scanWindowFor(Size screenSize) {
    final width = screenSize.width * 0.85;
    final height = screenSize.height * 0.28;
    return Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: width,
      height: height,
    );
  }

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
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanWindow = _scanWindowFor(screenSize);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código de barras'),
        backgroundColor: const Color(0xFF232D37),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Linterna',
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
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
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindow,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              // CORREGIDO/NUEVO: antes, si la cámara no arrancaba (permiso
              // negado, cámara ocupada, etc.) la pantalla se quedaba negra
              // sin ninguna explicación y parecía que "el escáner falló".
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No se pudo abrir la cámara.\nRevisa que la app tenga permiso de cámara.\n(${error.errorCode.name})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Overlay oscuro fuera del área de escaneo, para que sea obvio
          // dónde sí se está leyendo.
          IgnorePointer(
            child: ColoredBox(
              color: Colors.transparent,
              child: CustomPaint(
                size: screenSize,
                painter: _ScannerOverlayPainter(scanWindow),
              ),
            ),
          ),
          // NUEVO: línea láser roja que sube y baja dentro del recuadro,
          // como un lector láser de verdad. Es puramente visual (la lectura
          // real la sigue haciendo ML Kit sobre el scanWindow completo), pero
          // ayuda a que el cajero centre y sostenga el código quieto en el
          // punto correcto, que es la causa más común de "no lo detecta".
          AnimatedBuilder(
            animation: _laserController,
            builder: (context, _) {
              final y = scanWindow.top +
                  8 +
                  (scanWindow.height - 16) * _laserController.value;
              return Positioned(
                left: scanWindow.left + 10,
                right: screenSize.width - scanWindow.right + 10,
                top: y,
                child: IgnorePointer(
                  child: Container(
                    height: 2.4,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.85),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        ),
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Centra el código de barras dentro del recuadro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.8))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja el marco verde exactamente sobre el `scanWindow` real, más un
/// oscurecido ligero alrededor para guiar la vista del cajero.
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  _ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)));
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => oldDelegate.scanWindow != scanWindow;
}
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

/// Prywatny, stanowy widżet do zarządzania ekranem skanera i jego kontrolerem.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen();

  @override
  State<QrScannerScreen> createState() => QrScannerScreenState();
}

class QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _isPopping = false; // Flaga zapobiegająca wielokrotnemu wywołaniu pop

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skieruj aparat na kod QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AiBarcodeScanner(
        controller: _scannerController,
        onDetect: (BarcodeCapture capture) {
          // Sprawdzamy, czy już nie jesteśmy w trakcie zamykania ekranu
          if (_isPopping || !mounted) return;

          final String? result = capture.barcodes.first.rawValue;
          if (result != null) {
            // 1. Ustawiamy flagę, aby zablokować kolejne detekcje
            _isPopping = true;
            // 2. Natychmiast zatrzymujemy kamerę dla szybkiej informacji zwrotnej
            _scannerController.stop();
            // 3. Bezpiecznie zamykamy ekran po zakończeniu bieżącej klatki
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(result);
              }
            });
          }
        },
      ),
    );
  }
}
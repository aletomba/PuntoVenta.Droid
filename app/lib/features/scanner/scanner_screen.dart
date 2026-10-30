import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_formats.dart';

/// Spike de escaneo ([B] 1.3).
///
/// Pantalla autocontenida que sirve para validar `mobile_scanner` en un
/// dispositivo real: formatos restringidos, linterna, manejo del permiso de
/// cámara e ingreso manual del código.
///
/// Devuelve el código confirmado mediante `Navigator.pop(context, code)`, o lo
/// entrega a [onCodeDetected] cuando se provee un callback.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.onCodeDetected});

  /// Si se provee, se invoca en lugar de cerrar la pantalla.
  final ValueChanged<String>? onCodeDetected;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: supportedBarcodeFormats,
    detectionSpeed: DetectionSpeed.normal,
    autoStart: true,
  );

  String? _detectedCode;
  bool _isResolving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_isResolving || _detectedCode != null) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final code = normalizeScannedCode(barcode.rawValue);
      if (code == null) {
        continue;
      }
      setState(() {
        _detectedCode = code;
        _isResolving = true;
      });
      _controller.stop();
      return;
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _detectedCode = null;
      _isResolving = false;
    });
    await _controller.start();
  }

  void _confirmCode(String code) {
    final callback = widget.onCodeDetected;
    if (callback != null) {
      callback(code);
      return;
    }
    Navigator.of(context).pop(code);
  }

  Future<void> _openManualEntry() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _ManualCodeDialog(),
    );
    if (code == null || !mounted) {
      return;
    }
    setState(() {
      _detectedCode = code;
      _isResolving = true;
    });
    await _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                final isOn = state.torchState == TorchState.on;
                return Icon(isOn ? Icons.flash_on : Icons.flash_off);
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
            errorBuilder: (context, error) => _ScannerErrorView(
              error: error,
              onRetry: () => _controller.start(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPanel(
              detectedCode: _detectedCode,
              onConfirm: _confirmCode,
              onScanAgain: _scanAgain,
              onManualEntry: _openManualEntry,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.detectedCode,
    required this.onConfirm,
    required this.onScanAgain,
    required this.onManualEntry,
  });

  final String? detectedCode;
  final ValueChanged<String> onConfirm;
  final VoidCallback onScanAgain;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final code = detectedCode;
    return SafeArea(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (code == null) ...[
              const Text(
                'Apuntá la cámara al código de barras',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Ingresar manualmente'),
              ),
            ] else ...[
              const Text('Código detectado:', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              SelectableText(
                code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onConfirm(code),
                child: const Text('Usar este código'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onScanAgain, child: const Text('Escanear otro')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = isPermissionDenied
        ? 'La app necesita permiso de cámara para escanear códigos.'
        : 'No se pudo iniciar la cámara: ${error.errorCode.name}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _ManualCodeDialog extends StatefulWidget {
  const _ManualCodeDialog();

  @override
  State<_ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<_ManualCodeDialog> {
  final TextEditingController _textController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = normalizeScannedCode(_textController.text);
    if (code == null) {
      setState(() => _errorText = 'Ingresá un código válido');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ingresar código'),
      content: TextField(
        controller: _textController,
        autofocus: true,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Código de barras',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aceptar')),
      ],
    );
  }
}

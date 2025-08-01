import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? cameraController;
  bool _screenOpened = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _screenOpened = false;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameraController = MobileScannerController();
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Give time for initialization

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = _getErrorMessage(e);
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is MissingPluginException) {
      return 'Camera plugin not available. Please restart the app or enter barcode manually.';
    } else if (error.toString().contains('permission')) {
      return 'Camera permission denied. Please enable camera access in settings.';
    } else if (error.toString().contains('camera')) {
      return 'Camera not available on this device. Please enter barcode manually.';
    } else {
      return 'Camera error: ${error.toString()}';
    }
  }

  @override
  void dispose() {
    try {
      cameraController?.dispose();
    } catch (e) {
      // Ignore disposal errors
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _hasError || _isInitializing || cameraController == null
            ? []
            : [
                IconButton(
                  onPressed: () {
                    try {
                      cameraController?.toggleTorch();
                    } catch (e) {
                      // Ignore torch errors
                    }
                  },
                  icon: ValueListenableBuilder(
                    valueListenable: cameraController!.torchState,
                    builder: (context, state, child) {
                      switch (state) {
                        case TorchState.off:
                          return const Icon(
                            Icons.flash_off,
                            color: Colors.grey,
                          );
                        case TorchState.on:
                          return const Icon(
                            Icons.flash_on,
                            color: Colors.yellow,
                          );
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    try {
                      cameraController?.switchCamera();
                    } catch (e) {
                      // Ignore camera switch errors
                    }
                  },
                  icon: ValueListenableBuilder(
                    valueListenable: cameraController!.cameraFacingState,
                    builder: (context, state, child) {
                      switch (state) {
                        case CameraFacing.front:
                          return const Icon(Icons.camera_front);
                        case CameraFacing.back:
                          return const Icon(Icons.camera_rear);
                      }
                    },
                  ),
                ),
              ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return _buildLoadingView();
    } else if (_hasError) {
      return _buildErrorView();
    } else if (cameraController != null) {
      return _buildCameraView();
    } else {
      return _buildErrorView();
    }
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Camera Not Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Unable to access camera for barcode scanning.',
              style: TextStyle(color: Colors.grey[300], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Enter Manually'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retryCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera View
        MobileScanner(
          controller: cameraController!,
          onDetect: _foundBarcode,
          errorBuilder: (context, error, child) {
            return _buildErrorView();
          },
        ),

        // Overlay with scanning area
        Container(
          decoration: ShapeDecoration(
            shape: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 250,
            ),
          ),
        ),

        // Instructions
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Position the barcode within the frame',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.keyboard, size: 16),
                      label: const Text('Manual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the barcode number manually:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
                hintText: 'Enter barcode number',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, barcode); // Return barcode
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _retryCamera() {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = '';
    });
    _initializeCamera();
  }

  void _foundBarcode(BarcodeCapture barcodeCapture) {
    if (!_screenOpened) {
      final List<Barcode> barcodes = barcodeCapture.barcodes;
      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first.rawValue;
        if (barcode != null && barcode.isNotEmpty) {
          _screenOpened = true;
          Navigator.pop(context, barcode);
        }
      }
    }
  }
}

// Custom overlay shape for the scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
  }) : cutOutSize = cutOutSize ?? 250;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final cutOutSized = cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - cutOutSized / 2 + borderOffset,
      rect.top + height / 2 - cutOutSized / 2 + borderOffset,
      cutOutSized - borderOffset * 2,
      cutOutSized - borderOffset * 2,
    );

    // Draw background
    canvas.saveLayer(rect, backgroundPaint);
    canvas.drawRect(rect, backgroundPaint);

    // Draw cut out
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      boxPaint,
    );

    canvas.restore();

    // Draw border
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      borderPaint,
    );
    final lineWidth = borderWidth;
    final cornerRadius = borderRadius;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left - lineWidth, cutOutRect.top + cornerRadius)
        ..lineTo(cutOutRect.left - lineWidth, cutOutRect.top - lineWidth)
        ..lineTo(cutOutRect.left + cornerRadius, cutOutRect.top - lineWidth),
      Paint()
        ..color = borderColor
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - cornerRadius, cutOutRect.top - lineWidth)
        ..lineTo(cutOutRect.right + lineWidth, cutOutRect.top - lineWidth)
        ..lineTo(cutOutRect.right + lineWidth, cutOutRect.top + cornerRadius),
      Paint()
        ..color = borderColor
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left - lineWidth, cutOutRect.bottom - cornerRadius)
        ..lineTo(cutOutRect.left - lineWidth, cutOutRect.bottom + lineWidth)
        ..lineTo(cutOutRect.left + cornerRadius, cutOutRect.bottom + lineWidth),
      Paint()
        ..color = borderColor
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - cornerRadius, cutOutRect.bottom + lineWidth)
        ..lineTo(cutOutRect.right + lineWidth, cutOutRect.bottom + lineWidth)
        ..lineTo(
          cutOutRect.right + lineWidth,
          cutOutRect.bottom - cornerRadius,
        ),
      Paint()
        ..color = borderColor
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }

  double min(double a, double b) => a < b ? a : b;
}

import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/scan_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/result_card.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _camera = CameraController(_cameras[0], ResolutionPreset.high);
    await _camera!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _onScanPressed() async {
    final scanService = context.read<ScanService>();
    final locationService = context.read<LocationService>();

    if (!_cameraReady || scanService.isScanning) return;

    // Capture frame (used by TFLite inference when model is wired in)
    unawaited(_camera!.takePicture()); // capture but don't await in stub

    // 📥 After exporting the model, run TFLite inference here.
    // Uncomment and adjust the code below once kabadiai.tflite is in assets/model/:
    // -------------------------------------------------
    // final interpreter = await Interpreter.fromAsset('assets/model/kabadiai.tflite');
    // final result = await runInference(interpreter, image.path);
    // final material   = result['class'];   // e.g. 'plastic'
    // final confidence = result['confidence']; // e.g. 0.87
    // -------------------------------------------------
    // For now, we keep the demo stub.
    const material   = 'plastic';   // demo stub
    const confidence = 0.87;

    await scanService.submitScan(
      material:   material,
      confidence: confidence,
      lat:        locationService.lat,
      lng:        locationService.lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('♻️  ', style: TextStyle(fontSize: 20)),
            Text('KabadiAI'),
          ],
        ),
        actions: [
          Consumer<ScanService>(
            builder: (_, svc, __) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.eco, size: 16, color: Colors.black),
                label: Text(
                  '${svc.greenPoints} pts',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: KabadiTheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          if (_cameraReady)
            Positioned.fill(child: CameraPreview(_camera!))
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: KabadiTheme.primary),
                  SizedBox(height: 12),
                  Text('Starting camera…', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),

          // ── Scan frame overlay ──────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _ScanFramePainter()),
          ),

          // ── Scan button ─────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: Consumer<ScanService>(
                builder: (_, svc, __) => GestureDetector(
                  onTap: _onScanPressed,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width:  svc.isScanning ? 72 : 80,
                    height: svc.isScanning ? 72 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: KabadiTheme.primary.withValues(alpha: svc.isScanning ? 0.7 : 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: KabadiTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: svc.isScanning
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.document_scanner, color: Colors.black, size: 36),
                  ),
                ),
              ),
            ),
          ),

          // ── Instruction chip ────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: Text(
                'Point at waste item and tap to scan',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
            ),
          ),

          // ── Result card overlay ─────────────────────────────────────────
          Consumer<ScanService>(
            builder: (_, svc, __) {
              if (svc.lastResult == null) return const SizedBox.shrink();
              return Positioned(
                left: 0, right: 0, bottom: 0,
                child: ResultCard(
                  result: svc.lastResult!,
                  onDismiss: svc.clearResult,
                ).animate().slideY(
                  begin: 1, end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOutCubic,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Scan frame corner painter ─────────────────────────────────────────────────
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color  = KabadiTheme.primary
      ..strokeWidth = 3
      ..style  = PaintingStyle.stroke;

    const len   = 36.0;
    const inset = 60.0;

    final corners = [
      // top-left
      [Offset(inset, inset + len), Offset(inset, inset), Offset(inset + len, inset)],
      // top-right
      [Offset(size.width - inset - len, inset), Offset(size.width - inset, inset), Offset(size.width - inset, inset + len)],
      // bottom-left
      [Offset(inset, size.height - inset - len), Offset(inset, size.height - inset), Offset(inset + len, size.height - inset)],
      // bottom-right
      [Offset(size.width - inset - len, size.height - inset), Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - len)],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

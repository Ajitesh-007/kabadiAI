import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Try to import Firestore — if it fails at runtime, we fall back gracefully.
// ignore_for_file: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';

const String _backendBase = 'http://localhost:8000';
// On Android emulator use: 'http://10.0.2.2:8000'

class ScanResult {
  final String material;
  final double confidence;
  final int pricePerKg;
  final bool hazardous;
  final Map<String, dynamic>? nearestDropoff;
  final String? hazardWarning;
  final DateTime timestamp;

  ScanResult({
    required this.material,
    required this.confidence,
    required this.pricePerKg,
    required this.hazardous,
    this.nearestDropoff,
    this.hazardWarning,
    required this.timestamp,
  });
}

class ScanService extends ChangeNotifier {
  ScanResult? lastResult;
  bool        isScanning  = false;
  int         greenPoints = 0;
  String?     errorMessage;
  bool        backendOnline = false;

  /// Called from the scan screen after capturing a frame.
  /// material: one of [glass, metal_scrap, paper, cardboard, plastic, ewaste]
  /// confidence: 0.0–1.0
  Future<void> submitScan({
    required String material,
    required double confidence,
    double lat = 28.6139,
    double lng  = 77.2090,
    String zone = 'Mobile Scan',
  }) async {
    isScanning   = true;
    errorMessage = null;
    notifyListeners();

    // ── Try real backend first ────────────────────────────────────────────────
    try {
      final response = await http.post(
        Uri.parse('$_backendBase/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'material':   material,
          'confidence': confidence,
          'zone':       zone,
          'lat':        lat,
          'lng':        lng,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        lastResult = ScanResult(
          material:       data['material'] as String,
          confidence:     confidence,
          pricePerKg:     (data['price_per_kg'] as num).toInt(),
          hazardous:      data['hazardous'] as bool,
          nearestDropoff: data['nearest_dropoff'] as Map<String, dynamic>?,
          hazardWarning:  data['hazard_warning']  as String?,
          timestamp:      DateTime.now(),
        );
        backendOnline = true;

        // Award Green Points and try to persist to Firestore
        final points = lastResult!.hazardous ? 10 : 5;
        greenPoints += points;
        _tryUpdateFirestore(points, material);

        isScanning = false;
        notifyListeners();
        return;
      }
    } catch (_) {
      // Backend offline — fall through to local demo mode below
      backendOnline = false;
    }

    // ── Offline / demo mode ───────────────────────────────────────────────────
    // Full result from local price table — no network needed for the demo.
    final price   = _localPriceTable[material] ?? 0;
    final isHazard = material == 'ewaste';

    lastResult = ScanResult(
      material:   material,
      confidence: confidence,
      pricePerKg: price,
      hazardous:  isHazard,
      nearestDropoff: isHazard ? _demoDropoff : null,
      hazardWarning:  isHazard
          ? 'Do NOT mix with regular scrap. Route to certified e-waste recycler.'
          : null,
      timestamp:  DateTime.now(),
    );
    greenPoints  += isHazard ? 10 : 5;
    errorMessage  = '⚡ Demo mode — backend offline';

    isScanning = false;
    notifyListeners();
  }

  /// Try to write Green Points to Firestore — silently swallow any error.
  Future<void> _tryUpdateFirestore(int delta, String material) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc('demo_user');
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap    = await tx.get(ref);
        final current = snap.exists ? (snap.data()?['green_points'] ?? 0) as int : 0;
        tx.set(ref, {
          'green_points':  current + delta,
          'last_scan':     DateTime.now().toIso8601String(),
          'last_material': material,
          'total_scans':   FieldValue.increment(1),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Non-critical — points shown locally regardless
    }
  }

  void clearResult() {
    lastResult   = null;
    errorMessage = null;
    notifyListeners();
  }

  // ── Local price table (fallback when backend is offline) ──────────────────
  static const _localPriceTable = {
    'glass':       2,
    'metal_scrap': 45,
    'paper':       10,
    'cardboard':   8,
    'plastic':     12,
    'ewaste':      0,
  };

  // Demo drop-off shown when backend is offline and ewaste is detected
  static const _demoDropoff = {
    'name':        'CPCB Authorised Drop-off',
    'address':     'Bhikaji Cama Place, New Delhi',
    'phone':       '011-2307-0200',
    'distance_km': 4.8,
    'lat':         28.5681,
    'lng':         77.1882,
  };
}

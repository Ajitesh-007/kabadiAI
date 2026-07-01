import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/scan_service.dart';
import '../theme.dart';

/// Emoji and color per material class
const _materialMeta = {
  'plastic':    {'emoji': '🧴', 'label': 'Plastic',     'color': 0xFF2A78D6},
  'glass':      {'emoji': '🍶', 'label': 'Glass',        'color': 0xFF1BAF7A},
  'paper':      {'emoji': '📰', 'label': 'Paper',        'color': 0xFF6B46C1},
  'cardboard':  {'emoji': '📦', 'label': 'Cardboard',    'color': 0xFF8B6914},
  'metal_scrap':{'emoji': '🔩', 'label': 'Metal Scrap',  'color': 0xFFEDA100},
  'ewaste':     {'emoji': '💻', 'label': 'E-waste',      'color': 0xFFE34948},
};

class ResultCard extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onDismiss;

  const ResultCard({super.key, required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final meta   = _materialMeta[result.material] ?? {'emoji': '♻️', 'label': result.material, 'color': 0xFF00C897};
    final color  = Color(meta['color'] as int);
    final isHazard = result.hazardous;

    return Container(
      decoration: BoxDecoration(
        color: KabadiTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Material header ──────────────────────────────────────────────
          Row(
            children: [
              Text(meta['emoji'] as String, style: const TextStyle(fontSize: 42)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta['label'] as String,
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Hazard banner or price info ──────────────────────────────────
          if (isHazard) ...[
            _HazardBanner(dropoff: result.nearestDropoff),
          ] else ...[
            _PriceInfo(pricePerKg: result.pricePerKg),
          ],

          const SizedBox(height: 16),

          // ── Green Points award ───────────────────────────────────────────
          _GreenPointsChip(points: isHazard ? 10 : 5)
              .animate()
              .scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
        ],
      ),
    );
  }
}

class _PriceInfo extends StatelessWidget {
  final int pricePerKg;
  const _PriceInfo({required this.pricePerKg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: KabadiTheme.primary, size: 28),
              const SizedBox(width: 8),
              Text(
                '$pricePerKg / kg',
                style: const TextStyle(
                  color: KabadiTheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Fair market rate · Weight confirmed by\nkabadiwalla\'s scale at pickup',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _HazardBanner extends StatelessWidget {
  final Map<String, dynamic>? dropoff;
  const _HazardBanner({this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KabadiTheme.hazard.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KabadiTheme.hazard.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: KabadiTheme.hazard, size: 22),
              SizedBox(width: 8),
              Text(
                'HAZARDOUS — E-waste',
                style: TextStyle(
                  color: KabadiTheme.hazard,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Contains heavy metals / Li-ion. Do NOT put in regular scrap bin.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          if (dropoff != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${dropoff!['name']} · ${dropoff!['distance_km']} km away',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dropoff!['address'] ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Directions button — opens Google Maps via browser on Linux
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: KabadiTheme.hazard,
                side: const BorderSide(color: KabadiTheme.hazard),
              ),
              icon: const Icon(Icons.directions, size: 16),
              label: const Text('Copy drop-off address'),
              onPressed: () {
                final name = dropoff!['name'] ?? 'Drop-off';
                final addr = dropoff!['address'] ?? '';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 $name\n$addr'),
                    backgroundColor: KabadiTheme.surface,
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GreenPointsChip extends StatelessWidget {
  final int points;
  const _GreenPointsChip({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KabadiTheme.primary.withValues(alpha: 0.3),
            KabadiTheme.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: KabadiTheme.primary.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco, color: KabadiTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            '+$points Green Points earned! 🌱',
            style: const TextStyle(
              color: KabadiTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

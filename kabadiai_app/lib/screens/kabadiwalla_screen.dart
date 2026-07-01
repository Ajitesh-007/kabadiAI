import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../theme.dart';

class KabadiwallaScreen extends StatelessWidget {
  const KabadiwallaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locationService = context.watch<LocationService>();

    return Scaffold(
      backgroundColor: KabadiTheme.bg,
      appBar: AppBar(
        backgroundColor: KabadiTheme.surface,
        title: const Text('Kabadiwalla Map', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _safeStream(),
        builder: (context, snapshot) {
          // Use Firestore data if available, otherwise show demo kabadiwallas
          final kabs = snapshot.hasData
              ? snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
              : snapshot.hasError
                  ? _demoKabadiwallas
                  : <Map<String, dynamic>>[];

          return Column(
            children: [
              // ── Map (top 55%) ──────────────────────────────────────────────
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.48,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(locationService.lat, locationService.lng),
                    initialZoom: 11.5,
                  ),
                  children: [
                    // OpenStreetMap dark tile layer
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.kabadiai.app',
                    ),
                    // Kabadiwalla markers
                    MarkerLayer(
                      markers: kabs.map((k) {
                        final lat = (k['lat'] as num?)?.toDouble() ?? 28.6139;
                        final lng = (k['lng'] as num?)?.toDouble() ?? 77.2090;
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showKabadiInfo(context, k),
                            child: Container(
                              decoration: BoxDecoration(
                                color: KabadiTheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: KabadiTheme.primary.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, color: Colors.black, size: 20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // User location marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(locationService.lat, locationService.lng),
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── List (bottom 45%) ──────────────────────────────────────────
              Expanded(
                child: Container(
                  color: KabadiTheme.surface,
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? _buildShimmerList()
                      : kabs.isEmpty
                          ? const Center(
                              child: Text(
                                'No kabadiwallas found.\nRun simulator.py to seed data.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: kabs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _KabadiCard(data: kabs[i]),
                            ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showKabadiInfo(BuildContext context, Map<String, dynamic> k) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KabadiTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k['name'] ?? 'Kabadiwalla',
              style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text('${k['rating'] ?? '?'}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 16),
              const Icon(Icons.recycling, color: KabadiTheme.primary, size: 16),
              const SizedBox(width: 4),
              Text('${k['pickups_today'] ?? '?'} pickups today',
                  style: const TextStyle(color: Colors.white70)),
            ]),
            const SizedBox(height: 8),
            Text(
              '₹${k['earnings_today'] ?? '?'} earned today',
              style: const TextStyle(color: KabadiTheme.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Returns Firestore stream, or a stream that immediately errors
  /// (so we fall back to demo data) if Firebase is not configured.
  Stream<QuerySnapshot> _safeStream() {
    try {
      return FirebaseFirestore.instance.collection('kabadiwallas').snapshots();
    } catch (_) {
      return Stream.error('Firebase not configured');
    }
  }

  // Demo kabadiwallas shown when Firestore is unavailable
  static const _demoKabadiwallas = [
    {'name': 'Raju Kumar',   'lat': 28.7041, 'lng': 77.1025, 'rating': 4.9, 'pickups_today': 12, 'earnings_today': 2400},
    {'name': 'Suresh Yadav', 'lat': 28.6562, 'lng': 77.2410, 'rating': 4.7, 'pickups_today': 9,  'earnings_today': 1800},
    {'name': 'Mohan Lal',   'lat': 28.5355, 'lng': 77.3910, 'rating': 4.8, 'pickups_today': 15, 'earnings_today': 3200},
    {'name': 'Vijay Singh', 'lat': 28.6280, 'lng': 77.0850, 'rating': 4.6, 'pickups_today': 7,  'earnings_today': 1400},
    {'name': 'Ramesh Das',  'lat': 28.7280, 'lng': 77.3200, 'rating': 4.5, 'pickups_today': 11, 'earnings_today': 2100},
  ];
}

class _KabadiCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _KabadiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KabadiTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KabadiTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: KabadiTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data['pickups_today'] ?? '?'} pickups  ·  ₹${data['earnings_today'] ?? '?'} today',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 13),
                const SizedBox(width: 3),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

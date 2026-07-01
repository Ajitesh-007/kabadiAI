import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../theme.dart';
import 'scan_screen.dart';
import 'kabadiwalla_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  final List<Widget> _screens = const [
    ScanScreen(),
    KabadiwallaScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Init GPS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentTab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: KabadiTheme.cardBg,
        indicatorColor: KabadiTheme.primary.withValues(alpha: 0.2),
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(
            icon:           Icon(Icons.camera_alt_outlined),
            selectedIcon:   Icon(Icons.camera_alt),
            label:          'Scan',
          ),
          NavigationDestination(
            icon:           Icon(Icons.map_outlined),
            selectedIcon:   Icon(Icons.map),
            label:          'Kabadiwalla',
          ),
        ],
      ),
    );
  }
}

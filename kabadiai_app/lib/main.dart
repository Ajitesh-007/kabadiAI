import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/scan_service.dart';
import 'services/location_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialise Firebase. On Linux desktop without google-services.json,
  // this will throw — we catch it and run in offline/demo mode instead.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey:            'demo-api-key',
        appId:             '1:000000000000:linux:0000000000000000',
        messagingSenderId: '000000000000',
        projectId:         'kabadiai',
        storageBucket:     'kabadiai.appspot.com',
      ),
    );
  } catch (e) {
    debugPrint('⚠ Firebase init skipped (demo mode): $e');
    // App continues in offline/demo mode — UI is fully functional.
  }

  runApp(const KabadiAIApp());
}

class KabadiAIApp extends StatelessWidget {
  const KabadiAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: 'KabadiAI',
        debugShowCheckedModeBanner: false,
        theme: KabadiTheme.light(),
        darkTheme: KabadiTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}

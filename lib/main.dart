import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/donation_screen.dart';
import 'screens/stripe_terminal_screen.dart';
import 'screens/donor_form_screen.dart';
import 'screens/thank_you_screen.dart';
import 'screens/payment_method_screen.dart';
import 'screens/qr_payment_screen.dart';
import 'screens/device_installation_screen.dart';
import 'pwa_interop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await StorageService.init();
  runApp(const EundiApp());
}

class EundiApp extends StatelessWidget {
  const EundiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eUndi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12376E),
          primary: const Color(0xFF12376E),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF12376E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            elevation: 6,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withOpacity(0.97),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.zero,
        ),
      ),
      home: SplashGate(),
    );
  }
}

class SplashGate extends StatefulWidget {
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    final bool isAuthenticated = StorageService.getCookie('isAuthenticated') == 'true';
    
    // Smooth check
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DonationScreen()),
      );
    } else {
      // Check if PWA is installed
      bool installed = true;
      try {
        installed = isPWAInstalled();
      } catch (e) {
        installed = false;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(showInstallPrompt: !installed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12376E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading logo: $error');
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 60,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              'Eundi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
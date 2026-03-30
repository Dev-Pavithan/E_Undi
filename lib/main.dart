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
      initialRoute: _getInitialRoute(),
      onGenerateRoute: (settings) {
        final isAuthenticated = StorageService.getCookie('isAuthenticated') == 'true';

        debugPrint('Route: ${settings.name}, Auth: $isAuthenticated');

        // If authenticated and trying to access login, redirect to donation
        if (isAuthenticated && settings.name == '/login') {
          return MaterialPageRoute(builder: (_) => const DonationScreen());
        }

        // Auth Guard for protected routes
        final protectedRoutes = [
          '/donation',
          '/payment-method',
          '/card',
          '/donor-form',
          '/thank-you',
          '/qr-payment',
        ];

        if (!isAuthenticated && protectedRoutes.contains(settings.name)) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }

        // Route definitions
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/donation':
            return MaterialPageRoute(builder: (_) => const DonationScreen());
          case '/payment-method':
            return MaterialPageRoute(builder: (_) => const PaymentMethodScreen());
          case '/card':
            return MaterialPageRoute(builder: (_) => const StripeTerminalScreen());
          case '/donor-form':
            return MaterialPageRoute(builder: (_) => const DonorFormScreen());
          case '/thank-you':
            return MaterialPageRoute(builder: (_) => const ThankYouScreen());
          case '/qr-payment':
            return MaterialPageRoute(builder: (_) => const QrPaymentScreen());
          case '/device-installation':
            return MaterialPageRoute(builder: (_) => const DeviceInstallationScreen());
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }

  String _getInitialRoute() {
    final isAuthenticated = StorageService.getCookie('isAuthenticated') == 'true';
    
    debugPrint('Initial route - Auth: $isAuthenticated');
    
    if (isAuthenticated) {
      return '/donation';
    }
    return '/login';
  }
}
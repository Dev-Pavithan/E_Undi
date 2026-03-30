import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  late ConfettiController _confettiController;
  bool _isCheckingDevice = true;
  bool _apiError = false;
  Timer? _navigationTimer;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 8));

    // Clear donation session data
    _clearDonationSession();

    // Start confetti after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _confettiController.play();
    });

    // Check device status
    _checkDevice();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDevice());

    // Navigate home after 5 seconds
    _navigationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        final deviceStatus = StorageService.getCookie('device_status');
        if (deviceStatus != 'inactive') {
          Navigator.pushReplacementNamed(context, '/donation');
        }
      }
    });
  }

  void _clearDonationSession() {
    StorageService.removeSessionValue('invoice_pdf');
    StorageService.removeSessionValue('trans_amount');
    StorageService.removeSessionValue('trans_no');
  }

  Future<void> _checkDevice() async {
    final deviceId = StorageService.getCookie('device_id');
    if (deviceId == null) {
      setState(() => _isCheckingDevice = false);
      return;
    }

    try {
      final data = await ApiService.checkDeviceStatus(deviceId);
      if (data != null && data['device'] != null) {
        final device = data['device'];
        final status = device['device_status'] as String? ?? '';
        final invoiceAvailable = device['invoice_availability'] == true;

        await StorageService.setCookie('device_status', status);
        await StorageService.setCookie('invoice_availability', invoiceAvailable.toString());

        if (status == 'inactive') {
          _logout();
          return;
        }
      }
      setState(() { _isCheckingDevice = false; _apiError = false; });
    } catch (e) {
      setState(() { _isCheckingDevice = false; _apiError = true; });
    }
  }

  void _logout() {
    StorageService.clearAll();
    _navigationTimer?.cancel();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _navigationTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingDevice) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Checking device status...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 40,
                gravity: 0.1,
                emissionFrequency: 0.05,
                colors: const [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.purple],
              ),
            ),

            // Main Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thumbs up icon
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(Icons.thumb_up, size: 100, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Thank You for Your\nGenerous Donation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your contribution helps us continue our mission.\nWe truly appreciate your support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                    if (_apiError) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Flexible(child: Text('Using cached device data. Some features may be limited.', style: TextStyle(fontSize: 13, color: Colors.orange))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Text('Redirecting in a moment...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme.dart';

class QrPaymentScreen extends StatefulWidget {
  const QrPaymentScreen({super.key});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  late int _paymentId;
  String _status = 'Waiting for payment...';
  int _timeLeft = 20;
  Timer? _checkTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _paymentId = Random().nextInt(1000000);

    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPaymentStatus());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _status = 'Payment timeout. Redirecting...';
          _checkTimer?.cancel();
          _countdownTimer?.cancel();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pushReplacementNamed(context, '/donation');
          });
        }
      });
    });
  }

  void _checkPaymentStatus() {
    if (Random().nextDouble() > 0.8) {
      setState(() => _status = 'Payment Successful!');
      _checkTimer?.cancel();
      _countdownTimer?.cancel();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/donor-form');
      });
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _status.contains('Successful');
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Scan to Pay',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                            child: QrImageView(
                              data: 'https://yourpaymentgateway.com/pay?transaction=$_paymentId',
                              version: QrVersions.auto,
                              size: 240,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSuccess ? Colors.green : AppTheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: _timeLeft / 20,
                            backgroundColor: Colors.grey.shade200,
                            color: AppTheme.primary,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 8),
                          Text('Time remaining: $_timeLeft seconds', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

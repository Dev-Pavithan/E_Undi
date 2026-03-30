import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class StripeTerminalScreen extends StatefulWidget {
  const StripeTerminalScreen({super.key});

  @override
  State<StripeTerminalScreen> createState() => _StripeTerminalScreenState();
}

class _StripeTerminalScreenState extends State<StripeTerminalScreen>
    with TickerProviderStateMixin {
  bool _isAnimating = false;
  bool _showSuccess = false;
  String _transactionAmount = "0.00";
  bool _invoiceAvailability = false;
  bool _isProcessing = false;
  String? _apiError;

  late AnimationController _nfcController;
  late AnimationController _cardController;
  late AnimationController _rippleController;
  late AnimationController _shimmerController;

  late Animation<double> _cardSlideAnimation;
  late Animation<double> _nfcPulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();

    _nfcController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _nfcPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _nfcController, curve: Curves.easeInOut));

    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _cardSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardController, curve: Curves.easeInOut));

    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.linear));

    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _rippleAnimation = Tween<double>(begin: 1.0, end: 3.0).animate(
        CurvedAnimation(parent: _rippleController, curve: Curves.easeOut));
  }

  void _loadData() {
    final amount = StorageService.getSessionValue('trans_amount') ?? "0.00";
    final invoiceAvailability =
        StorageService.getSessionValue('invoice_availability') ??
        StorageService.getLocalValue('invoice_availability') ??
        StorageService.getCookie('invoice_availability') ??
        "false";
    setState(() {
      _transactionAmount = amount;
      _invoiceAvailability = invoiceAvailability == "true";
    });
  }

  Future<bool> _createTransaction() async {
    final comCode = StorageService.getCookie('com_code');
    final deviceId = StorageService.getCookie('device_id');
    final transAmount = StorageService.getSessionValue('trans_amount');

    if (comCode == null || deviceId == null || transAmount == null) {
      setState(() => _apiError = "Missing required transaction data");
      return false;
    }

    try {
      final response = await ApiService.createTransaction(
        comCode: comCode,
        deviceId: deviceId,
        transAmount: transAmount,
      );
      if (response['trans_no'] != null) {
        await StorageService.setSessionValue('trans_no', response['trans_no'].toString());
      }
      return true;
    } catch (e) {
      setState(() => _apiError = e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<void> _handlePay() async {
    if (_isAnimating || _isProcessing) return;

    setState(() {
      _isAnimating = true;
      _showSuccess = false;
      _apiError = null;
    });

    _cardController.forward();
    _rippleController.forward(from: 0);

    // Call the "no invoice" API if invoice_availability is false
    if (!_invoiceAvailability) {
      setState(() => _isProcessing = true);
      final success = await _createTransaction();
      setState(() => _isProcessing = false);

      if (!success) {
        setState(() => _isAnimating = false);
        _cardController.reverse();
        return;
      }
    }

    await Future.delayed(const Duration(seconds: 3));
    setState(() => _showSuccess = true);

    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isAnimating = false);
    _cardController.reverse();

    if (mounted) {
      if (_invoiceAvailability) {
        Navigator.pushReplacementNamed(context, '/donor-form');
      } else {
        Navigator.pushReplacementNamed(context, '/thank-you');
      }
    }
  }

  @override
  void dispose() {
    _nfcController.dispose();
    _cardController.dispose();
    _shimmerController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Color get _screenColor {
    if (_showSuccess) return const Color(0xFF27AE60);
    if (_isAnimating) return const Color(0xFF3498DB);
    return const Color(0xFF1A1A1A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
              child: Column(
                children: [
                  const Text(
                    'Stripe Terminal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contactless Payment',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  if (_apiError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_apiError!, style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  _buildTerminal(),
                  const SizedBox(height: 20),
                  _buildCard(),
                  const SizedBox(height: 40),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    return AnimatedScale(
      scale: _isAnimating ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 3),
          boxShadow: [
            BoxShadow(
              color: _isAnimating
                  ? const Color(0xFF3498DB).withOpacity(0.5)
                  : Colors.black.withOpacity(0.3),
              blurRadius: _isAnimating ? 30 : 20,
              spreadRadius: _isAnimating ? 5 : 0,
            )
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              bottom: 60,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _screenColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _screenColor.withOpacity(0.4), blurRadius: 10)],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildScreenContent(),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 16,
              child: ScaleTransition(
                scale: _isAnimating ? _nfcPulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isAnimating ? const Color(0xFF3498DB) : const Color(0xFF95A5A6),
                    boxShadow: _isAnimating
                        ? [const BoxShadow(color: Color(0xFF3498DB), blurRadius: 20, spreadRadius: 2)]
                        : [],
                  ),
                  child: const Icon(Icons.wifi, color: Colors.white, size: 28),
                ),
              ),
            ),
            if (_isAnimating)
              Positioned(
                bottom: 12,
                right: 16,
                child: AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: (1.0 - (_rippleAnimation.value - 1.0) / 2).clamp(0.0, 0.6),
                      child: Container(
                        width: 52 * _rippleAnimation.value,
                        height: 52 * _rippleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF3498DB).withOpacity(0.3),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenContent() {
    if (_showSuccess) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          const Text('Payment Successful', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('\$$_transactionAmount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (_isAnimating) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: Colors.white, size: 24),
          SizedBox(width: 8),
          Text('Processing...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      );
    } else {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card, color: Colors.white, size: 24),
          SizedBox(width: 8),
          Text('Ready for Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      );
    }
  }

  Widget _buildCard() {
    return AnimatedBuilder(
      animation: _cardSlideAnimation,
      builder: (ctx, child) {
        final offsetY = -120.0 * _cardSlideAnimation.value;
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (_isAnimating)
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(MediaQuery.of(context).size.width * _shimmerAnimation.value, 0),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.white.withOpacity(0.2), Colors.transparent],
                            stops: const [0, 0.5, 1],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 50, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white30, width: 2),
                          ),
                        ),
                        const Icon(Icons.wifi, color: Colors.white70, size: 24),
                      ],
                    ),
                    const Text(
                      '4242 •••• •••• 4242',
                      style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: 3),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('VALID THRU', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('12/28', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text('JOHN DOE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const Text('VISA', style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showSuccess
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Payment of \$$_transactionAmount completed!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  _isAnimating
                      ? 'Processing contactless payment...'
                      : 'Ready to pay \$$_transactionAmount',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  key: ValueKey(_isAnimating),
                ),
        ),
        const SizedBox(height: 20),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton(
            onPressed: _isAnimating || _isProcessing ? null : _handlePay,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAnimating ? const Color(0xFF95A5A6) : const Color(0xFF2ECC71),
              disabledBackgroundColor: const Color(0xFF95A5A6),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              elevation: 8,
              shadowColor: const Color(0xFF2ECC71).withOpacity(0.4),
            ),
            child: Text(
              _isAnimating ? 'Processing...' : 'Pay \$$_transactionAmount',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_showSuccess) ...[
          const SizedBox(height: 12),
          Text(
            'Redirecting to ${_invoiceAvailability ? "Donor Form" : "Thank You Page"}...',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

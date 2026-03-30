import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> with SingleTickerProviderStateMixin {
  // State variables
  String _selectedAmount = "";
  final _customAmountController = TextEditingController();

  // Loading states
  bool _isLoadingCompany = true;
  bool _isCheckingDevice = false;

  // Company details
  String _companyName = '';
  String _companyAddress = '';

  // Animation variables
  String _displayText = "";
  final String _fullText = "Please Donate Generously";
  Timer? _typingTimer;

  // Timer for periodic device status check
  Timer? _statusCheckTimer;

  // Predefined donation amounts using raw strings to avoid interpolation issues
  static const List<String> _predefinedAmounts = [r'$5', r'$10', r'$20', r'$50', r'$100'];

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetails();
    _verifyDeviceStatus();
    _startPeriodicStatusCheck();
    _startTypingAnimation();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _typingTimer?.cancel();
    _customAmountController.dispose();
    super.dispose();
  }

  void _startTypingAnimation() {
    int index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        if (index < _fullText.length) {
          setState(() {
            _displayText += _fullText[index];
          });
          index++;
        } else {
          // Pause at the end for 2 seconds, then reset and loop
          timer.cancel();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _displayText = "";
              });
              _startTypingAnimation();
            }
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startPeriodicStatusCheck() {
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _verifyDeviceStatus(),
    );
  }

  Future<void> _fetchCompanyDetails() async {
    final comCode = StorageService.getCookie('com_code');
    if (comCode == null) {
      setState(() => _isLoadingCompany = false);
      return;
    }

    try {
      final data = await ApiService.fetchCompanyInfo(comCode);
      if (data != null && data['success'] == true) {
        final info = data['data'];
        setState(() {
          _companyName = info['com_name'] ?? '';
          _companyAddress = _formatCompanyAddress(info);
          _isLoadingCompany = false;
        });

        // Store for other screens
        _storeCompanyDetails(info);
      } else {
        setState(() => _isLoadingCompany = false);
      }
    } catch (e) {
      debugPrint('Error fetching company details: $e');
      setState(() => _isLoadingCompany = false);
    }
  }

  String _formatCompanyAddress(Map<String, dynamic> info) {
    final parts = [
      info['com_address'],
      info['com_suburb'],
      info['com_state'],
      info['com_postcode'],
      info['com_country'],
    ].where((part) => part != null && part.toString().isNotEmpty);

    return parts.join(' ');
  }

  void _storeCompanyDetails(Map<String, dynamic> info) {
    StorageService.setSessionValue('company_name', info['com_name']);
    StorageService.setSessionValue('company_address', info['com_address']);
    StorageService.setSessionValue('company_suburb', info['com_suburb']);
    StorageService.setSessionValue('company_state', info['com_state']);
    StorageService.setSessionValue('company_postcode', info['com_postcode']);
    StorageService.setSessionValue('company_country', info['com_country']);
  }

  Future<bool> _verifyDeviceStatus() async {
    final deviceId = StorageService.getCookie('device_id');
    if (deviceId == null) return true;

    try {
      final data = await ApiService.checkDeviceStatus(deviceId);
      if (data != null && data['device'] != null) {
        final device = data['device'];
        final status = device['device_status'];
        final invoiceAvailable = device['invoice_availability'] == true;

        await StorageService.setCookie('device_status', status);
        await StorageService.setCookie('invoice_availability', invoiceAvailable.toString());

        if (status == 'inactive') {
          _logout();
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error checking device: $e');
      return true;
    }
  }

  void _logout() {
    StorageService.clearAll();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _handleAmountSelect(String amount) {
    setState(() {
      _selectedAmount = amount;
      _customAmountController.clear();
      StorageService.setSessionValue('trans_amount', amount.replaceAll(r'$', ''));
    });
  }

  void _handleSetCustomAmount() {
    if (_customAmountController.text.isNotEmpty) {
      final amountValue = _customAmountController.text;
      setState(() {
        _selectedAmount = r"$" + amountValue;
        StorageService.setSessionValue('trans_amount', amountValue);
      });
      Navigator.pop(context);
    }
  }

  Future<void> _handleDonateNow() async {
    setState(() => _isCheckingDevice = true);
    final canProceed = await _verifyDeviceStatus();
    setState(() => _isCheckingDevice = false);

    if (canProceed && mounted) {
      Navigator.pushNamed(context, '/card');
    }
  }

  bool get _isDonateButtonEnabled {
    return _selectedAmount.isNotEmpty && !_isCheckingDevice && !_isLoadingCompany;
  }

  String get _displayCompanyName {
    if (_companyName.isNotEmpty) return _companyName;
    return "ABC Corporation";
  }

  String get _displayCompanyAddress {
    if (_companyAddress.isNotEmpty) return _companyAddress;
    return "123 Business Ave Sydney CBD NSW 2000 Australia";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12376E), // Dark blue background as per image
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _buildDonationCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonationCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        elevation: 12,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopIcon(),
              const SizedBox(height: 20),
              _buildTitle(),
              const SizedBox(height: 16),
              _buildCompanyInfo(),
              const SizedBox(height: 10),
              _buildAnimationSection(),
              const SizedBox(height: 10),
              const Text(
                r'Donation Amount ($)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _buildAmountSection(),
              const SizedBox(height: 40),
              _buildDonateButtonWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopIcon() {
    return Image.network(
      'icons/Icon-192.png',
      height: 120,
      width: 120,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.volunteer_activism,
        size: 64,
        color: Color(0xFF12376E),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'eUndi',
      style: GoogleFonts.poppins(
        fontSize: 42,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF00154C),
        letterSpacing: -1,
      ),
    );
  }

  Widget _buildCompanyInfo() {
    if (_isLoadingCompany) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        Text(
          _displayCompanyName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _displayCompanyAddress,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimationSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 30, // Reduced height
      alignment: Alignment.center,
      child: Text(
        _displayText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: Color(0xFF12376E),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildAmountButton(r"$5")),
            const SizedBox(width: 12),
            Expanded(child: _buildAmountButton(r"$10")),
            const SizedBox(width: 12),
            Expanded(child: _buildAmountButton(r"$20")),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildAmountButton(r"$50")),
            const SizedBox(width: 12),
            Expanded(child: _buildAmountButton(r"$100")),
            const SizedBox(width: 12),
            Expanded(child: _buildOtherAmountButton()),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountButton(String amount) {
    final isSelected = _selectedAmount == amount;

    return InkWell(
      onTap: () => _handleAmountSelect(amount),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF12376E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          amount,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOtherAmountButton() {
    final isOtherSelected = _selectedAmount.isNotEmpty &&
        !_predefinedAmounts.contains(_selectedAmount);
    final displayText = isOtherSelected ? _selectedAmount : "Other";

    return InkWell(
      onTap: _showCustomAmountDialog,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isOtherSelected ? const Color(0xFF12376E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          displayText,
          style: TextStyle(
            color: isOtherSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDonateButtonWidget() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: _isDonateButtonEnabled ? const Color(0xFF12376E) : Colors.grey.shade400,
        boxShadow: _isDonateButtonEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF12376E).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: _isDonateButtonEnabled ? _handleDonateNow : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _isCheckingDevice
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Donate Now',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  void _showCustomAmountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Enter Custom Amount'),
        content: TextField(
          controller: _customAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            hintText: '0.00',
            prefixIcon: Icon(Icons.attach_money),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _handleSetCustomAmount,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Set Amount'),
          ),
        ],
      ),
    );
  }
}

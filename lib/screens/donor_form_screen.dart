import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import '../services/storage_service.dart';
import '../widgets/input_box.dart';
import '../theme.dart';

class DonorFormScreen extends StatefulWidget {
  const DonorFormScreen({super.key});

  @override
  State<DonorFormScreen> createState() => _DonorFormScreenState();
}

class _DonorFormScreenState extends State<DonorFormScreen> {
  bool _wantInvoice = true;
  bool _submitted = false;
  bool _isSubmitting = false;
  
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  final Map<String, String?> _errors = {};
  
  Map<String, dynamic> _companyDetails = {};
  String? _transNo;
  String? _transAmount;
  
  static const String API_BASE_URL = "https://eundibackend.wstsc.org.au/api";
  
  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
    _loadTransactionAmount();
  }
  
  Future<void> _loadCompanyDetails() async {
    final comCode = StorageService.getCookie('com_code');
    if (comCode != null && comCode.isNotEmpty) {
      await _fetchCompanyDetails(comCode);
    }
  }
  
  Future<void> _fetchCompanyDetails(String comCode) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/company/info/$comCode'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _companyDetails = data['data'];
          });
        }
      }
    } catch (error) {
      debugPrint('Error fetching company details: $error');
    }
  }
  
  Future<void> _loadTransactionAmount() async {
    final amount = StorageService.getSessionValue('trans_amount');
    if (amount != null) {
      setState(() {
        _transAmount = amount;
      });
    }
  }
  
  bool _validateForm() {
    final newErrors = <String, String?>{};
    bool isValid = true;
    
    if (_wantInvoice) {
      if (_firstNameController.text.trim().isEmpty) {
        newErrors['firstName'] = 'First name is required';
        isValid = false;
      }
      if (_lastNameController.text.trim().isEmpty) {
        newErrors['lastName'] = 'Last name is required';
        isValid = false;
      }
      if (_emailController.text.trim().isEmpty || 
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text)) {
        newErrors['email'] = 'Valid email is required';
        isValid = false;
      }
      if (_phoneController.text.trim().isEmpty) {
        newErrors['phone'] = 'Phone number is required';
        isValid = false;
      }
    }
    
    setState(() {
      _errors.clear();
      _errors.addAll(newErrors);
    });
    
    return isValid;
  }
  
  int _calculateCompletion() {
    if (!_wantInvoice) return 100;
    int filled = 0;
    if (_firstNameController.text.isNotEmpty) filled++;
    if (_lastNameController.text.isNotEmpty) filled++;
    if (_emailController.text.isNotEmpty) filled++;
    if (_phoneController.text.isNotEmpty) filled++;
    return ((filled / 4) * 100).round();
  }
  
  Future<void> _handleSubmit() async {
    setState(() {
      _submitted = true;
    });
    
    if (!_validateForm() || _isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final comCode = StorageService.getCookie('com_code');
      final deviceId = StorageService.getCookie('device_id');
      
      if (comCode == null || deviceId == null) {
        throw Exception('Device session expired. Please log in again.');
      }

      final numericAmount = double.tryParse(_transAmount ?? '0') ?? 0.0;
      
      if (_wantInvoice) {
        final payload = {
          'com_code': comCode,
          'device_id': deviceId,
          'donor_fname': _firstNameController.text,
          'donor_lname': _lastNameController.text,
          'donor_email': _emailController.text,
          'donor_phone': _phoneController.text,
          'trans_amount': numericAmount,
          'trans_email_status': 'send',
        };

        debugPrint('Submitting payload: ${json.encode(payload)}');

        final response = await http.post(
          Uri.parse('$API_BASE_URL/add-donor-transaction'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          _transNo = data['trans_no'];
          
          await StorageService.setSessionValue('trans_no', _transNo!);
          
          final pdfBytes = await _generateInvoicePdf(data);
          await StorageService.setSessionValue('invoice_pdf', base64Encode(pdfBytes));
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Donation completed successfully! Check your email for invoice.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
           debugPrint('Error: ${response.statusCode} - ${response.body}');
           throw Exception('Failed to add donor transaction: ${response.body}');
        }
      } else {
        final response = await http.post(
          Uri.parse('$API_BASE_URL/createTransaction'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'com_code': comCode,
            'device_id': deviceId,
            'trans_amount': numericAmount,
          }),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          _transNo = data['trans_no'];
          await StorageService.setSessionValue('trans_no', _transNo!);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Donation completed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
           debugPrint('Error: ${response.statusCode} - ${response.body}');
           throw Exception('Failed to create transaction: ${response.body}');
        }
      }
      
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacementNamed(context, '/thank-you');
      }
    } catch (error) {
      debugPrint('Submission failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  
  Future<Uint8List> _generateInvoicePdf(Map<String, dynamic> transactionData) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Invoice', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Transaction Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Transaction No: ${transactionData['trans_no']}'),
              pw.SizedBox(height: 5),
              pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
              pw.SizedBox(height: 20),
              pw.Text('Donor Information', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Name: ${_firstNameController.text} ${_lastNameController.text}'),
              pw.SizedBox(height: 5),
              pw.Text('Email: ${_emailController.text}'),
              pw.SizedBox(height: 5),
              pw.Text('Phone: ${_phoneController.text}'),
              pw.SizedBox(height: 20),
              pw.Text('Donation Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Amount: \$${transactionData['trans_amount']}'),
              pw.SizedBox(height: 20),
              pw.Text('Organization Information', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Company: ${_companyDetails['com_name'] ?? 'N/A'}'),
              if (_companyDetails['com_address'] != null) ...[
                pw.SizedBox(height: 5),
                pw.Text('Address: ${_companyDetails['com_address']}'),
              ],
              if (_companyDetails['com_phone'] != null) ...[
                pw.SizedBox(height: 5),
                pw.Text('Phone: ${_companyDetails['com_phone']}'),
              ],
              pw.SizedBox(height: 30),
              pw.Text('Thank you for your donation!', 
                style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );
    
    return await pdf.save();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final completion = _calculateCompletion();
    
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF1565C0)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Donation Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please provide your details to complete your donation',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Completion',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: completion == 100 ? Colors.green : AppTheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$completion%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: completion / 100,
                                  backgroundColor: Colors.grey[200],
                                  color: completion == 100 ? Colors.green : AppTheme.primary,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Would you like to receive an invoice?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInvoiceOption(
                                  icon: Icons.email_outlined,
                                  label: 'Email Invoice',
                                  selected: _wantInvoice,
                                  onTap: () {
                                    setState(() {
                                      _wantInvoice = true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInvoiceOption(
                                  icon: Icons.close_outlined,
                                  label: 'No Invoice',
                                  selected: !_wantInvoice,
                                  onTap: () {
                                    setState(() {
                                      _wantInvoice = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          if (_wantInvoice) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: InputBox(
                                    label: 'First Name',
                                    controller: _firstNameController,
                                    hint: 'Enter first name',
                                    errorText: _submitted ? _errors['firstName'] : null,
                                    onChanged: (value) {
                                      String formatted = value.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
                                      if (formatted.isNotEmpty && _firstNameController.text != formatted) {
                                        _firstNameController.value = TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(offset: formatted.length),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InputBox(
                                    label: 'Last Name',
                                    controller: _lastNameController,
                                    hint: 'Enter last name',
                                    errorText: _submitted ? _errors['lastName'] : null,
                                    onChanged: (value) {
                                      String formatted = value.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
                                      if (formatted.isNotEmpty && _lastNameController.text != formatted) {
                                        _lastNameController.value = TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(offset: formatted.length),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            InputBox(
                              label: 'Email Address',
                              controller: _emailController,
                              hint: 'name@example.com',
                              keyboardType: TextInputType.emailAddress,
                              errorText: _submitted ? _errors['email'] : null,
                            ),
                            const SizedBox(height: 16),
                            InputBox(
                              label: 'Phone Number',
                              controller: _phoneController,
                              hint: '+1 (555) 123-4567',
                              keyboardType: TextInputType.phone,
                              errorText: _submitted ? _errors['phone'] : null,
                              onChanged: (value) {
                                String formatted = value.replaceAll(RegExp(r'[^0-9+]'), '');
                                if (_phoneController.text != formatted) {
                                  _phoneController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 28),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: _isSubmitting
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Processing...'),
                                      ],
                                    )
                                  : Text(
                                      _wantInvoice
                                          ? 'Complete Donation'
                                          : 'Continue Without Invoice',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Your transaction is secure and encrypted',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInvoiceOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? AppTheme.primary.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppTheme.primary : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppTheme.primary : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

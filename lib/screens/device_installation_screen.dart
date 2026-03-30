import 'dart:math';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/input_box.dart';
import '../theme.dart';

class DeviceInstallationScreen extends StatefulWidget {
  const DeviceInstallationScreen({super.key});

  @override
  State<DeviceInstallationScreen> createState() => _DeviceInstallationScreenState();
}

class _DeviceInstallationScreenState extends State<DeviceInstallationScreen> {
  int _step = 1;
  String _pin = "";

  final _emailController    = TextEditingController();
  final _idController       = TextEditingController();
  final _nameController     = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  Map<String, String?> _errors = {};
  bool _showPassword = false;
  bool _showConfirm  = false;

  void _generatePin() {
    final pin = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _pin = pin;
      _step = 2;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Installation PIN: $pin'), duration: const Duration(seconds: 8)),
    );
  }

  bool _validate() {
    final errors = <String, String?>{};
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      errors['email'] = 'Valid email is required';
    }
    if (_idController.text.trim().isEmpty) errors['id'] = 'Device ID is required';
    if (_passwordController.text.length < 6) errors['password'] = 'Password must be at least 6 characters';
    if (_passwordController.text != _confirmController.text) errors['confirm'] = 'Passwords do not match';
    if (_nameController.text.trim().isEmpty) errors['name'] = 'Device name is required';
    if (_locationController.text.trim().isEmpty) errors['location'] = 'Location is required';
    setState(() => _errors = errors);
    return errors.isEmpty;
  }

  Future<void> _completeInstallation() async {
    if (!_validate()) return;

    await StorageService.setLocalValue('device_email', _emailController.text.trim());
    await StorageService.setLocalValue('device_id', _idController.text.trim());
    await StorageService.setCookie('device_email', _emailController.text.trim());
    await StorageService.setCookie('device_id', _idController.text.trim());
    await StorageService.setCookie('isAuthenticated', 'true');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device installed successfully!'), backgroundColor: Colors.green),
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Device Installation',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 24),
                      if (_step == 1) ...[
                        const Text('Generate an installation PIN to pair this device:',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _generatePin,
                            child: const Text('Generate Installation PIN'),
                          ),
                        ),
                      ] else ...[
                        // PIN Display
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Installation PIN:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(_pin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              const SizedBox(height: 4),
                              const Text('Share this PIN with the device installer.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        InputBox(label: 'Device Email', controller: _emailController, hint: 'Enter device email', errorText: _errors['email'], keyboardType: TextInputType.emailAddress),
                        InputBox(label: 'Device ID', controller: _idController, hint: 'Enter unique device ID', errorText: _errors['id']),
                        InputBox(label: 'Device Name', controller: _nameController, hint: 'Enter device name', errorText: _errors['name']),
                        InputBox(label: 'Device Location', controller: _locationController, hint: 'Enter installation location', errorText: _errors['location']),
                        InputBox(label: 'Password', controller: _passwordController, hint: 'Create a password', errorText: _errors['password'],
                            isPassword: !_showPassword,
                            suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _showPassword = !_showPassword))),
                        InputBox(label: 'Confirm Password', controller: _confirmController, hint: 'Confirm your password', errorText: _errors['confirm'],
                            isPassword: !_showConfirm,
                            suffixIcon: IconButton(icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _showConfirm = !_showConfirm))),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _completeInstallation,
                            child: const Text('Complete Installation'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

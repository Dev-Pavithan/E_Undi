import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/input_box.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _idError;
  String? _passwordError;
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedInfo();
    _checkIfAlreadyAuthenticated();
  }

  Future<void> _checkIfAlreadyAuthenticated() async {
    // Check if already authenticated
    final isAuthenticated = await StorageService.getCookie('isAuthenticated');
    if (isAuthenticated == 'true') {
      // Already authenticated, go to donation
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/donation');
      }
    }
  }

  Future<void> _loadSavedInfo() async {
    final savedEmail = StorageService.getLocalValue('device_email');
    final savedId = StorageService.getLocalValue('device_id');
    if (savedEmail != null) _emailController.text = savedEmail;
    if (savedId != null) _idController.text = savedId;
  }

  bool _validate() {
    setState(() {
      _emailError =
          _emailController.text.isEmpty ? 'Device email is required' : null;
      _idError =
          _idController.text.isEmpty ? 'Device ID is required' : null;
      _passwordError = _passwordController.text.length < 6
          ? 'Password must be at least 6 characters'
          : null;
    });
    return _emailError == null && _idError == null && _passwordError == null;
  }

  Future<void> _handleLogin() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.loginDevice(
        email: _emailController.text.trim(),
        deviceId: _idController.text.trim(),
        passcode: _passwordController.text,
      );

      final device = response['device'] ?? response;

      // Store all authentication data
      await StorageService.setCookie('device_email', device['device_email']);
      await StorageService.setCookie('device_id', device['device_id']);
      await StorageService.setCookie('com_code', device['com_code']);
      await StorageService.setCookie('isAuthenticated', 'true');
      await StorageService.setCookie('invoice_availability',
          (device['invoice_availability'] == true).toString());
      await StorageService.setLocalValue(
          'device_email', device['device_email']);
      await StorageService.setLocalValue('device_id', device['device_id']);
      await StorageService.setLocalValue('com_code', device['com_code']);
      await StorageService.setLocalValue('isAuthenticated', 'true');

      if (mounted) {
        // Navigate directly to donation screen
        Navigator.pushReplacementNamed(context, '/donation');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Device Login',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF12376E),
          ),
        ),
        const SizedBox(height: 32),
        InputBox(
          label: 'Device Email',
          controller: _emailController,
          hint: 'Enter device email',
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
        ),
        InputBox(
          label: 'Device ID',
          controller: _idController,
          hint: 'Enter device ID',
          errorText: _idError,
        ),
        InputBox(
          label: 'Password',
          controller: _passwordController,
          hint: 'Enter password',
          errorText: _passwordError,
          isPassword: !_showPassword,
          suffixIcon: IconButton(
            icon: Icon(
                _showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () =>
                setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Login'),
          ),
        ),
      ],
    );
  }
}
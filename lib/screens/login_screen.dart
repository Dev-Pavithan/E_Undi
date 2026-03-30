import 'dart:js' as js;
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
  bool _showInstallDialog = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedInfo();
    _checkIfAlreadyAuthenticated();
  }

  Future<void> _checkIfAlreadyAuthenticated() async {
    final isAuthenticated = await StorageService.getCookie('isAuthenticated');
    if (isAuthenticated == 'true') {
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
        // Check if PWA is already installed
        final isInstalled = _isPWAInstalled();
        
        if (!isInstalled) {
          // Show installation dialog
          setState(() {
            _showInstallDialog = true;
          });
        } else {
          // Already installed, go to donation
          Navigator.pushReplacementNamed(context, '/donation');
        }
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

  bool _isPWAInstalled() {
    try {
      return js.context.callMethod('isPWAInstalled') as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  void _installPWA() async {
    setState(() => _installing = true);
    
    try {
      final result = js.context.callMethod('installPWA') as String? ?? 'error';
      debugPrint('Install result: $result');
      
      if (result == 'installed' || result == 'already_installed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App installed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, '/donation');
        }
      } else if (result == 'installing') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please follow browser prompts to install'),
              backgroundColor: Colors.blue,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/donation');
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Installation not available. You can continue using the web version.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacementNamed(context, '/donation');
        }
      }
    } catch (e) {
      debugPrint('Install error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/donation');
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _skipInstall() {
    setState(() => _showInstallDialog = false);
    Navigator.pushReplacementNamed(context, '/donation');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
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
        ),
        // Install Dialog Overlay
        if (_showInstallDialog)
          _buildInstallDialog(),
      ],
    );
  }

  Widget _buildInstallDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.install_mobile,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  'Install Eundi App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                const Text(
                  'Get a better experience with the installed app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                // Features
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.offline_bolt,
                        text: 'Works offline',
                      ),
                      SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.speed,
                        text: 'Faster performance',
                      ),
                      SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.fullscreen,
                        text: 'Full-screen experience',
                      ),
                      SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.home,
                        text: 'Easy access from home screen',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Install Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _installing ? null : _installPWA,
                    icon: _installing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, size: 20),
                    label: Text(
                      _installing ? 'Installing...' : 'Install Now',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Skip Button
                TextButton(
                  onPressed: _skipInstall,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
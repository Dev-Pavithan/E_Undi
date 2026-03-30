import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/input_box.dart';
import '../theme.dart';
import '../pwa_interop.dart';

class LoginScreen extends StatefulWidget {
  final bool showInstallPrompt;
  
  const LoginScreen({super.key, this.showInstallPrompt = false});

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
  bool _hasShownInstallDialog = false;

  @override
  void initState() {
    super.initState();
    _loadSavedInfo();
    _checkIfAlreadyAuthenticated();
    
    // Show install dialog if prompted from splash
    if (widget.showInstallPrompt && !_hasShownInstallDialog) {
      _hasShownInstallDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInstallPopup();
      });
    }
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
        final isInstalled = isPWAInstalled();
        
        if (!isInstalled && !_hasShownInstallDialog) {
          _hasShownInstallDialog = true;
          _showInstallPopup();
        } else {
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

  Future<void> _triggerPWAInstall() async {
    if (!isPWAPromptReady()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installation prompt not ready. Please wait a moment or check your browser settings.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final result = await installPWA();
    if (result == true && mounted) {
      Navigator.pop(context); // Close popup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App installed successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/donation');
    } else if (result == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installation cancelled or not available'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pushReplacementNamed(context, '/donation');
    }
  }

  void _showInstallPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.install_mobile, color: Color(0xFF12376E)),
            SizedBox(width: 12),
            Text('Install App', style: TextStyle(color: Color(0xFF12376E), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'For the best experience, install Eundi on your device.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: const [
                  _InstallFeature(icon: Icons.offline_bolt, text: 'Works offline'),
                  SizedBox(height: 8),
                  _InstallFeature(icon: Icons.speed, text: 'Faster performance'),
                  SizedBox(height: 8),
                  _InstallFeature(icon: Icons.fullscreen, text: 'Full-screen experience'),
                  SizedBox(height: 8),
                  _InstallFeature(icon: Icons.home, text: 'Easy access from home screen'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _triggerPWAInstall,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12376E),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Install Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/donation');
            },
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
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

class _InstallFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _InstallFeature({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
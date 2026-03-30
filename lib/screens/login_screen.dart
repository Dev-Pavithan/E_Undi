import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    
    if (widget.showInstallPrompt && !_hasShownInstallDialog) {
      _hasShownInstallDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInstallPopup();
      });
    }
  }

  Future<void> _checkIfAlreadyAuthenticated() async {
    try {
      final isAuthenticated = await StorageService.getCookie('isAuthenticated');
      final deviceEmail = await StorageService.getCookie('device_email');
      
      if (isAuthenticated == 'true' && deviceEmail != null && deviceEmail.isNotEmpty) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigateToDonation();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking auth: $e');
    }
  }
  
  void _navigateToDonation() {
    // Clear all routes and navigate to donation
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/donation',
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _loadSavedInfo() async {
    try {
      final savedEmail = StorageService.getLocalValue('device_email');
      final savedId = StorageService.getLocalValue('device_id');
      
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      } else {
        _emailController.text = 'DEV_99@gmail.com';
      }
      
      if (savedId != null && savedId.isNotEmpty) {
        _idController.text = savedId;
      } else {
        _idController.text = 'DEV_99';
      }
      
      _passwordController.text = '123456789';
    } catch (e) {
      debugPrint('Error loading saved info: $e');
      _emailController.text = 'DEV_99@gmail.com';
      _idController.text = 'DEV_99';
      _passwordController.text = '123456789';
    }
  }

  bool _validate() {
    setState(() {
      final email = _emailController.text.trim();
      
      if (email.isEmpty) {
        _emailError = 'Device email is required';
      } 
      else if (!email.contains('@') || !email.contains('.')) {
        _emailError = 'Please enter a valid email address (e.g., DEV_99@gmail.com)';
      } 
      else {
        _emailError = null;
      }
      
      _idError = _idController.text.isEmpty ? 'Device ID is required' : null;
      
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Password is required';
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });
    return _emailError == null && _idError == null && _passwordError == null;
  }

  Future<void> _handleLogin() async {
    // Prevent multiple submissions
    if (_isLoading) return;
    
    if (!_validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final deviceId = _idController.text.trim();
      final passcode = _passwordController.text.trim();
      
      debugPrint('Attempting login with email: $email, deviceId: $deviceId');
      
      final response = await ApiService.loginDevice(
        email: email,
        deviceId: deviceId,
        passcode: passcode,
      );

      debugPrint('Login response: $response');
      
      // Check if login was successful
      if (response['message'] != 'Login successful') {
        throw Exception('Login failed: ${response['message'] ?? 'Unknown error'}');
      }
      
      // Safely extract device data
      final deviceData = response['device'];
      if (deviceData == null) {
        throw Exception('Invalid response from server');
      }

      final deviceEmail = deviceData['device_email'] as String?;
      final deviceIdResponse = deviceData['device_id'] as String?;
      final comCode = deviceData['com_code'] as String?;
      final deviceStatus = deviceData['device_status'] as String?;
      final invoiceAvailable = deviceData['invoice_availability'] as bool? ?? false;

      if (deviceEmail == null || deviceIdResponse == null || comCode == null) {
        throw Exception('Missing required device information');
      }

      debugPrint('Login successful for device: $deviceEmail');

      // Store all authentication data
      await StorageService.setCookie('device_email', deviceEmail);
      await StorageService.setCookie('device_id', deviceIdResponse);
      await StorageService.setCookie('com_code', comCode);
      await StorageService.setCookie('isAuthenticated', 'true');
      await StorageService.setCookie('invoice_availability', invoiceAvailable.toString());
      await StorageService.setCookie('device_status', deviceStatus ?? 'active');
      
      // Store in local storage as backup
      await StorageService.setLocalValue('device_email', deviceEmail);
      await StorageService.setLocalValue('device_id', deviceIdResponse);
      await StorageService.setLocalValue('com_code', comCode);
      await StorageService.setLocalValue('isAuthenticated', 'true');
      await StorageService.setLocalValue('invoice_availability', invoiceAvailable.toString());

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful! Redirecting...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Handle navigation after successful login
      if (mounted) {
        // Small delay to show the success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          bool installed = false;
          try {
            installed = isPWAInstalled();
          } catch (e) {
            debugPrint('Error checking PWA install: $e');
          }
          
          if (!installed && !_hasShownInstallDialog) {
            _hasShownInstallDialog = true;
            _showInstallPopup();
          } else {
            _navigateToDonation();
          }
        }
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception:', '').trim();
        
        if (errorMessage.contains('device email') && errorMessage.contains('valid email')) {
          errorMessage = 'Please enter a valid email address (e.g., DEV_99@gmail.com)';
        } else if (errorMessage.contains('Validation failed')) {
          errorMessage = 'Please check your email and password and try again.';
        } else if (errorMessage.isEmpty) {
          errorMessage = 'Login failed. Please check your credentials and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerPWAInstall() async {
    try {
      if (!isPWAPromptReady()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Installation prompt not ready. Please wait a moment.'),
            backgroundColor: Colors.orange,
          ),
        );
        if (mounted) {
          Navigator.pop(context);
          _navigateToDonation();
        }
        return;
      }
      
      final result = await installPWA();
      if (result == true && mounted) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App installed successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          _navigateToDonation();
        }
      } else if (result == false && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Installation cancelled or not available'),
            backgroundColor: Colors.orange,
          ),
        );
        _navigateToDonation();
      }
    } catch (e) {
      debugPrint('Install error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Installation not available. You can continue using the web version.'),
            backgroundColor: Colors.orange,
          ),
        );
        _navigateToDonation();
      }
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
              _navigateToDonation();
            },
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.coreGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
          hint: 'Enter device email (e.g., DEV_99@gmail.com)',
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            FocusScope.of(context).nextFocus();
          },
        ),
        InputBox(
          label: 'Device ID',
          controller: _idController,
          hint: 'Enter device ID',
          errorText: _idError,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            FocusScope.of(context).nextFocus();
          },
        ),
        InputBox(
          label: 'Password',
          controller: _passwordController,
          hint: 'Enter password',
          errorText: _passwordError,
          isPassword: !_showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            _handleLogin();
          },
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF12376E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
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
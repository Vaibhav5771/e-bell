import 'package:e_bell/authentication/termsandconditions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_text_styles.dart';
import 'auth_service.dart';
import '../pages/device_page.dart';
import 'auth_state.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onTap;

  const RegisterScreen({super.key, required this.onTap});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ssidController = TextEditingController();
  final _devicePasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _ssidController.dispose();
    _devicePasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
        _ssidController.text.trim(),
        _devicePasswordController.text.trim(),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authState = Provider.of<AuthState>(context, listen: false);
        authState.setUser(
          user.uid,
          _emailController.text.trim(),
          _usernameController.text.trim(),
          'assets/avatar_1.png',
          isNewUser: true,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration failed: ${e.toString()}',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 80),

              // Illustration
              SizedBox(
                height: 250,
                child: Image.asset(
                  'assets/illustration.png',
                  fit: BoxFit.contain,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 50),

                    // ===== PERSONAL DETAILS =====
                    Text("Personal Details", style: AppTextStyles.subheading),
                    const SizedBox(height: 16),

                    // Username
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: AppTextStyles.small.copyWith(color: Colors.grey[700]!),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: AppTextStyles.small.copyWith(color: Colors.grey[700]!),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: AppTextStyles.small.copyWith(color: Colors.grey[700]!),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ===== DEVICE DETAILS =====
                    Text("Device Details", style: AppTextStyles.subheading),
                    const SizedBox(height: 16),

                    // SSID
                    TextField(
                      controller: _ssidController,
                      decoration: InputDecoration(
                        labelText: 'SSID',
                        labelStyle: AppTextStyles.small.copyWith(color: Colors.grey[700]!),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Device Password
                    TextField(
                      controller: _devicePasswordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Device Password',
                        labelStyle: AppTextStyles.small.copyWith(color: Colors.grey[700]!),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Register button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Register', style: AppTextStyles.button),
                    ),
                    const SizedBox(height: 16),

                    // Login link
                    Center(
                      child: TextButton(
                        onPressed: widget.onTap,
                        child: Text(
                          'Already have an account? Login',
                          style: AppTextStyles.link,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Logo + Version
                    Center(
                      child: Column(
                        children: [
                          Image.asset('assets/iogicon.png', height: 60),
                          const SizedBox(height: 10),
                          Text(
                            'EBELL_Version_V.3.0',
                            style: AppTextStyles.small.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cropsync/main.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/widgets/keyboard.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pin = _pinController.text.trim();

      // 1. Call the function to get the secure token
      final response = await supabase.functions.invoke(
        'login-with-pin',
        body: {'pin': pin},
      );

      if (response.status != 200) {
        final errorMessage =
            response.data?['error'] ?? 'An unknown error occurred.';
        throw Exception(errorMessage);
      }

      // 2. Parse the full response from the function
      final responseData = response.data as Map<String, dynamic>;
      final properties = responseData['properties'] as Map<String, dynamic>?;
      final user = responseData['user'] as Map<String, dynamic>?;

      final email = user?['email'] as String?;
      final token = properties?['email_otp'] as String?;

      if (email == null || token == null) {
        throw Exception(
            'Invalid response from server. Token or email missing.');
      }

      // 3. Use the token to verify the OTP and create the session
      await supabase.auth.verifyOTP(
        type: OtpType.magiclink,
        email: email,
        token: token,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      _showErrorSnackbar(
          'Login failed: ${error.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lexend()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Kiosk Login',
                  style: GoogleFonts.lexend(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please enter your unique PIN to continue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _pinController,
                  readOnly: true,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a PIN';
                    }
                    if (value.length != 6) {
                      return 'PIN must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                NumericKeypad(controller: _pinController),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            'Login',
                            style: GoogleFonts.lexend(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
}

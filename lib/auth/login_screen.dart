import 'package:cropsync/main.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/widgets/keyboard.dart';
import 'package:cropsync/widgets/mosern_toast.dart';
import 'package:cropsync/widgets/pin_input_field.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
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
  final GlobalKey<PinInputFieldState> _pinFieldKey =
      GlobalKey<PinInputFieldState>();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!(_pinFieldKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pin = _pinController.text.trim();
      final response = await supabase.functions.invoke(
        'login-with-pin',
        body: {'pin': pin},
      );

      if (response.status != 200) {
        final errorMessage =
            response.data?['error'] ?? 'An unknown error occurred.';
        throw Exception(errorMessage);
      }

      final responseData = response.data as Map<String, dynamic>;
      final properties = responseData['properties'] as Map<String, dynamic>?;
      final user = responseData['user'] as Map<String, dynamic>?;

      final email = user?['email'] as String?;
      final token = properties?['email_otp'] as String?;

      if (email == null || token == null) {
        throw Exception(
            'Invalid response from server. Token or email missing.');
      }

      await supabase.auth.verifyOTP(
        type: OtpType.magiclink,
        email: email,
        token: token,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      // --- THIS IS THE UPDATED PART ---
      // Display a modern, top-aligned toast notification for errors.
      String displayMessage = 'Login failed. Please try again later.';
      if (error.toString().contains('Invalid PIN provided')) {
        displayMessage = 'The PIN you entered is incorrect. Please try again.';
      }
      // Call the new modern toast
      if (mounted) {
        showModernErrorToast(context, displayMessage);
      }
      // --- END OF UPDATE ---
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // The old _showErrorSnackbar method has been removed.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ScrollConfiguration(
            behavior: NoOverscrollGlowBehavior(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Lottie.asset(
                      'assets/lottie/farmer.json',
                      height: 120,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Kiosk Login',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please enter your unique PIN to continue.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 48),
                    PinInputField(
                      key: _pinFieldKey,
                      controller: _pinController,
                      filledColors: [
                        Colors.teal.shade100,
                        Colors.teal.shade200,
                        Colors.green.shade200,
                        Colors.green.shade300,
                        Colors.lightGreen.shade300,
                        Colors.lightGreen.shade400,
                      ],
                      emptyColor: Colors.grey.shade100,
                      borderColor: Colors.grey.shade300,
                      activeBorderColor: Colors.green.shade500,
                      textColor: Colors.black54,
                    ),
                    const SizedBox(height: 32),
                    // This now uses the animated keypad
                    NumericKeypad(
                      controller: _pinController,
                      onEnter: _login,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.green.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Login',
                                style: GoogleFonts.lexend(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
}

class NoOverscrollGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

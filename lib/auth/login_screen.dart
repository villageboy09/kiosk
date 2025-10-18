import 'package:cropsync/main.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final pin = _pinController.text.trim();

    if (pin.length != 6) {
      _showErrorFeedback('PIN must be 6 digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
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
      String displayMessage = 'Login failed. Please try again later.';
      if (error.toString().contains('Invalid PIN provided')) {
        displayMessage = 'The PIN you entered is incorrect. Please try again.';
      }
      _showErrorFeedback(displayMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorFeedback(String message) {
    _shakeController.forward(from: 0);
    _pinController.clear();
    setState(() {
      _errorMessage = message;
    });

    // Hide the error chip after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32.0, vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 60),
                          _buildPinInput(),
                          const SizedBox(height: 40),
                          _buildKeypad(),
                          const SizedBox(height: 36),
                          _buildLoginButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildErrorChip(),
        ],
      ),
    );
  }

  Widget _buildErrorChip() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      top: _errorMessage != null ? 16 : -100,
      right: 16,
      child: SafeArea(
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: Colors.redAccent.shade200,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  _errorMessage ?? '',
                  style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade100.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Lottie.asset(
              'assets/lottie/farmer.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome Back',
            style: GoogleFonts.lexend(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your secure PIN to continue',
            style: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinInput() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pinController, _shakeController]),
      builder: (context, child) {
        final pinLength = _pinController.text.length;
        // Calculate shake offset
        final shakeOffset = Matrix4.translationValues(
            12 * (0.5 - (0.5 - _shakeAnimation.value).abs()) * 2, 0, 0);

        Widget buildDot(int index) {
          final isFilled = index < pinLength;
          final isActive = index == pinLength;
          return _buildPinDot(index, isFilled, isActive);
        }

        return Transform(
          transform: shakeOffset,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildDot(0),
              const SizedBox(width: 8),
              buildDot(1),
              const SizedBox(width: 8),
              buildDot(2),
              const SizedBox(width: 10),
              _buildSeparator(),
              const SizedBox(width: 10),
              buildDot(3),
              const SizedBox(width: 8),
              buildDot(4),
              const SizedBox(width: 8),
              buildDot(5),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeparator() {
    return Container(
      width: 8,
      alignment: Alignment.center,
      child: const Text(
        '•',
        style: TextStyle(
          color: Color(0xFFE0E0E0), // Colors.grey.shade300
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPinDot(int index, bool isFilled, bool isActive) {
    final colors = [
      Colors.green.shade300,
      Colors.green.shade400,
      Colors.green.shade500,
      Colors.green.shade600,
      Colors.green.shade700,
      Colors.green.shade800,
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 48,
      height: 68,
      decoration: BoxDecoration(
        color: isFilled
            ? colors[index].withValues(alpha: 0.12)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? Colors.green.shade500
              : isFilled
                  ? colors[index].withValues(alpha: 0.3)
                  : Colors.grey.shade200,
          width: isActive ? 2.5 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.green.shade300.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: isFilled
              ? Icon(
                  Icons.circle,
                  key: ValueKey(index),
                  size: 16,
                  color: colors[index],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKeypadButton(
                onTap: _login,
                child: Icon(Icons.check_rounded,
                    color: Colors.green.shade600, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKeypadButton(
                onTap: () => _onNumberPressed('0'),
                child: Text(
                  '0',
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKeypadButton(
                onTap: _onBackspacePressed,
                child: Icon(Icons.backspace_outlined,
                    color: Colors.grey.shade600, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      children: numbers.map((number) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildKeypadButton(
              onTap: () => _onNumberPressed(number),
              child: Text(
                number,
                style: GoogleFonts.lexend(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton(
      {required VoidCallback onTap, required Widget child}) {
    return FluidKeypadButton(onTap: onTap, child: child);
  }

  Widget _buildLoginButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: _isLoading
              ? [Colors.grey.shade300, Colors.grey.shade400]
              : [Colors.green.shade500, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: Colors.green.shade300.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _login,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Continue',
                    style: GoogleFonts.lexend(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String value) {
    if (_pinController.text.length < 6) {
      setState(() {
        _pinController.text += value;
      });
    }
  }

  void _onBackspacePressed() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text =
            _pinController.text.substring(0, _pinController.text.length - 1);
      });
    }
  }
}

// Fluid Keypad Button with buttery smooth animations
class FluidKeypadButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const FluidKeypadButton({
    super.key,
    required this.onTap,
    required this.child,
  });

  @override
  State<FluidKeypadButton> createState() => _FluidKeypadButtonState();
}

class _FluidKeypadButtonState extends State<FluidKeypadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300.withValues(alpha: 0.4),
                    blurRadius: 12 + _elevationAnimation.value,
                    spreadRadius: 0,
                    offset: Offset(0, 4 + _elevationAnimation.value / 2),
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

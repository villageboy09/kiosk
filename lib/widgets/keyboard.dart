import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// This is the new animated button widget
class AnimatedKeypadButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget? child;
  final String? text;

  const AnimatedKeypadButton({
    super.key,
    required this.onTap,
    this.child,
    this.text,
  }) : assert(child != null || text != null);

  @override
  State<AnimatedKeypadButton> createState() => _AnimatedKeypadButtonState();
}

class _AnimatedKeypadButtonState extends State<AnimatedKeypadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.child ??
                Text(
                  widget.text!,
                  style: GoogleFonts.lexend(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

// The NumericKeypad now uses the animated button
class NumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnter;

  const NumericKeypad({
    super.key,
    required this.controller,
    required this.onEnter,
  });

  void _onNumberPressed(String value) {
    if (controller.text.length < 6) {
      controller.text += value;
    }
  }

  void _onBackspacePressed() {
    if (controller.text.isNotEmpty) {
      controller.text =
          controller.text.substring(0, controller.text.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildButton('1'),
            _buildButton('2'),
            _buildButton('3'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildButton('4'),
            _buildButton('5'),
            _buildButton('6'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildButton('7'),
            _buildButton('8'),
            _buildButton('9'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Using the 'child' property for icons
            _buildButtonWithChild(
              onTap: onEnter,
              child: const Icon(Icons.check, color: Colors.green, size: 28),
            ),
            _buildButton('0'),
            _buildButtonWithChild(
              onTap: _onBackspacePressed,
              child: const Icon(Icons.backspace_outlined,
                  color: Colors.black54, size: 24),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(String text) {
    return Expanded(
      child: AnimatedKeypadButton(
        text: text,
        onTap: () => _onNumberPressed(text),
      ),
    );
  }

  Widget _buildButtonWithChild(
      {required Widget child, required VoidCallback onTap}) {
    return Expanded(
      child: AnimatedKeypadButton(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

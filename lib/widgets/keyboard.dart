import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NumericKeypad extends StatelessWidget {
  final TextEditingController controller;

  const NumericKeypad({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildButton('1'),
            _buildButton('2'),
            _buildButton('3'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildButton('4'),
            _buildButton('5'),
            _buildButton('6'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildButton('7'),
            _buildButton('8'),
            _buildButton('9'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 70), // Placeholder for alignment
            _buildButton('0'),
            _buildBackspaceButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(String text) {
    return SizedBox(
      width: 70,
      height: 70,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          if (controller.text.length < 6) {
            controller.text += text;
          }
        },
        child: Text(
          text,
          style: GoogleFonts.lexend(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return SizedBox(
      width: 70,
      height: 70,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          if (controller.text.isNotEmpty) {
            controller.text =
                controller.text.substring(0, controller.text.length - 1);
          }
        },
        icon: const Icon(Icons.backspace_outlined, color: Colors.black),
      ),
    );
  }
}

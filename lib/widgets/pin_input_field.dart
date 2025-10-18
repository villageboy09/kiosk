import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinInputField extends StatefulWidget {
  final TextEditingController controller;
  final int pinLength;
  final List<Color> filledColors; // NEW: Accepts a list of colors
  final double fieldWidth;
  final double fieldHeight;
  final double spacing;
  final Color emptyColor;
  final Color borderColor;
  final Color activeBorderColor;
  final Color textColor;
  final double borderRadius;

  const PinInputField({
    super.key,
    required this.controller,
    this.pinLength = 6,
    this.fieldWidth = 50,
    this.fieldHeight = 60,
    this.spacing = 8,
    // NEW: Default list of colors for the fill effect
    this.filledColors = const [Colors.green],
    // NEW: Default colors updated for a light theme
    this.emptyColor = const Color(0xFFF1F1F1),
    this.borderColor = const Color(0xFFD9D9D9),
    this.activeBorderColor = Colors.green,
    this.textColor = Colors.black87,
    this.borderRadius = 8.0,
    required bool autofocus,
  });

  @override
  State<PinInputField> createState() => PinInputFieldState();
}

class PinInputFieldState extends State<PinInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_errorText != null && widget.controller.text.isNotEmpty) {
      setState(() {
        _errorText = null;
      });
    }
    setState(() {});
  }

  bool validate() {
    String? validationMessage = _validator(widget.controller.text);
    setState(() {
      _errorText = validationMessage;
    });
    return validationMessage == null;
  }

  String? _validator(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN cannot be empty.';
    }
    if (value.length != widget.pinLength) {
      return 'PIN must be ${widget.pinLength} digits.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (index) {
            bool isFilled = index < widget.controller.text.length;

            // NEW: Selects color from the list. Uses modulo to cycle through colors
            // if the list is shorter than the pin length.
            Color currentFilledColor = isFilled
                ? widget.filledColors[index % widget.filledColors.length]
                : widget.emptyColor;

            // Inserts a dash in the middle for 6-digit PINs
            if (widget.pinLength == 6 && index == 3) {
              return Row(
                children: [
                  Container(
                    width: 16,
                    alignment: Alignment.center,
                    child: Text(
                      '-',
                      style: GoogleFonts.lexend(
                          color: Colors.grey.shade400,
                          fontSize: 30,
                          fontWeight: FontWeight.w300),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPinSegment(index, isFilled, currentFilledColor),
                ],
              );
            }
            return _buildPinSegment(index, isFilled, currentFilledColor);
          }),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorText!,
            style: GoogleFonts.lexend(
              color: Colors.redAccent,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPinSegment(int index, bool isFilled, Color segmentColor) {
    bool isActive = index == widget.controller.text.length ||
        (index == widget.pinLength - 1 && isFilled);

    Color currentBorderColor = _errorText != null
        ? Colors.redAccent
        : (isActive ? widget.activeBorderColor : widget.borderColor);

    return Container(
      width: widget.fieldWidth,
      height: widget.fieldHeight,
      margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
      decoration: BoxDecoration(
        color: segmentColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: currentBorderColor,
          width: 2,
        ),
        boxShadow: isActive && _errorText == null
            ? [
                BoxShadow(
                  color: widget.activeBorderColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      alignment: Alignment.center,
      child: isFilled
          ? Text(
              '●',
              style: GoogleFonts.lexend(
                color: widget.textColor,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

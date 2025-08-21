import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cropsync Dashboard',
          style: GoogleFonts.lexend(),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: Text(
          'Welcome to your Kiosk!',
          style: GoogleFonts.lexend(fontSize: 24),
        ),
      ),
    );
  }
}

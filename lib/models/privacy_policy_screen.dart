// lib/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final String url;
  const PrivacyPolicyScreen({super.key, required this.url});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false; // Track if URL loading failed

  @override
  void initState() {
    super.initState();

    // --- FIX for WebView Assertion ---
    // Ensure the URL is valid before trying to load it
    final Uri? initialUri = Uri.tryParse(widget.url);

    if (initialUri == null ||
        !initialUri.hasScheme ||
        !initialUri.hasAuthority) {
      debugPrint('❌ Invalid URL passed to WebView: ${widget.url}');
      // If URL is invalid, set error state immediately
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      // Initialize controller without loading to avoid assertion
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white);
      return; // Stop initialization here
    }
    // --- End Fix ---

    // If URL is valid, proceed with normal initialization
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = false; // Reset error on success
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web resource error: ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true; // Set error state on failure
              });
            }
          },
          // Optional: Handle navigation requests if needed
          // onNavigationRequest: (NavigationRequest request) {
          //   if (request.url.startsWith('https://www.youtube.com/')) {
          //     return NavigationDecision.prevent;
          //   }
          //   return NavigationDecision.navigate;
          // },
        ),
      )
      ..loadRequest(initialUri); // Load the validated URI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF282C3F),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF282C3F),
      ),
      body: Stack(
        children: [
          // Only show WebView if there's no error
          if (!_hasError) WebViewWidget(controller: _controller),
          // Show loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF60B246)),
            ),
          // Show error message if URL was invalid or failed to load
          if (_hasError && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Could not load the Privacy Policy.\nPlease check your connection or contact support.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

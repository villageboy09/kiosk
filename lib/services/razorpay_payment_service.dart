import 'dart:convert';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback type for payment completion
typedef PaymentCallback = void Function(RazorpayPaymentResult result);

/// Production Razorpay Payment Service for CropSync In-App Purchases.
/// Securely creates orders on the backend server and verifies HMAC SHA256 signatures
/// using the server's RAZORPAY_KEY_SECRET before crediting scans.
class RazorpayPaymentService {
  late final Razorpay _razorpay;
  PaymentCallback? _onResult;
  String? _currentUserId;

  RazorpayPaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Resolves and sanitizes the user's 10-digit Indian mobile number across all session sources
  /// to guarantee automatic autofill during Razorpay checkout.
  static Future<String> resolveUserPhoneNumber({String? fallbackPhone}) async {
    // 1. If explicit phone was passed, sanitize and validate
    if (fallbackPhone != null && fallbackPhone.trim().isNotEmpty) {
      final sanitized = sanitizeIndianPhoneNumber(fallbackPhone);
      if (sanitized.isNotEmpty) return sanitized;
    }

    // 2. Check AuthService in-memory session
    var user = AuthService.currentUser;
    if (user == null) {
      try {
        user = await AuthService.loadUserSession();
      } catch (_) {}
    }

    if (user != null) {
      if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
        final sanitized = sanitizeIndianPhoneNumber(user.phoneNumber!);
        if (sanitized.isNotEmpty) return sanitized;
      }
      // Often in CropSync userId is the farmer's 10-digit mobile number
      final sanitizedUid = sanitizeIndianPhoneNumber(user.userId);
      if (sanitizedUid.isNotEmpty) return sanitizedUid;
    }

    // 3. Check SharedPreferences direct keys
    try {
      final prefs = await SharedPreferences.getInstance();
      final candidates = [
        prefs.getString('phone_number'),
        prefs.getString('phoneNumber'),
        prefs.getString('phone'),
        prefs.getString('user_phone'),
        prefs.getString('mobile'),
        prefs.getString('user_id'),
        prefs.getString('userId'),
      ];

      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          final sanitized = sanitizeIndianPhoneNumber(candidate);
          if (sanitized.isNotEmpty) return sanitized;
        }
      }

      // 4. Check SharedPreferences 'current_user' JSON
      final userJson = prefs.getString('current_user');
      if (userJson != null && userJson.trim().isNotEmpty) {
        try {
          final data = jsonDecode(userJson) as Map<String, dynamic>;
          final phone = data['phone_number']?.toString() ?? data['phone']?.toString();
          if (phone != null) {
            final sanitized = sanitizeIndianPhoneNumber(phone);
            if (sanitized.isNotEmpty) return sanitized;
          }
          final uid = data['user_id']?.toString();
          if (uid != null) {
            final sanitized = sanitizeIndianPhoneNumber(uid);
            if (sanitized.isNotEmpty) return sanitized;
          }
        } catch (_) {}
      }
    } catch (_) {}

    return '';
  }

  /// Extracts a clean 10-digit Indian mobile number suitable for Razorpay contact prefill
  static String sanitizeIndianPhoneNumber(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      return digits;
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return '';
  }

  /// Initiates secure payment for AI Doctor Credits (₹1 = 10 Credits).
  /// Automatically resolves and autofills the user's mobile number.
  /// 1. Calls CropSync server to generate a Razorpay Order ID.
  /// 2. Opens the Razorpay Checkout UI with the generated order ID.
  /// 3. On success, validates the HMAC SHA256 signature with the server's Secret Key.
  Future<void> purchaseCredits({
    required int amountInr,
    String? userPhone,
    String userEmail = '',
    required PaymentCallback onResult,
    String? userId,
    String description = "10 AI Crop Doctor Scans",
  }) async {
    _onResult = onResult;

    // Automatically resolve 10-digit mobile number for prefill autofill
    final effectivePhone = await resolveUserPhoneNumber(fallbackPhone: userPhone);

    _currentUserId = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : (effectivePhone.isNotEmpty ? effectivePhone : 'guest_farmer');

    // 1. Request server-side order creation
    debugPrint("🌐 Razorpay: Requesting server-side order creation for user $_currentUserId (phone: $effectivePhone)...");
    final orderRes = await ApiService.createRazorpayOrder(
      userId: _currentUserId!,
      amountInr: amountInr,
      credits: 10,
    );

    if (orderRes['success'] != true || orderRes['order_id'] == null) {
      final err = orderRes['error'] ?? 'Failed to create payment order on server.';
      debugPrint("❌ Razorpay order creation failed: $err");
      onResult(RazorpayPaymentResult(
        isSuccess: false,
        errorMessage: err,
      ));
      return;
    }

    final serverOrderId = orderRes['order_id'] as String;
    final serverKeyId = (orderRes['key_id'] as String?)?.trim();
    final envKeyId = dotenv.env['RAZORPAY_KEY_ID']?.trim();

    final keyId = (serverKeyId != null && serverKeyId.isNotEmpty && !serverKeyId.contains('your_key_id'))
        ? serverKeyId
        : (envKeyId ?? '');

    if (keyId.isEmpty) {
      debugPrint("⚠️ Razorpay Key ID not found in server response or client .env");
      onResult(RazorpayPaymentResult(
        isSuccess: false,
        errorMessage: "Razorpay Key is not configured. Please set RAZORPAY_KEY_ID on the server or in .env",
      ));
      return;
    }

    // Razorpay amount in paise (1 INR = 100 paise)
    final amountInPaise = amountInr * 100;

    final options = {
      'key': keyId,
      'amount': amountInPaise,
      'order_id': serverOrderId, // Link with server-generated order
      'name': 'CropSync',
      'description': description,
      'timeout': 180, // 3 minutes
      'prefill': {
        if (effectivePhone.isNotEmpty) 'contact': effectivePhone,
        if (userEmail.isNotEmpty) 'email': userEmail,
      },
      'theme': {
        'color': '#2E7D32', // CropSync Brand Green
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Razorpay open error: $e");
      onResult(RazorpayPaymentResult(
        isSuccess: false,
        errorMessage: "Failed to open payment gateway: $e",
      ));
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint("✅ Razorpay Payment Succeeded on Device: ${response.paymentId}");
    debugPrint("🔐 Verifying cryptographic HMAC signature on server with Secret Key...");

    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? '';
    final signature = response.signature ?? '';

    // Verify cryptographic signature with server-stored Secret Key
    final verifyRes = await ApiService.verifyRazorpayPayment(
      userId: _currentUserId ?? 'guest_farmer',
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );

    if (verifyRes['success'] == true) {
      debugPrint("🎉 Server verification successful! Credits confirmed on server.");
      _onResult?.call(RazorpayPaymentResult(
        isSuccess: true,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        creditsAdded: (verifyRes['credits_added'] as num?)?.toInt() ?? 10,
        totalPurchased: (verifyRes['total_purchased'] as num?)?.toInt(),
      ));
    } else {
      final err = verifyRes['error'] ?? "Server payment signature verification failed.";
      debugPrint("❌ Server signature verification rejected: $err");
      _onResult?.call(RazorpayPaymentResult(
        isSuccess: false,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        errorMessage: err,
      ));
    }
    _onResult = null;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Razorpay Payment Error (${response.code}): ${response.message}");
    _onResult?.call(RazorpayPaymentResult(
      isSuccess: false,
      errorCode: response.code,
      errorMessage: response.message ?? "Payment cancelled or failed.",
    ));
    _onResult = null;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("👛 Razorpay External Wallet: ${response.walletName}");
    _onResult?.call(RazorpayPaymentResult(
      isSuccess: false,
      walletName: response.walletName,
      errorMessage: "External wallet selected (${response.walletName}). Complete payment in wallet.",
    ));
  }

  /// Clean up Razorpay event listeners
  void dispose() {
    _razorpay.clear();
  }
}

class RazorpayPaymentResult {
  final bool isSuccess;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final int? errorCode;
  final String? errorMessage;
  final String? walletName;
  final int? creditsAdded;
  final int? totalPurchased;

  RazorpayPaymentResult({
    required this.isSuccess,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorCode,
    this.errorMessage,
    this.walletName,
    this.creditsAdded,
    this.totalPurchased,
  });
}

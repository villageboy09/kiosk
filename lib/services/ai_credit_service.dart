import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/services/api_service.dart';

/// Manages CropSync AI Plant Doctor daily free quota (10 free scans/day)
/// and purchased in-app credit balance (e.g., +10 scans for ₹1 via Razorpay).
class AiCreditService {
  static const int defaultDailyLimit = 10;
  static const int creditsPerPurchase = 10;
  static const int costPerPurchaseInr = 1; // ₹1

  /// Get current credit status for user
  static Future<CreditStatus> getCreditStatus({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _resolveUserId(userId, prefs);
    final todayStr = _getTodayDateString();

    final lastDate = prefs.getString('ai_credit_date_$uid') ?? '';
    int dailyUsed = prefs.getInt('ai_credit_daily_used_$uid') ?? 0;
    int purchasedCredits = prefs.getInt('ai_credit_purchased_$uid') ?? 0;

    // Reset daily counter if a new calendar day has started
    if (lastDate != todayStr) {
      dailyUsed = 0;
      await prefs.setString('ai_credit_date_$uid', todayStr);
      await prefs.setInt('ai_credit_daily_used_$uid', 0);
    }

    final dailyRemaining = (defaultDailyLimit - dailyUsed).clamp(0, defaultDailyLimit);
    final totalAvailable = dailyRemaining + purchasedCredits;

    return CreditStatus(
      dailyLimit: defaultDailyLimit,
      dailyUsed: dailyUsed,
      dailyRemaining: dailyRemaining,
      purchasedCredits: purchasedCredits,
      totalAvailable: totalAvailable,
      dateString: todayStr,
    );
  }

  /// Check if user can perform an analysis
  static Future<bool> canPerformAnalysis({String? userId}) async {
    final status = await getCreditStatus(userId: userId);
    return status.hasCredits;
  }

  /// Deducts 1 credit for an AI analysis scan.
  /// Free daily quota is consumed first. Once 10 free scans are exhausted,
  /// extra purchased credits are consumed.
  /// Returns true if credit was successfully consumed, false if insufficient credits.
  static Future<bool> consumeCredit({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _resolveUserId(userId, prefs);
    final todayStr = _getTodayDateString();

    final lastDate = prefs.getString('ai_credit_date_$uid') ?? '';
    int dailyUsed = prefs.getInt('ai_credit_daily_used_$uid') ?? 0;
    int purchasedCredits = prefs.getInt('ai_credit_purchased_$uid') ?? 0;

    // Reset daily if date changed
    if (lastDate != todayStr) {
      dailyUsed = 0;
      await prefs.setString('ai_credit_date_$uid', todayStr);
      await prefs.setInt('ai_credit_daily_used_$uid', 0);
    }

    if (dailyUsed < defaultDailyLimit) {
      // Consume free daily credit
      dailyUsed++;
      await prefs.setInt('ai_credit_daily_used_$uid', dailyUsed);
      debugPrint("🌾 AiCreditService: Consumed daily free scan ($dailyUsed/$defaultDailyLimit used)");
      return true;
    } else if (purchasedCredits > 0) {
      // Consume purchased credit
      purchasedCredits--;
      await prefs.setInt('ai_credit_purchased_$uid', purchasedCredits);
      debugPrint("⚡ AiCreditService: Consumed purchased scan ($purchasedCredits remaining)");
      return true;
    }

    debugPrint("⚠️ AiCreditService: Zero credits available for user $uid");
    return false;
  }

  /// Add purchased credits after a verified Razorpay payment (e.g. +10 scans for ₹1)
  static Future<CreditStatus> addPurchasedCredits(
    int count, {
    String? userId,
    String? paymentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _resolveUserId(userId, prefs);

    int currentPurchased = prefs.getInt('ai_credit_purchased_$uid') ?? 0;
    currentPurchased += count;
    await prefs.setInt('ai_credit_purchased_$uid', currentPurchased);

    if (paymentId != null && paymentId.isNotEmpty) {
      final history = prefs.getStringList('ai_payment_history_$uid') ?? [];
      history.add('${DateTime.now().toIso8601String()}|$paymentId|$count');
      await prefs.setStringList('ai_payment_history_$uid', history);
    }

    debugPrint("🎉 AiCreditService: Added +$count purchased credits to user $uid (Total purchased: $currentPurchased)");
    return getCreditStatus(userId: uid);
  }

  /// Sets or synchronizes purchased credits directly from the server
  static Future<CreditStatus> syncPurchasedCredits(
    int totalCount, {
    String? userId,
    String? paymentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _resolveUserId(userId, prefs);

    await prefs.setInt('ai_credit_purchased_$uid', totalCount);

    if (paymentId != null && paymentId.isNotEmpty) {
      final history = prefs.getStringList('ai_payment_history_$uid') ?? [];
      history.add('${DateTime.now().toIso8601String()}|$paymentId|sync:$totalCount');
      await prefs.setStringList('ai_payment_history_$uid', history);
    }

    debugPrint("🔄 AiCreditService: Synced purchased credits from server for user $uid (Total: $totalCount)");
    return getCreditStatus(userId: uid);
  }

  /// Fetches latest purchased credits balance directly from server API and persists locally
  static Future<CreditStatus> syncWithServer({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _resolveUserId(userId, prefs);

    if (uid.isNotEmpty && uid != 'guest_farmer') {
      try {
        final serverCredits = await ApiService.getAiCreditBalance(userId: uid);
        if (serverCredits != null) {
          await prefs.setInt('ai_credit_purchased_$uid', serverCredits);
          debugPrint("🔄 AiCreditService: Synced $serverCredits purchased credits from server for user $uid");
        }
      } catch (e) {
        debugPrint("AiCreditService: server sync error: $e");
      }
    }
    return getCreditStatus(userId: uid);
  }

  /// Resolves the user ID from parameters, SharedPreferences, or fallback
  static String _resolveUserId(String? userId, SharedPreferences prefs) {
    if (userId != null && userId.trim().isNotEmpty) {
      return userId.trim();
    }
    final storedUid = prefs.getString('user_id') ??
        prefs.getString('userId') ??
        prefs.getString('phone_number') ??
        prefs.getString('phone');
    if (storedUid != null && storedUid.trim().isNotEmpty) {
      return storedUid.trim();
    }

    // Try current_user JSON
    final userJson = prefs.getString('current_user');
    if (userJson != null && userJson.trim().isNotEmpty) {
      try {
        final data = jsonDecode(userJson) as Map<String, dynamic>;
        final uid = data['user_id']?.toString() ?? data['phone_number']?.toString();
        if (uid != null && uid.trim().isNotEmpty) {
          return uid.trim();
        }
      } catch (_) {}
    }

    return 'guest_farmer';
  }

  /// Get today's calendar date as YYYY-MM-DD
  static String _getTodayDateString() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class CreditStatus {
  final int dailyLimit;
  final int dailyUsed;
  final int dailyRemaining;
  final int purchasedCredits;
  final int totalAvailable;
  final String dateString;

  CreditStatus({
    required this.dailyLimit,
    required this.dailyUsed,
    required this.dailyRemaining,
    required this.purchasedCredits,
    required this.totalAvailable,
    required this.dateString,
  });

  bool get hasCredits => totalAvailable > 0;
  bool get hasFreeCreditsRemaining => dailyRemaining > 0;
  bool get isUsingPurchasedCredits => dailyRemaining == 0 && purchasedCredits > 0;
}

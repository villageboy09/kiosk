import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = ['en', 'hi', 'te'];
  final prefixes = [
    'shop_',
    'shopd_',
    'shopnew_',
    'buy_',
    'shoph_',
    'pd_',
    'seedui_',
    'seedd_',
    'mkt_',
    'mktui_',
    'mktd_',
  ];
  final data = <String, Map<String, dynamic>>{
    for (final l in locales)
      l: jsonDecode(File('assets/translations/$l.json').readAsStringSync())
          as Map<String, dynamic>,
  };

  bool isShop(String k) => prefixes.any(k.startsWith);
  final allKeys = {
    for (final l in locales) ...data[l]!.keys.where(isShop),
  };

  List<String> placeholders(String v) =>
      (RegExp(r'\{[^}]*\}').allMatches(v).map((m) => m.group(0)!).toList()
        ..sort());

  test('shop keys are present in every locale', () {
    expect(allKeys, isNotEmpty);
    for (final l in locales) {
      final missing = allKeys.where((k) => !data[l]!.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'missing in $l');
    }
  });

  test('shop values are non-empty strings', () {
    for (final l in locales) {
      for (final k in allKeys) {
        final v = data[l]![k];
        expect(v is String && v.trim().isNotEmpty, isTrue,
            reason: '$l.$k is empty');
      }
    }
  });

  test('placeholders match across locales', () {
    for (final k in allKeys) {
      final base = placeholders(data['en']![k] as String);
      for (final l in locales) {
        expect(placeholders(data[l]![k] as String), base,
            reason: 'placeholder mismatch for $k in $l');
      }
    }
  });
}

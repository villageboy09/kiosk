import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropsync/utils/commodity_translator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Market Prices Multi-language & Commodity Translation Tests', () {
    const marketKeys = [
      'market_prices_title',
      'commodities_in_district',
      'market_prices_in_state',
      'markets_for_commodity',
      'variety_label_with_val',
      'price_trends',
      'avg_across_state',
      'market_per_quintal',
      'fetching_state_prices',
      'no_prices_for_state',
      'error_fetching_prices',
      'no_market_prices',
      'last_updated',
    ];

    test('All market translation keys exist and are non-empty in en.json', () {
      final file = File('assets/translations/en.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      for (final k in marketKeys) {
        expect(jsonMap.containsKey(k), isTrue, reason: 'Missing $k in en.json');
        expect(jsonMap[k].toString().trim().isNotEmpty, isTrue, reason: 'Empty $k in en.json');
      }
    });

    test('All market translation keys exist and are non-empty in te.json', () {
      final file = File('assets/translations/te.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      for (final k in marketKeys) {
        expect(jsonMap.containsKey(k), isTrue, reason: 'Missing $k in te.json');
        expect(jsonMap[k].toString().trim().isNotEmpty, isTrue, reason: 'Empty $k in te.json');
      }
    });

    test('All market translation keys exist and are non-empty in hi.json', () {
      final file = File('assets/translations/hi.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      for (final k in marketKeys) {
        expect(jsonMap.containsKey(k), isTrue, reason: 'Missing $k in hi.json');
        expect(jsonMap[k].toString().trim().isNotEmpty, isTrue, reason: 'Empty $k in hi.json');
      }
    });

    test('CommodityTranslator translates accurately in Telugu', () {
      expect(CommodityTranslator.getLocalizedName('Tomato', 'te'), 'టమోటా');
      expect(CommodityTranslator.getLocalizedName('Cotton', 'te'), 'పత్తి');
      expect(CommodityTranslator.getLocalizedName('Paddy(Dhan)(Common)', 'te'), 'వరి (సాధారణ ధాన్యం)');
      expect(CommodityTranslator.getLocalizedName('Chilli Red', 'te'), 'ఎర్ర మిరప');
      expect(CommodityTranslator.getLocalizedName('Maize', 'te'), 'మొక్కజొన్న');
      expect(CommodityTranslator.getLocalizedName('Groundnut', 'te'), 'వేరుశనగ');
      expect(CommodityTranslator.getLocalizedName('Turmeric', 'te'), 'పసుపు');
      expect(CommodityTranslator.getLocalizedName('Red Gram (Tur/Arhar)', 'te'), 'కందులు');
      expect(CommodityTranslator.getLocalizedName('Bengal Gram(Gram)(Whole)', 'te'), 'శనగలు');
    });

    test('CommodityTranslator translates accurately in Hindi', () {
      expect(CommodityTranslator.getLocalizedName('Tomato', 'hi'), 'टमाटर');
      expect(CommodityTranslator.getLocalizedName('Cotton', 'hi'), 'कपास');
      expect(CommodityTranslator.getLocalizedName('Paddy(Dhan)(Common)', 'hi'), 'धान (सामान्य)');
      expect(CommodityTranslator.getLocalizedName('Chilli Red', 'hi'), 'लाल मिर्च');
      expect(CommodityTranslator.getLocalizedName('Maize', 'hi'), 'मक्का');
      expect(CommodityTranslator.getLocalizedName('Groundnut', 'hi'), 'मूंगफली');
      expect(CommodityTranslator.getLocalizedName('Turmeric', 'hi'), 'हल्दी');
      expect(CommodityTranslator.getLocalizedName('Red Gram (Tur/Arhar)', 'hi'), 'अरहर / तूर');
      expect(CommodityTranslator.getLocalizedName('Bengal Gram(Gram)(Whole)', 'hi'), 'चना (साबुत)');
    });

    test('CommodityTranslator returns English name unchanged for English locale or unknown', () {
      expect(CommodityTranslator.getLocalizedName('Tomato', 'en'), 'Tomato');
      expect(CommodityTranslator.getLocalizedName('Cotton', 'en'), 'Cotton');
      expect(CommodityTranslator.getLocalizedName('Rare Exotic Fruit', 'te'), 'Rare Exotic Fruit');
    });

    test('Translation files have zero duplicate keys', () {
      for (final lang in ['en', 'te', 'hi']) {
        final lines = File('assets/translations/$lang.json').readAsLinesSync();
        final seenKeys = <String>{};
        final duplicateKeys = <String>[];
        final keyRegex = RegExp(r'^\s*"([^"]+)"\s*:');

        for (final line in lines) {
          final match = keyRegex.firstMatch(line);
          if (match != null) {
            final key = match.group(1)!;
            if (seenKeys.contains(key)) {
              duplicateKeys.add(key);
            } else {
              seenKeys.add(key);
            }
          }
        }

        expect(duplicateKeys, isEmpty, reason: 'Duplicate keys found in $lang.json: $duplicateKeys');
      }
    });
  });
}

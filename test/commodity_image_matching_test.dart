import 'package:flutter_test/flutter_test.dart';
import 'package:cropsync/utils/commodity_translator.dart';

void main() {
  group('CommodityTranslator.resolveImageUrl Tests', () {
    test('Resolves complex Agmarknet Mandi names with parentheses', () {
      expect(
        CommodityTranslator.resolveImageUrl('Paddy(Dhan)(Common)'),
        'https://kiosk.cropsync.in/api/commodity/Rice.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Bhindi(Ladies Finger)'),
        'https://kiosk.cropsync.in/crops/okra.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Bengal Gram(Gram)(Whole)'),
        'https://kiosk.cropsync.in/api/commodity/Soyabean.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Red Gram (Arhar/Tur)'),
        'https://kiosk.cropsync.in/api/commodity/Soyabean.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Green Gram (Moong)'),
        'https://kiosk.cropsync.in/api/commodity/Soyabean.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Black Gram(Urd Beans)(Whole)'),
        'https://kiosk.cropsync.in/api/commodity/Soyabean.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Mousambi(Sweet Lime)'),
        'https://kiosk.cropsync.in/api/commodity/Lime.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Ridgeguard(Tori)'),
        'https://kiosk.cropsync.in/crops/bitter_gourd.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Sesamum(Sesame,Gingelly,Til)'),
        'https://kiosk.cropsync.in/api/commodity/Linseed.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Jowar(Sorghum)'),
        'https://kiosk.cropsync.in/api/commodity/Maize.png',
      );
    });

    test('Resolves variations of chillies and gourds', () {
      expect(
        CommodityTranslator.resolveImageUrl('Chilli Red'),
        'https://kiosk.cropsync.in/crops/chilli.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Green Chilli'),
        'https://kiosk.cropsync.in/crops/chilli.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Dry Chillies'),
        'https://kiosk.cropsync.in/crops/chilli.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Bitter gourd'),
        'https://kiosk.cropsync.in/crops/bitter_gourd.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('Little gourd(Kundru)'),
        'https://kiosk.cropsync.in/crops/bitter_gourd.jpg',
      );
    });

    test('Resolves regional Telugu and Hindi names', () {
      expect(
        CommodityTranslator.resolveImageUrl('వరి (ధాన్యం)'),
        'https://kiosk.cropsync.in/api/commodity/Rice.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('టమోటా'),
        'https://kiosk.cropsync.in/api/commodity/Tomato.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('బెండకాయ'),
        'https://kiosk.cropsync.in/crops/okra.jpg',
      );
      expect(
        CommodityTranslator.resolveImageUrl('धान'),
        'https://kiosk.cropsync.in/api/commodity/Rice.png',
      );
      expect(
        CommodityTranslator.resolveImageUrl('टमाटर'),
        'https://kiosk.cropsync.in/api/commodity/Tomato.png',
      );
    });

    test('Prioritizes explicitUrl when provided and valid', () {
      expect(
        CommodityTranslator.resolveImageUrl(
          'Tomato',
          explicitUrl: 'https://custom.server.com/custom_tomato.png',
        ),
        'https://custom.server.com/custom_tomato.png',
      );
    });
  });
}

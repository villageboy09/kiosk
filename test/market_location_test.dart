import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/utils/market_aliases.dart';

LocationDeps deps({
  bool enabled = true,
  LocationPermission check = LocationPermission.whileInUse,
  LocationPermission request = LocationPermission.whileInUse,
  GeoFix? last,
  Future<GeoFix> Function(Duration)? current,
  Future<List<Placemark>> Function(double, double)? placemarks,
  List<String>? log,
  Future<void> Function(String)? setLocale,
}) {
  final now = DateTime(2026, 1, 1, 12);
  return LocationDeps(
    isServiceEnabled: () async => enabled,
    checkPermission: () async => check,
    requestPermission: () async {
      log?.add('request');
      return request;
    },
    lastKnown: () async => last,
    current: current ?? (_) async => GeoFix(17.4, 78.4, now),
    placemarks: placemarks ??
        (a, b) async => [
              const Placemark(
                  administrativeArea: 'Telangana',
                  subAdministrativeArea: 'Rangareddy',
                  locality: 'Shamshabad'),
            ],
    now: () => now,
    setGeocoderLocale: setLocale,
  );
}

void main() {
  group('resolveMarketLocation', () {
    test('service disabled', () async {
      final r = await LocationService.resolveMarketLocation(
          deps: deps(enabled: false));
      expect(r.failure, MarketLocationFailure.serviceDisabled);
      expect(r.location, isNull);
    });

    test('denied then request denied', () async {
      final log = <String>[];
      final r = await LocationService.resolveMarketLocation(
          deps: deps(
              check: LocationPermission.denied,
              request: LocationPermission.denied,
              log: log));
      expect(r.failure, MarketLocationFailure.permissionDenied);
      expect(log, ['request']);
    });

    test('denied then granted', () async {
      final r = await LocationService.resolveMarketLocation(
          deps: deps(check: LocationPermission.denied));
      expect(r.location?.district, 'Rangareddy');
    });

    test('deniedForever never requests', () async {
      final log = <String>[];
      final r = await LocationService.resolveMarketLocation(
          deps: deps(check: LocationPermission.deniedForever, log: log));
      expect(r.failure, MarketLocationFailure.permissionDeniedForever);
      expect(log, isEmpty);
    });

    test('gps timeout -> timeout failure', () async {
      final r = await LocationService.resolveMarketLocation(
          gpsTimeout: const Duration(milliseconds: 50),
          deps: deps(current: (_) => Completer<GeoFix>().future));
      expect(r.failure, MarketLocationFailure.timeout);
    });

    test('gps timeout falls back to stale last known', () async {
      final stale = GeoFix(17.0, 78.0, DateTime(2025, 1, 1));
      final r = await LocationService.resolveMarketLocation(
          gpsTimeout: const Duration(milliseconds: 50),
          deps: deps(last: stale, current: (_) => Completer<GeoFix>().future));
      expect(r.location?.lat, 17.0);
    });

    test('fresh last known skips current position', () async {
      var called = false;
      final fresh = GeoFix(16.0, 79.0, DateTime(2026, 1, 1, 11, 50));
      final r = await LocationService.resolveMarketLocation(
          deps: deps(
              last: fresh,
              current: (_) async {
                called = true;
                return const GeoFix(0, 0);
              }));
      expect(called, isFalse);
      expect(r.location?.lat, 16.0);
    });

    test('geocode failure and empty', () async {
      var r = await LocationService.resolveMarketLocation(
          deps: deps(placemarks: (a, b) async => throw Exception('x')));
      expect(r.failure, MarketLocationFailure.geocodeFailed);
      r = await LocationService.resolveMarketLocation(
          deps: deps(placemarks: (a, b) async => []));
      expect(r.failure, MarketLocationFailure.geocodeFailed);
    });

    test('success with Telugu script state and locality fallback', () async {
      final r = await LocationService.resolveMarketLocation(
          deps: deps(
              placemarks: (a, b) async => [
                    const Placemark(
                        administrativeArea: 'తెలంగాణ', locality: 'Warangal'),
                  ]));
      expect(r.location?.state, 'Telangana');
      expect(r.location?.district, 'Warangal');
      expect(r.location?.source, MarketLocationSource.gps);
    });
  });

  group('geocoder language', () {
    test('asks the geocoder for English (India) before reverse geocoding',
        () async {
      final log = <String>[];
      final r = await LocationService.resolveMarketLocation(
          deps: deps(
              setLocale: (l) async => log.add('locale:$l'),
              placemarks: (a, b) async {
                log.add('placemarks');
                return [
                  const Placemark(
                      administrativeArea: 'Telangana',
                      subAdministrativeArea: 'Rangareddy'),
                ];
              }));
      expect(log, ['locale:en_IN', 'placemarks']);
      expect(r.location?.district, 'Rangareddy');
    });

    test('a failing locale switch does not break resolution', () async {
      final r = await LocationService.resolveMarketLocation(
          deps: deps(setLocale: (l) async => throw Exception('unsupported')));
      expect(r.location?.state, 'Telangana');
    });

    test('Telugu-script district and state still resolve', () async {
      final r = await LocationService.resolveMarketLocation(
          deps: deps(
              placemarks: (a, b) async => [
                    const Placemark(
                        administrativeArea: 'తెలంగాణ',
                        subAdministrativeArea: 'రంగారెడ్డి జిల్లా'),
                  ]));
      expect(r.location?.state, 'Telangana');
      expect(r.location?.district, 'Rangareddy');
      final ap = await LocationService.resolveMarketLocation(
          deps: deps(
              placemarks: (a, b) async => [
                    const Placemark(
                        administrativeArea: 'ఆంధ్రప్రదేశ్',
                        subAdministrativeArea: 'గుంటూరు జిల్లా'),
                  ]));
      expect(ap.location?.state, 'Andhra Pradesh');
      expect(ap.location?.district, 'Guntur');
    });
  });

  group('locationFromProfile', () {
    test('null / empty district', () {
      expect(LocationService.locationFromProfile(null), isNull);
      expect(
          LocationService.locationFromProfile(
              User(userId: '1', name: 'a', district: ' ')),
          isNull);
    });

    test('derives state from known district', () {
      final l = LocationService.locationFromProfile(
          User(userId: '1', name: 'a', district: 'Guntur'))!;
      expect(l.state, 'Andhra Pradesh');
      expect(l.source, MarketLocationSource.profile);
    });

    test('unknown district leaves state empty; region wins', () {
      var l = LocationService.locationFromProfile(
          User(userId: '1', name: 'a', district: 'Pune'))!;
      expect(l.hasState, isFalse);
      l = LocationService.locationFromProfile(User(
          userId: '1', name: 'a', district: 'Pune', region: 'Maharashtra'))!;
      expect(l.state, 'Maharashtra');
    });
  });

  group('market_aliases', () {
    test('canonicalState', () {
      expect(canonicalState('Orissa'), 'Odisha');
      expect(canonicalState('  telangana '), 'Telangana');
      expect(canonicalState('తెలంగాణ'), 'Telangana');
      expect(canonicalState('आंध्र प्रदेश'), 'Andhra Pradesh');
      expect(canonicalState('NCT of Delhi'), 'Delhi');
      expect(canonicalState('goa'), 'Goa');
      expect(canonicalState(''), '');
    });

    test('sameDistrict', () {
      expect(sameDistrict('Chittor', 'Chittoor'), isTrue);
      expect(sameDistrict('Rangareddy', 'Ranga Reddy'), isTrue);
      expect(sameDistrict('Rangareddi', 'Ranga Reddy District'), isTrue);
      expect(sameDistrict('Warangal Urban', 'Hanumakonda'), isTrue);
      expect(sameDistrict('Tirupathi', 'Tirupati'), isTrue);
      expect(sameDistrict('Vizag', 'Visakhapatnam'), isTrue);
      expect(sameDistrict('Mahbubnagar', 'Mahabubnagar'), isTrue);
      expect(sameDistrict('Medchal-Malkajgiri', 'Medchal Malkajgiri'), isTrue);
      expect(sameDistrict('Guntur', 'Krishna'), isFalse);
      expect(sameDistrict('', 'Guntur'), isFalse);
    });

    test('every state and UT resolves from Telugu and Hindi', () {
      const te = {
        'Telangana': 'తెలంగాణ',
        'Andhra Pradesh': 'ఆంధ్ర ప్రదేశ్',
        'Karnataka': 'కర్ణాటక',
        'Tamil Nadu': 'తమిళనాడు',
        'Kerala': 'కేరళ',
        'Maharashtra': 'మహారాష్ట్ర',
        'Odisha': 'ఒడిశా',
        'Goa': 'గోవా',
        'Delhi': 'ఢిల్లీ',
        'Ladakh': 'లడఖ్',
        'Puducherry': 'పుదుచ్చేరి',
        'Jammu and Kashmir': 'జమ్మూ కాశ్మీర్',
        'West Bengal': 'పశ్చిమ బెంగాల్',
        'Uttar Pradesh': 'ఉత్తర ప్రదేశ్',
      };
      te.forEach((en, t) => expect(canonicalState(t), en, reason: t));
      const hi = {
        'Manipur': 'मणिपुर',
        'Sikkim': 'सिक्किम',
        'Assam': 'असम',
        'Meghalaya': 'मेघालय',
        'Lakshadweep': 'लक्षद्वीप',
        'Chandigarh': 'चंडीगढ़',
        'Jharkhand': 'झारखंड',
        'Uttarakhand': 'उत्तराखंड',
        'Himachal Pradesh': 'हिमाचल प्रदेश',
        'West Bengal': 'पश्चिम बंगाल',
        'Arunachal Pradesh': 'अरुणाचल प्रदेश',
      };
      hi.forEach((en, h) => expect(canonicalState(h), en, reason: h));
      expect(canonicalState('Telangana State'), 'Telangana');
      expect(isKnownState(canonicalState('మణిపూర్')), isTrue);
    });

    test('Telugu district names, suffixes and dash variants', () {
      expect(sameDistrict('రంగారెడ్డి జిల్లా', 'Ranga Reddy'), isTrue);
      expect(sameDistrict('రంగారెడ్డి', 'Rangareddy District'), isTrue);
      expect(sameDistrict('గుంటూరు జిల్లా', 'Guntur'), isTrue);
      expect(sameDistrict('వరంగల్', 'Warangal'), isTrue);
      expect(sameDistrict('తూర్పు గోదావరి జిల్లా', 'East Godavari'), isTrue);
      expect(sameDistrict('తూర్పు గోదావరి', 'పశ్చిమ గోదావరి'), isFalse);
      expect(normalizeDistrictKey('Guntur జిల్లా'), 'guntur');
      expect(normalizeDistrictKey('Guntur district'), 'guntur');
      expect(
          normalizeDistrictKey('गुंटूर जिला'), normalizeDistrictKey('गुंटूर'));
      expect(sameDistrict('Medchal\u2013Malkajgiri', 'Medchal-Malkajgiri'),
          isTrue);
      expect(sameDistrict('Medchal\u2014Malkajgiri', 'Medchal Malkajgiri'),
          isTrue);
      expect(englishDistrictName('నల్గొండ జిల్లా'), 'Nalgonda');
      expect(englishDistrictName('Pune'), 'Pune');
    });

    test('direction / type words never match each other', () {
      const pairs = [
        ['East Godavari', 'West Godavari'],
        ['North Goa', 'South Goa'],
        ['Bengaluru Rural', 'Bengaluru Urban'],
        ['Bangalore Rural', 'Bangalore Urban'],
        ['Warangal Rural', 'Warangal Urban'],
        ['North 24 Parganas', 'South 24 Parganas'],
        ['Central Delhi', 'East Delhi'],
        ['New Town', 'Old Town'],
      ];
      for (final p in pairs) {
        expect(sameDistrict(p[0], p[1]), isFalse, reason: '${p[0]} / ${p[1]}');
        expect(bestDistrictMatch(p[0], [p[1]]), isNull, reason: p[0]);
      }
      // The plain name does not swallow a qualified one either.
      expect(sameDistrict('Bengaluru Rural', 'Bengaluru'), isFalse);
      expect(sameDistrict('South Goa', 'Goa'), isFalse);
    });

    test('fuzzy limits and unique best match', () {
      // <= 1 edit for short names, whole-word containment for long ones.
      expect(sameDistrict('Guntur', 'Gunturr'), isTrue);
      expect(sameDistrict('Medak', 'Medan'), isTrue);
      expect(sameDistrict('Medak', 'Medan Sx'), isFalse);
      expect(sameDistrict('Krishna', 'Krishnagiri'), isFalse);
      expect(sameDistrict('Nellore', 'Nalore x'), isFalse);
      // Two equally close candidates: ambiguous -> no match.
      expect(bestDistrictMatch('Salem', ['Salen', 'Salek']), isNull);
      expect(bestDistrictMatch('Salem', ['Salen', 'Chennai']), 'Salen');
      // Contains rule needs a whole word of >= 5 letters.
      expect(sameDistrict('Medchal', 'Medchal Malkajgiri'), isTrue);
      expect(sameDistrict('Pune', 'Pune City X'), isFalse);
    });

    test('bestDistrictMatch', () {
      final avail = ['Guntur', 'Chittoor', 'Ranga Reddy'];
      expect(bestDistrictMatch('Chittor', avail), 'Chittoor');
      expect(bestDistrictMatch('Rangareddy', avail), 'Ranga Reddy');
      expect(bestDistrictMatch('Pune', avail), isNull);
    });
  });
}

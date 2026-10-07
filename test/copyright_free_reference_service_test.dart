import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cropsync/services/copyright_free_reference_service.dart';

Map<String, dynamic> _page(int index, String title, String mime) => {
      'title': title,
      'index': index,
      'imageinfo': <Map<String, dynamic>>[
        {'mime': mime, 'thumburl': 'https://upload.wikimedia.org/$index.jpg'}
      ],
    };

http.Response okResp(Map<String, dynamic> pages) => http.Response(
    jsonEncode({
      "query": {"pages": pages}
    }),
    200);

void main() {
  test('filters mimes, ranks by keyword, sends User-Agent', () async {
    String? ua;
    final client = MockClient((req) async {
      ua = req.headers['User-Agent'];
      return http.Response(
        jsonEncode({
          'query': {
            'pages': {
              '1': _page(1, 'File:Random thing.jpg', 'image/jpeg'),
              '2': _page(2, 'File:Rice blast.pdf', 'application/pdf'),
              '3': _page(3, 'File:Rice blast lesions.jpg', 'image/jpeg'),
            }
          }
        }),
        200,
      );
    });
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Rice', problemName: 'blast', client: client);
    expect(ua, contains('CropSync/1.0'));
    expect(r.length, 1); // score-0 'Random thing' rejected
    expect(r.first.title, 'Rice blast lesions.jpg');
  });

  test('returns empty (no fake fallback) on errors', () async {
    final client = MockClient((req) async => http.Response('x', 500));
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Zzz', problemName: 'Qqq', client: client);
    expect(r, isEmpty);
  });

  test('score-0 results are rejected and next query is tried', () async {
    final queries = <String>[];
    final client = MockClient((req) async {
      queries.add(req.url.queryParameters['gsrsearch']!);
      if (queries.length == 1) {
        return okResp({'1': _page(1, 'File:Sunset beach.jpg', 'image/jpeg')});
      }
      return okResp(
          {'2': _page(2, 'File:Wheat rust pustules.jpg', 'image/jpeg')});
    });
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Wheat', problemName: 'rust', client: client);
    expect(queries.length, 2);
    expect(r.single.title, 'Wheat rust pustules.jpg');
  });

  test('crop-only fallback requires crop in title', () async {
    final client = MockClient((req) async =>
        okResp({'1': _page(1, 'File:Unrelated field.jpg', 'image/jpeg')}));
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Maize', problemName: 'smut', client: client);
    expect(r, isEmpty);
  });

  test('empty problem searches crop only', () async {
    final queries = <String>[];
    final client = MockClient((req) async {
      queries.add(req.url.queryParameters['gsrsearch']!);
      return okResp({'1': _page(1, 'File:Cotton field.jpg', 'image/jpeg')});
    });
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Cotton', problemName: '  ', client: client);
    expect(queries, ['Cotton']);
    expect(r.length, 1);
  });

  test('empty crop returns empty without network call', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return okResp({});
    });
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: null, problemName: 'blight', client: client);
    final r2 = await CopyrightFreeReferenceService.fetchReferences(
        cropName: ' ', problemName: null, client: client);
    expect(r, isEmpty);
    expect(r2, isEmpty);
    expect(calls, 0);
  });

  test('keyword matching uses word boundaries', () async {
    final client = MockClient((req) async => okResp({
          '1': _page(1, 'File:Price of apricot.jpg', 'image/jpeg'),
          '2': _page(2, 'File:Rice field.jpg', 'image/jpeg'),
        }));
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Rice', client: client);
    expect(r.map((p) => p.title), ['Rice field.jpg']);
  });

  test('uses per-file licence and artist, falls back to generic', () async {
    final client = MockClient((req) async {
      expect(req.url.queryParameters['iiprop'], contains('extmetadata'));
      expect(req.url.queryParameters['iiextmetadatafilter'],
          'LicenseShortName|Artist');
      final withMeta = _page(1, 'File:Tomato blight leaf.jpg', 'image/jpeg');
      (withMeta['imageinfo'] as List).first['extmetadata'] = {
        'LicenseShortName': {'value': 'CC BY-SA 4.0'},
        'Artist': {'value': '<a href="x">Jane <b>Doe</b></a>'},
      };
      return okResp({
        '1': withMeta,
        '2': _page(2, 'File:Tomato blight spots.jpg', 'image/jpeg'),
      });
    });
    final r = await CopyrightFreeReferenceService.fetchReferences(
        cropName: 'Tomato', problemName: 'blight', client: client);
    expect(r[0].license, 'CC BY-SA 4.0');
    expect(r[0].credit, 'Jane Doe');
    expect(r[1].license, 'Creative Commons / Public Domain');
    expect(r[1].credit, isNull);
  });
}

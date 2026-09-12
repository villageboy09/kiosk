import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/reel_model.dart';
import 'package:cropsync/services/reels_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/screens/reels_screen.dart';

void main() {
  final sampleReelsJson = jsonEncode([
    {
      'id': 1,
      'video_url': 'https://example.com/sample1.mp4',
      'caption': 'Natural pest control demonstration',
      'creator': {
        'id': 1,
        'username': 'dr_kalyan',
        'displayName': 'Dr. Kalyan Rao',
        'isVerified': true,
      },
      'likes': '1.2K',
      'saves': '340',
      'has_liked': false,
      'has_saved': false,
    },
    {
      'id': 2,
      'video_url': 'https://example.com/sample2.mp4',
      'caption': 'Drip irrigation setup guide',
      'creator': {
        'id': 2,
        'username': 'ravi_farmer',
        'displayName': 'Ravi Kumar',
        'isVerified': false,
      },
      'likes': '850',
      'saves': '120',
      'has_liked': false,
      'has_saved': false,
    },
    {
      'id': 3,
      'video_url': 'https://example.com/sample3.mp4',
      'caption': 'Soil testing methods before sowing',
      'creator': {
        'id': 3,
        'username': 'green_tech',
        'displayName': 'Green Tech',
        'isVerified': true,
      },
      'likes': '2.1K',
      'saves': '510',
      'has_liked': false,
      'has_saved': false,
    },
    {
      'id': 4,
      'video_url': 'https://example.com/sample4.mp4',
      'caption': 'Organic composting masterclass',
      'creator': {
        'id': 4,
        'username': 'farm_master',
        'displayName': 'Farm Master',
        'isVerified': false,
      },
      'likes': '990',
      'saves': '230',
      'has_liked': false,
      'has_saved': false,
    },
  ]);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'cropsync_cached_reels_v1': sampleReelsJson,
    });
  });

  group('Reels Models Tests', () {
    test('ReelCreator model parsing and serialization', () {
      final json = {
        'id': 10,
        'username': 'dr_kalyan',
        'displayName': 'Dr. Kalyan Rao',
        'profileImageUrl': 'https://example.com/avatar.jpg',
        'isVerified': true,
        'phoneNumber': '+919988776655',
        'bio': 'Agronomist',
      };

      final creator = ReelCreator.fromJson(json);
      expect(creator.id, 10);
      expect(creator.username, 'dr_kalyan');
      expect(creator.displayName, 'Dr. Kalyan Rao');
      expect(creator.isVerified, true);
      expect(creator.phoneNumber, '+919988776655');

      final serialized = creator.toJson();
      expect(serialized['username'], 'dr_kalyan');
      expect(serialized['phoneNumber'], '+919988776655');
    });

    test('ReelComment model parsing and formattedTimeAgo', () {
      final now = DateTime.now();
      final json = {
        'id': 1,
        'reel_id': 100,
        'farmer_username': 'ravi_farmer',
        'phone_number': '9876543210',
        'comment_text': 'Great organic technique!',
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      };

      final comment = ReelComment.fromJson(json);
      expect(comment.id, 1);
      expect(comment.reelId, 100);
      expect(comment.farmerUsername, 'ravi_farmer');
      expect(comment.commentText, 'Great organic technique!');
      expect(comment.formattedTimeAgo, '2h ago');
    });

    test('Reel model parsing and copyWith helper', () {
      final json = {
        'id': 5,
        'videoUrl': 'https://example.com/sample_video.mp4',
        'creator': {
          'id': 1,
          'username': 'agri_master',
          'displayName': 'Agri Master',
          'profileImageUrl': '',
        },
        'caption': 'Paddy harvest demo #farming',
        'musicTitle': 'Kisan Beat',
        'phoneNumber': '+919876543210',
        'tags': 'paddy,harvest',
        'likes': '1.5K',
        'likesRaw': 1500,
        'hasLiked': false,
        'saves': '250',
        'savesRaw': 250,
        'hasSaved': false,
        'commentsCount': 12,
        'viewsCount': 8900,
        'created_at': DateTime.now().toIso8601String(),
      };

      final reel = Reel.fromJson(json);
      expect(reel.id, 5);
      expect(reel.videoUrl, 'https://example.com/sample_video.mp4');
      expect(reel.creator.username, 'agri_master');
      expect(reel.hasLiked, false);
      expect(reel.likes, '1.5K');
      expect(reel.saves, '250');

      final updated = reel.copyWith(
        hasLiked: true,
        likesRaw: 1501,
        likes: '1.5K',
        hasSaved: true,
      );

      expect(updated.hasLiked, true);
      expect(updated.hasSaved, true);
      expect(updated.likesRaw, 1501);
      expect(updated.id, 5);
    });
  });

  group('ReelsService Tests', () {
    test('getReels returns default curated reels catalog in offline test mode', () async {
      final reels = await ReelsService.getReels();
      expect(reels, isNotEmpty);
      expect(reels.length, greaterThanOrEqualTo(4));
      expect(reels.first.creator.username, isNotEmpty);
      expect(reels.first.videoUrl, contains('mp4'));
    });

    test('toggleLike persists state and toggles properly', () async {
      final res1 = await ReelsService.toggleLike(1);
      expect(res1['success'], true);
      expect(res1['hasLiked'], true);

      final res2 = await ReelsService.toggleLike(1);
      expect(res2['success'], true);
      expect(res2['hasLiked'], false);
    });

    test('toggleSave persists state and toggles properly', () async {
      final res1 = await ReelsService.toggleSave(2);
      expect(res1['success'], true);
      expect(res1['hasSaved'], true);

      final res2 = await ReelsService.toggleSave(2);
      expect(res2['success'], true);
      expect(res2['hasSaved'], false);
    });

    test('addComment creates valid comment object and logs analytics', () async {
      final comment = await ReelsService.addComment(1, 'Nice harvest demonstration!');
      expect(comment, isNotNull);
      expect(comment!.commentText, 'Nice harvest demonstration!');
      expect(comment.reelId, 1);
    });
  });

  group('FarmerAnalyticsService Reel Events Tests', () {
    test('logs all reel interaction types without throwing exceptions', () async {
      await FarmerAnalyticsService.logReelView(
        reelId: 1,
        watchDurationSeconds: 15,
        isCompleted: true,
        creatorUsername: 'dr_kalyan',
      );

      await FarmerAnalyticsService.logReelLike(
        reelId: 1,
        isLiked: true,
        creatorUsername: 'dr_kalyan',
      );

      await FarmerAnalyticsService.logReelSave(
        reelId: 1,
        isSaved: true,
        creatorUsername: 'dr_kalyan',
      );

      await FarmerAnalyticsService.logReelComment(
        reelId: 1,
        commentLength: 25,
      );

      await FarmerAnalyticsService.logReelShare(reelId: 1);

      await FarmerAnalyticsService.logReelCall(
        reelId: 1,
        phoneNumber: '+919876543210',
      );
    });
  });

  group('ReelsScreen Widget Tests', () {
    testWidgets('ReelsScreen mounts and displays list of reels on mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        const MaterialApp(
          home: ReelsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('ReelsScreen mounts and constrains layout on tablet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: ReelsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(ConstrainedBox), findsWidgets);
    });

    testWidgets('ReelsScreen updates visibility and activates when isTabVisible becomes true', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        const MaterialApp(
          home: ReelsScreen(isTabVisible: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReelsScreen), findsOneWidget);

      // Verify all items are inactive when tab is hidden
      final inactiveItems = tester.widgetList(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AuthenticReelItem',
      ));
      expect(inactiveItems, isNotEmpty);
      for (final item in inactiveItems) {
        expect((item as dynamic).isActive, isFalse);
      }

      // Switch tab to visible
      await tester.pumpWidget(
        const MaterialApp(
          home: ReelsScreen(isTabVisible: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReelsScreen), findsOneWidget);

      // Verify active item is now activated for playback
      final activeItems = tester.widgetList(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AuthenticReelItem' && (w as dynamic).isActive == true,
      ));
      expect(activeItems, hasLength(1));
    });

    testWidgets('ReelsScreen responds to static isTabActive changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      ReelsScreen.isTabActive.value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: ReelsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final inactiveItems = tester.widgetList(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AuthenticReelItem',
      ));
      expect(inactiveItems, isNotEmpty);
      for (final item in inactiveItems) {
        expect((item as dynamic).isActive, isFalse);
      }

      ReelsScreen.isTabActive.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final activeItems = tester.widgetList(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AuthenticReelItem' && (w as dynamic).isActive == true,
      ));
      expect(activeItems, hasLength(1));

      ReelsScreen.isTabActive.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final deactivatedItems = tester.widgetList(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AuthenticReelItem',
      ));
      for (final item in deactivatedItems) {
        expect((item as dynamic).isActive, isFalse);
      }
    });
  });
}

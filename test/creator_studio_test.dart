import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/creator_studio_model.dart';
import 'package:cropsync/services/creator_service.dart';
import 'package:cropsync/screens/creator/creator_studio_screen.dart';
import 'package:cropsync/screens/creator/upload_reel_screen.dart';
import 'package:cropsync/screens/creator/upload_news_screen.dart';

class CreatorTestAssetLoader extends AssetLoader {
  const CreatorTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'creator_studio_title': 'Creator Studio',
      'creator_studio_subtitle': 'Manage your reels, news & analyze reach',
      'creator_upload_reel': 'Upload Reel',
      'creator_upload_news': 'Write News Article',
      'creator_tab_reels': 'My Reels',
      'creator_tab_news': 'My Articles',
      'creator_tab_analytics': 'Analytics',
      'creator_stat_views': 'Total Views',
      'creator_stat_likes': 'Total Likes',
      'creator_stat_comments': 'Comments',
      'creator_stat_saves': 'Bookmarks',
      'creator_stat_shares': 'Shares',
      'creator_stat_calls': 'Inquiries',
      'creator_stat_engagement': 'Engagement',
      'creator_stat_avg_watch': 'Avg. Watch Time',
      'creator_no_reels': 'No reels uploaded yet',
      'creator_no_reels_sub': 'Share video guides and farming tips with fellow farmers',
      'creator_no_articles': 'No articles published yet',
      'creator_no_articles_sub': 'Write helpful advisories, news, or crop care guides',
      'creator_status_active': 'Active',
      'creator_status_inactive': 'Inactive',
      'creator_status_published': 'Published',
      'creator_status_draft': 'Draft',
      'creator_delete_confirm_title': 'Delete Content?',
      'creator_delete_confirm_desc': 'Are you sure you want to delete this? This action cannot be undone.',
      'creator_delete_btn': 'Delete',
      'creator_cancel_btn': 'Cancel',
      'upload_reel_title': 'New Agri Reel',
      'upload_reel_select_video': 'Select Video',
      'upload_reel_gallery': 'Choose from Gallery',
      'upload_reel_camera': 'Record Video',
      'upload_reel_url_hint': 'Or enter public video URL (MP4)',
      'upload_reel_caption_hint': 'Write a caption for your reel... #paddy #organic',
      'upload_reel_audio_hint': 'Audio Title (e.g. Original Sound)',
      'upload_reel_phone_hint': 'Contact Number for farmer inquiries',
      'upload_reel_tags_hint': 'Add topic tags',
      'upload_reel_publish_btn': 'Publish Reel',
      'upload_reel_success': 'Reel published successfully!',
      'upload_news_title': 'Publish Agri Article',
      'upload_news_headline': 'Article Headline / Title',
      'upload_news_summary': 'Executive Summary (2-3 sentences)',
      'upload_news_content': 'Full Article Content',
      'upload_news_category': 'Category',
      'upload_news_image': 'Cover Image (Camera/Gallery or URL)',
      'upload_news_author': 'Author Name',
      'upload_news_source': 'Source / Organization',
      'upload_news_featured': 'Feature as Top Story',
      'upload_news_publish_btn': 'Publish Article',
      'upload_news_success': 'News article published successfully!',
    };
  }
}

Widget createTestApp(Widget home) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'assets/translations',
    startLocale: const Locale('en'),
    fallbackLocale: const Locale('en'),
    assetLoader: const CreatorTestAssetLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: home,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'user_phone': '9876543210',
      'user_name': 'Dr. Kalyan',
      'user_id': 'user_001',
    });
    await EasyLocalization.ensureInitialized();
  });

  group('Creator Studio Models & Service Tests', () {
    test('CreatorStats and DailyTrendItem parse correctly from JSON', () {
      final json = {
        'totalViews': 15400,
        'totalLikes': 920,
        'totalComments': 140,
        'totalSaves': 320,
        'totalCalls': 45,
        'totalShares': 60,
        'engagementRate': 9.4,
        'avgWatchDurationSeconds': 18.2,
        'totalReels': 4,
        'totalArticles': 2,
      };

      final stats = CreatorStats.fromJson(json);
      expect(stats.totalViews, 15400);
      expect(stats.totalLikes, 920);
      expect(stats.totalComments, 140);
      expect(stats.totalSaves, 320);
      expect(stats.totalCalls, 45);
      expect(stats.totalShares, 60);
      expect(stats.engagementRate, 9.4);
      expect(stats.avgWatchDurationSeconds, 18.2);
      expect(stats.totalReels, 4);
      expect(stats.totalArticles, 2);

      final trend = DailyTrendItem.fromJson({'day': 'Mon', 'views': 500, 'likes': 30});
      expect(trend.day, 'Mon');
      expect(trend.views, 500);
      expect(trend.likes, 30);
    });

    test('CreatorStudioData parses correctly with nested reels and articles', () {
      final json = {
        'creator': {
          'id': 1,
          'username': 'dr_kalyan',
          'display_name': 'Dr. Kalyan Kumar',
          'profile_image_url': 'https://example.com/avatar.jpg',
          'is_verified': 1,
          'phone_number': '9876543210',
          'bio': 'Agronomist & Researcher',
        },
        'stats': {
          'totalViews': 5000,
          'totalLikes': 400,
          'totalComments': 50,
          'totalSaves': 100,
          'totalCalls': 20,
          'totalShares': 30,
          'engagementRate': 12.0,
          'avgWatchDurationSeconds': 20.0,
          'totalReels': 1,
          'totalArticles': 1,
        },
        'reels': [
          {
            'id': 1,
            'video_url': 'https://example.com/video.mp4',
            'caption': 'Organic Fertilizer Preparation #BioFertilizer',
            'music_title': 'Original Audio',
            'phone_number': '9876543210',
            'tags': '#BioFertilizer',
            'views_count': 5000,
            'likes_count': 400,
            'saves_count': 100,
            'comments_count': 50,
            'is_active': 1,
            'creator': {
              'id': 1,
              'username': 'dr_kalyan',
              'displayName': 'Dr. Kalyan Kumar',
              'profileImageUrl': '',
            }
          }
        ],
        'articles': [
          {
            'id': 10,
            'title': 'Soil Health Management in Kharif Season',
            'summary': 'Key practices to improve soil organic carbon and yield.',
            'content': 'Soil testing is the first fundamental step...',
            'category': 'Farming Tips',
            'views_count': 3000,
            'likes_count': 200,
            'comments_count': 25,
            'is_featured': 1,
          }
        ],
        'trends': [
          {'day': 'Mon', 'views': 100, 'likes': 10},
          {'day': 'Tue', 'views': 200, 'likes': 20},
        ]
      };

      final data = CreatorStudioData.fromJson(json);
      expect(data.creator.displayName, 'Dr. Kalyan Kumar');
      expect(data.creator.isVerified, true);
      expect(data.stats.totalViews, 5000);
      expect(data.reels.length, 1);
      expect(data.articles.length, 1);
      expect(data.dailyTrends.length, 2);
    });

    test('CreatorService returns fallback data when offline', () async {
      final studioData = await CreatorService.getStudioData(forceRefresh: true);
      expect(studioData.creator.displayName.isNotEmpty, true);
      expect(studioData.stats.totalViews > 0, true);
      expect(studioData.dailyTrends.isNotEmpty, true);
    });
  });

  group('Creator Studio & Upload Screens Widget Tests', () {
    testWidgets('CreatorStudioScreen renders header, KPI metrics and tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const CreatorStudioScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Creator Studio'), findsOneWidget);
      expect(find.text('My Reels'), findsOneWidget);
      expect(find.text('My Articles'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Total Views'), findsOneWidget);
      expect(find.text('Total Likes'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Inquiries'), findsOneWidget);
    });

    testWidgets('UploadReelScreen renders form fields and suggested tag chips', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const UploadReelScreen()));
      await tester.pumpAndSettle();

      expect(find.text('New Agri Reel'), findsOneWidget);
      expect(find.text('Select Video'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Record Video'), findsOneWidget);
      expect(find.text('Publish Reel'), findsNWidgets(2)); // AppBar action + Bottom button
      expect(find.text('#PaddyCare'), findsOneWidget);
      expect(find.text('#DroneSpray'), findsOneWidget);

      // Tap on a tag chip
      await tester.tap(find.text('#PaddyCare'));
      await tester.pumpAndSettle();
    });

    testWidgets('UploadNewsScreen renders category chips and form inputs', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const UploadNewsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Publish Agri Article'), findsOneWidget);
      expect(find.text('Farming Tips'), findsOneWidget);
      expect(find.text('Govt Schemes'), findsOneWidget);
      expect(find.text('Market & MSP'), findsOneWidget);
      expect(find.text('Tech & Drones'), findsOneWidget);
      expect(find.text('Publish Article'), findsNWidgets(2)); // AppBar action + Bottom button

      // Select Govt Schemes category chip
      await tester.tap(find.text('Govt Schemes'));
      await tester.pumpAndSettle();
    });
  });
}

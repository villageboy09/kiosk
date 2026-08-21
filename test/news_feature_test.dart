import 'package:cropsync/models/news_article.dart';
import 'package:cropsync/screens/news/news_detail_screen.dart';
import 'package:cropsync/screens/news/news_feed_screen.dart';
import 'package:cropsync/services/news_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsTestAssetLoader extends AssetLoader {
  const NewsTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'news_title': 'Krishi News',
      'news_subtitle': 'Latest agricultural updates, schemes & market trends',
      'news_search_hint': 'Search news, subsidies, MSP...',
      'news_featured_badge': 'TOP STORY',
      'news_category_all': 'All News',
      'news_category_schemes': '🏛️ Govt Schemes',
      'news_category_market': '📈 Market & MSP',
      'news_category_tech': '🌾 Tech & Drones',
      'news_category_weather': '🌧️ Weather & Climate',
      'news_category_tips': '🌱 Farming Tips',
      'news_views_count': 'views',
      'news_likes_count': 'likes',
      'news_comments_count': 'comments',
      'news_comments_header': 'Comments',
      'news_no_comments': 'No comments yet. Be the first farmer to comment!',
      'news_comment_hint': 'Write your thoughts or ask a question...',
      'news_comment_submit': 'Post',
      'news_empty_title': 'No news articles found',
      'news_empty_subtitle': 'Try clearing your search or switching categories.',
      'news_min_read': 'min read',
      'home_bottom_nav_news': 'News',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrapWithLocalization(Widget child, {required Size screenSize}) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        assetLoader: const NewsTestAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: child,
            );
          },
        ),
      ),
    );
  }

  group('NewsArticle & NewsComment Model Tests', () {
    test('NewsArticle correctly parses JSON and calculates reading time', () {
      final json = {
        'id': 101,
        'title': 'Solar Pump Subsidy Announced',
        'summary': 'Farmers get up to 60% subsidy for installing PM-KUSUM solar pumps.',
        'content': 'Detailed guidelines for solar irrigation pumps application...\n' * 50,
        'category': 'Govt Schemes',
        'image_url': 'https://example.com/solar.jpg',
        'author': 'Renewable Energy Wing',
        'source_name': 'KUSUM Portal',
        'views_count': 500,
        'likes_count': 42,
        'comments_count': 7,
        'is_featured': 1,
        'has_liked': 0,
        'published_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      };

      final article = NewsArticle.fromJson(json);

      expect(article.id, 101);
      expect(article.title, 'Solar Pump Subsidy Announced');
      expect(article.category, 'Govt Schemes');
      expect(article.isFeatured, isTrue);
      expect(article.hasLiked, isFalse);
      expect(article.viewsCount, 500);
      expect(article.likesCount, 42);
      expect(article.commentsCount, 7);
      expect(article.estimatedReadTimeMinutes, greaterThanOrEqualTo(1));
      expect(article.formattedPublishedDate, contains('h ago'));
    });

    test('NewsComment correctly parses JSON and formats timestamp', () {
      final json = {
        'id': 501,
        'article_id': 101,
        'user_name': 'Kalyan Rao',
        'user_role': 'farmer',
        'phone_number': '9876543210',
        'comment_text': 'Where can we apply for this scheme?',
        'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      };

      final comment = NewsComment.fromJson(json);

      expect(comment.id, 501);
      expect(comment.articleId, 101);
      expect(comment.userName, 'Kalyan Rao');
      expect(comment.commentText, 'Where can we apply for this scheme?');
      expect(comment.formattedDate, '15m ago');
    });
  });

  group('NewsService Unit Tests', () {
    test('getArticles retrieves fallback articles and filters by category', () async {
      final allArticles = await NewsService.getArticles();
      expect(allArticles.isNotEmpty, isTrue);
      expect(allArticles.any((a) => a.isFeatured), isTrue);

      final schemeArticles = await NewsService.getArticles(category: 'Govt Schemes');
      expect(schemeArticles.every((a) => a.category == 'Govt Schemes'), isTrue);
    });

    test('getArticles searches by keyword', () async {
      final searchResults = await NewsService.getArticles(searchQuery: 'Paddy');
      expect(searchResults.any((a) => a.title.contains('Paddy') || a.content.contains('Paddy')), isTrue);
    });
  });

  group('NewsFeedScreen Responsive Widget Tests', () {
    testWidgets('Renders search bar, category chips, and news list on mobile (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const NewsFeedScreen(),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify search bar and header
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Krishi News'), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('Renders responsive layout on tablet screen (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const NewsFeedScreen(),
          screenSize: const Size(1280, 800),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('NewsDetailScreen Widget Tests', () {
    final sampleArticle = NewsArticle(
      id: 9999,
      title: 'Solar Irrigation Subsidy Available for All Districts',
      summary: 'State Govt announces 50% subsidy for solar pump sets.',
      content: 'Under the new agricultural modernization initiative, farmers can now apply online for solar powered pumps...',
      category: 'Govt Schemes',
      author: 'Agri Dept',
      sourceName: 'Govt Portal',
      viewsCount: 250,
      likesCount: 15,
      commentsCount: 2,
      isFeatured: true,
      hasLiked: false,
      publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    testWidgets('Renders full article, metrics, and comments section', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          NewsDetailScreen(article: sampleArticle),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify title and category
      expect(find.text('Solar Irrigation Subsidy Available for All Districts'), findsOneWidget);
      expect(find.text('Govt Schemes'), findsOneWidget);

      // Verify comment input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Tapping like button updates like state optimistically', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          NewsDetailScreen(article: sampleArticle),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('15'), findsOneWidget);

      // Tap like button
      final heartIcon = find.byIcon(Icons.favorite_border_rounded);
      expect(heartIcon, findsOneWidget);
      await tester.ensureVisible(heartIcon);
      await tester.pumpAndSettle();
      await tester.tap(heartIcon);
      await tester.pump();

      // Optimistic like increment
      expect(find.text('16'), findsOneWidget);
    });
  });
}

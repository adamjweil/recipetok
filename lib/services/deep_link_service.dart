import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import '../screens/meal_post_screen.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  
  factory DeepLinkService() {
    return _instance;
  }
  
  DeepLinkService._internal();

  Future<void> initDynamicLinks(BuildContext context) async {
    // Handle links when app is in background/terminated
    final PendingDynamicLinkData? initialLink = 
        await FirebaseDynamicLinks.instance.getInitialLink();

    if (initialLink != null) {
      _handleDynamicLink(initialLink, context);
    }

    // Handle links when app is in foreground
    FirebaseDynamicLinks.instance.onLink.listen(
      (dynamicLinkData) {
        _handleDynamicLink(dynamicLinkData, context);
      },
      onError: (error) {
        print('Dynamic Link Failed: ${error.message}');
      },
    );
  }

  void _handleDynamicLink(PendingDynamicLinkData data, BuildContext context) {
    final Uri deepLink = data.link;
    
    // Example: recipetok.app/post/123
    if (deepLink.pathSegments.contains('post')) {
      final String? postId = deepLink.pathSegments.last;
      if (postId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealPostScreen(mealId: postId),
          ),
        );
      }
    }
  }

  Future<String> createDynamicLink(String postId) async {
    final dynamicLinkParams = DynamicLinkParameters(
      link: Uri.parse('https://recipetok.page.link/post/$postId'),
      uriPrefix: 'https://recipetok.page.link',
      androidParameters: const AndroidParameters(
        packageName: 'com.recipetok.app',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.recipetok.app',
        minimumVersion: '0',
        appStoreId: '6475357667',
      ),
      socialMetaTagParameters: const SocialMetaTagParameters(
        title: 'Check out this recipe!',
        description: 'View this amazing recipe on Munchster',
      ),
    );

    final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(
      dynamicLinkParams,
      shortLinkType: ShortDynamicLinkType.short,
    );
    return shortLink.shortUrl.toString();
  }
} 
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter/foundation.dart';

class CustomCacheManager {
  static const key = 'customCache';
  static CacheManager? _instance;

  static CacheManager get instance {
    if (_instance == null) {
      _instance = CacheManager(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
          fileService: HttpFileService(),
        ),
      );
    }
    return _instance!;
  }

  // Clear the cache
  static Future<void> clearCache() async {
    await _instance?.emptyCache();
  }

  // Rename init to initialize to match the call in main.dart
  static Future<void> initialize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachePath = p.join(cacheDir.path, key);
      await Directory(cachePath).create(recursive: true);
      
      // Initialize the cache manager instance
      _instance = CacheManager(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
          fileService: HttpFileService(),
        ),
      );
    } catch (e) {
      // Handle or log initialization error
      print('Cache initialization error: $e');
    }
  }

  // Add error handling for database operations
  static Future<void> safeWrite(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      if (e.toString().contains('readonly database')) {
        // If we get a readonly error, clear the cache and try again
        await clearCache();
        try {
          await operation();
        } catch (e) {
          // If it still fails, just log it
          print('Cache operation failed after retry: $e');
        }
      } else {
        // For other errors, just log them
        print('Cache operation failed: $e');
      }
    }
  }

  // Add a separate method for URL validation
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      debugPrint('Debug: URL is null or empty');
      return false;
    }
    
    try {
      final uri = Uri.parse(url);
      final isValid = uri.hasScheme && 
                     (uri.scheme == 'http' || uri.scheme == 'https') &&
                     uri.host.isNotEmpty;
      
      debugPrint('Debug: URL validation for $url: $isValid');
      debugPrint('Debug: Scheme: ${uri.scheme}, Host: ${uri.host}');
      
      return isValid;
    } catch (e) {
      debugPrint('Debug: URL parsing error: $e');
      return false;
    }
  }

  // Update getFileFromCache to use the validation method
  static Future<File?> getFileFromCache(String? url) async {
    if (!isValidImageUrl(url)) {
      print('Warning: Invalid or empty image URL');
      return null;
    }

    try {
      final fileInfo = await instance.getFileFromCache(url!);
      return fileInfo?.file;
    } catch (e) {
      print('Error retrieving cached file: $e');
      return null;
    }
  }
} 
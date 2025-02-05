import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class CustomCacheManager {
  static const key = 'customCache';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 100,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileSystem: IOFileSystem(key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  // Clear the cache
  static Future<void> clearCache() async {
    await _instance?.emptyCache();
  }

  static Future<void> init(Directory cacheDir) async {
    try {
      await cacheDir.create(recursive: true);
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
      print('Error initializing cache: $e');
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
} 
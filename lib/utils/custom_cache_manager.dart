import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileSystem: IOFileSystem(key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  // Add a method to clear cache if needed
  static Future<void> clearCache() async {
    await _instance?.emptyCache();
    _instance = null;
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

  static Future<void> initialize() async {
    try {
      // Clear the cache on app start to prevent database errors
      await instance.emptyCache();
    } catch (e) {
      print('Error initializing cache: $e');
    }
  }
} 
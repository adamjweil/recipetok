import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    _instance = null;  // Reset the instance after clearing
  }

  // Initialize the cache manager with proper permissions
  static Future<void> initialize() async {
    try {
      // Get the temporary directory
      final cacheDir = await getTemporaryDirectory();
      final cachePath = p.join(cacheDir.path, key);
      
      // Create directory if it doesn't exist
      final directory = Directory(cachePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Ensure proper permissions on iOS
      if (Platform.isIOS) {
        try {
          await Process.run('chmod', ['777', cachePath]);
        } catch (e) {
          debugPrint('Failed to set permissions: $e');
        }
      }

      // Delete existing database file if it exists
      final dbFile = File(p.join(cachePath, '$key.db'));
      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
        } catch (e) {
          debugPrint('Failed to delete existing database: $e');
        }
      }
      
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

      // Test write access
      await safeWrite(() async {
        await _instance?.emptyCache();
      });
    } catch (e) {
      debugPrint('Cache initialization error: $e');
      // If initialization fails, try to recover
      try {
        final cacheDir = await getTemporaryDirectory();
        final cachePath = p.join(cacheDir.path, key);
        
        // Delete the entire cache directory
        final directory = Directory(cachePath);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
        
        // Retry initialization after cleanup
        await initialize();
      } catch (retryError) {
        debugPrint('Cache recovery failed: $retryError');
        // If recovery fails, create a new instance with in-memory cache
        _instance = CacheManager(
          Config(
            key,
            stalePeriod: const Duration(days: 1),
            maxNrOfCacheObjects: 50,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileSystem: IOFileSystem(key),
            fileService: HttpFileService(),
          ),
        );
      }
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
        } catch (retryError) {
          debugPrint('Cache operation failed after retry: $retryError');
        }
      } else {
        debugPrint('Cache operation failed: $e');
      }
    }
  }

  // Update the URL validation method to be more permissive and better at debugging
  static bool isValidImageUrl(String? url) {
    if (url == null) {
      debugPrint('❌ CustomCacheManager: URL is null');
      return false;
    }

    if (url.trim().isEmpty) {
      debugPrint('❌ CustomCacheManager: URL is empty');
      return false;
    }

    try {
      final uri = Uri.parse(url.trim());
      
      // More permissive validation that only requires a scheme and host
      final isValid = uri.hasScheme && uri.host.isNotEmpty;
      
      if (!isValid) {
        debugPrint('❌ CustomCacheManager: Invalid URL format detected');
        debugPrint('URL: "$url"');
        debugPrint('Scheme: ${uri.scheme}');
        debugPrint('Host: ${uri.host}');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('❌ CustomCacheManager: Error parsing URL: "$url"');
      debugPrint('Error: $e');
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

  // Update the buildCachedImage method to handle edge cases better
  static Widget buildCachedImage({
    required String? url,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (!isValidImageUrl(url)) {
      debugPrint('❌ Invalid image URL detected: $url');
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: errorWidget ?? const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholderFadeInDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => placeholder ?? Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('❌ Error loading image from: $url');
        debugPrint('Error details: $error');
        
        // For 404 errors, try an alternative URL format
        if (error is HttpException && error.toString().contains('404')) {
          final altUrl = url.replaceAll('images.unsplash.com', 'source.unsplash.com');
          debugPrint('🔄 Retrying with alternative URL: $altUrl');
          
          return CachedNetworkImage(
            imageUrl: altUrl,
            width: width,
            height: height,
            fit: fit,
            placeholder: (context, url) => placeholder ?? Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, finalError) => Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: errorWidget ?? const Center(
                child: Icon(Icons.error_outline, color: Colors.grey),
              ),
            ),
          );
        }
        
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: errorWidget ?? const Center(
            child: Icon(Icons.error_outline, color: Colors.grey),
          ),
        );
      },
    );
  }

  // Add a method specifically for avatar images
  static Widget buildProfileAvatar({
    required String? url,
    required double radius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (!isValidImageUrl(url)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: errorWidget ?? Icon(
          Icons.person,
          size: radius * 0.8,
          color: Colors.grey[400],
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          cacheManager: instance,
          placeholder: (context, url) => placeholder ?? Center(
            child: Icon(
              Icons.person,
              size: radius * 0.8,
              color: Colors.grey[400],
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('❌ Error loading avatar from: $url');
            debugPrint('Error details: $error');
            return errorWidget ?? Center(
              child: Icon(
                Icons.person,
                size: radius * 0.8,
                color: Colors.grey[400],
              ),
            );
          },
        ),
      ),
    );
  }
} 
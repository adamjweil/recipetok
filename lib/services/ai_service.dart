import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class VideoInfo {
  final Duration duration;
  final String format;
  final int width;
  final int height;

  VideoInfo({
    required this.duration,
    required this.format,
    required this.width,
    required this.height,
  });
}

class AIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25MB

  Future<VideoInfo> getVideoInfo(File videoFile) async {
    final MediaInfo? mediaInfo = await VideoCompress.getMediaInfo(videoFile.path);
    if (mediaInfo == null) {
      throw Exception('Failed to get video information');
    }

    return VideoInfo(
      duration: Duration(milliseconds: mediaInfo.duration?.toInt() ?? 0),
      format: mediaInfo.path?.split('.').last ?? 'unknown',
      width: mediaInfo.width ?? 0,
      height: mediaInfo.height ?? 0,
    );
  }

  Future<String> transcribeVideo(File videoFile) async {
    // Check file size
    final fileSize = await videoFile.length();
    if (fileSize > _maxFileSizeBytes) {
      throw Exception('Video file is too large for transcription (max 25MB)');
    }

    try {
      final url = Uri.parse('$_baseUrl/audio/transcriptions');
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Authorization': 'Bearer $_apiKey',
        })
        ..fields['model'] = 'whisper-1'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Failed to transcribe video: ${response.statusCode}\n$responseBody');
      }

      final data = json.decode(responseBody);
      String transcription = data['text'];
      
      // Sanitize the transcription text
      transcription = transcription
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '') // Remove control characters
          .replaceAll(RegExp(r'[^\x00-\x7F]+'), '') // Remove non-ASCII characters
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim(); // Trim leading/trailing whitespace
          
      debugPrint('Transcription (sanitized): $transcription');
      
      return transcription;
    } catch (e) {
      debugPrint('Error during transcription: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateRecipeData(String transcript) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    final prompt = '''
Analyze this cooking video transcript and extract the following information in JSON format:
1. A brief, engaging description
2. List of ingredients with quantities
3. Step-by-step cooking instructions
4. Estimated calories per serving
5. Estimated cooking time in minutes
6. Suggested title for the recipe

Transcript: $transcript

Please format the response as valid JSON with the following structure:
{
  "title": "string",
  "description": "string",
  "ingredients": ["string"],
  "instructions": ["string"],
  "calories": number,
  "cookTimeMinutes": number
}
''';

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: json.encode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a professional chef and food content creator who specializes in creating clear, concise recipe instructions.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate recipe data: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final content = data['choices'][0]['message']['content'];
    return json.decode(content);
  }
} 
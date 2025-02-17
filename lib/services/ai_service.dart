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

class TranscriptSegment {
  final String text;
  final double startTime;
  final double endTime;

  TranscriptSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory TranscriptSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptSegment(
      text: map['text'] ?? '',
      startTime: map['startTime']?.toDouble() ?? 0.0,
      endTime: map['endTime']?.toDouble() ?? 0.0,
    );
  }
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

  Future<List<TranscriptSegment>> transcribeVideo(File videoFile) async {
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
        ..fields['response_format'] = 'json'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
        ));

      debugPrint('Sending transcription request...');
      final response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint('Transcription failed with status ${response.statusCode}: $responseBody');
        throw Exception('Failed to transcribe video: ${response.statusCode}\n$responseBody');
      }

      debugPrint('Received transcription response');
      
      Map<String, dynamic> data;
      try {
        debugPrint('Attempting to parse response: $responseBody');
        data = json.decode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Failed to parse response as JSON: $responseBody');
        debugPrint('Parse error: $e');
        throw Exception('Invalid response format from transcription service');
      }

      // With the simpler JSON format, we'll create a single segment from the text
      final text = _sanitizeText(data['text']?.toString() ?? '');
      if (text.isEmpty) {
        throw Exception('No text found in transcription');
      }

      // Create a single segment with the entire transcription
      return [
        TranscriptSegment(
          text: text,
          startTime: 0.0,
          endTime: 0.0,  // We won't have timing information with this format
        )
      ];
    } catch (e) {
      debugPrint('Error during transcription: $e');
      rethrow;
    }
  }

  String _sanitizeText(String text) {
    return text
        .trim()
        // Remove control characters
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '')
        // Remove non-printable characters
        .replaceAll(RegExp(r'[^\x20-\x7E\s]'), '')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        // Replace smart quotes with regular quotes
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        // Replace other common problematic characters
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .trim();
  }

  Future<Map<String, dynamic>> generateRecipeData(String transcript) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    final prompt = '''
Analyze this cooking video transcript and extract the following information. Return ONLY a JSON object with no additional text or markdown formatting.

Transcript: $transcript

The response must be a valid JSON object with this exact structure:
{
  "title": "string",
  "description": "string",
  "ingredients": ["string"],
  "instructions": ["string"],
  "calories": number,
  "cookTimeMinutes": number
}

Do not include any markdown formatting, code blocks, or additional text. Return only the JSON object.
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
    
    // Clean the content by removing any markdown code blocks and extra whitespace
    final cleanContent = content
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll(RegExp(r'^\s+|\s+$'), '')
        .trim();

    try {
      debugPrint('Attempting to parse recipe data: $cleanContent');
      return json.decode(cleanContent) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to parse recipe data: $e');
      debugPrint('Raw content: $cleanContent');
      
      // Fallback response if parsing fails
      return {
        'title': 'Recipe',
        'description': content.replaceAll(RegExp(r'[{}[\]]'), '').trim(),
        'ingredients': <String>['Could not parse ingredients'],
        'instructions': <String>['Could not parse instructions'],
        'calories': 0,
        'cookTimeMinutes': 30,
      };
    }
  }
} 
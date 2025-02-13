import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class AIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25MB

  Future<String> transcribeVideo(File videoFile) async {
    // Check original file size
    final fileSize = await videoFile.length();
    File fileToTranscribe = videoFile;

    if (fileSize > _maxFileSizeBytes) {
      try {
        // Compress video and extract first frame
        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.LowQuality, // Use low quality to ensure small file size
          deleteOrigin: false, // Don't delete the original
          includeAudio: true, // Include audio as we need it for transcription
        );

        if (mediaInfo?.file == null) {
          throw Exception('Failed to compress video');
        }

        fileToTranscribe = mediaInfo!.file!;
        
        // Check if the compressed file is still too large
        final compressedSize = await fileToTranscribe.length();
        if (compressedSize > _maxFileSizeBytes) {
          throw Exception('Video is too large even after compression');
        }
      } catch (e) {
        throw Exception('Error compressing video: $e');
      }
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
          fileToTranscribe.path,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Failed to transcribe video: ${response.statusCode}\n$responseBody');
      }

      final data = json.decode(responseBody);
      return data['text'];
    } finally {
      // Clean up compressed file if it's different from the original
      if (fileToTranscribe.path != videoFile.path) {
        try {
          await fileToTranscribe.delete();
        } catch (e) {
          print('Error deleting compressed video file: $e');
        }
      }
      // Clear the cache from VideoCompress
      await VideoCompress.deleteAllCache();
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
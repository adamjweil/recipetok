import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ReplicateService {
  static final ReplicateService instance = ReplicateService._internal();
  final String _apiKey = dotenv.env['REPLICATE_API_KEY'] ?? '';
  
  ReplicateService._internal();

  Future<String?> enhanceFoodImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final createResponse = await http.post(
        Uri.parse('https://api.replicate.com/v1/predictions'),
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': '39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b',
          'input': {
            'image': 'data:image/jpeg;base64,$base64Image',
            'prompt': 'masterpiece digital art of gourmet food, professional food photography transformed into stunning digital painting, hyperrealistic art, detailed textures, dramatic lighting, vibrant colors, award-winning food illustration, artstation trending, ultra-detailed, photorealistic painting style',
            'negative_prompt': 'ugly, blurry, low quality, distorted, bad anatomy, disfigured, poorly drawn, bad proportions, watermark, text',
            'num_inference_steps': 30,
            'guidance_scale': 8.5,
            'strength': 0.75,
            'scheduler': 'K_EULER_ANCESTRAL',
            'num_outputs': 1,
            'width': 1024,
            'height': 1024,
            'refine': 'expert_ensemble_refiner',
            'high_noise_frac': 0.8,
            'apply_watermark': false
          }
        }),
      );

      if (createResponse.statusCode != 201) {
        throw Exception('Failed to create prediction: ${createResponse.body}');
      }

      final prediction = jsonDecode(createResponse.body);
      final String predictionId = prediction['id'];

      // Poll for completion
      String? outputUrl;
      bool isComplete = false;
      int attempts = 0;
      const maxAttempts = 120; // 60 seconds with 500ms delay (artistic conversion takes longer)

      while (!isComplete && attempts < maxAttempts) {
        attempts++;
        await Future.delayed(const Duration(milliseconds: 500));

        final getResponse = await http.get(
          Uri.parse('https://api.replicate.com/v1/predictions/$predictionId'),
          headers: {
            'Authorization': 'Token $_apiKey',
          },
        );

        if (getResponse.statusCode != 200) {
          throw Exception('Failed to get prediction status: ${getResponse.body}');
        }

        final status = jsonDecode(getResponse.body);
        
        if (status['status'] == 'succeeded') {
          outputUrl = status['output']?[0];
          isComplete = true;
        } else if (status['status'] == 'failed') {
          throw Exception('Image conversion failed: ${status['error']}');
        }
      }

      if (outputUrl == null) {
        throw Exception('Timeout waiting for image conversion');
      }

      return outputUrl;
    } catch (e) {
      debugPrint('Error converting image to drawing: $e');
      rethrow;
    }
  }
} 
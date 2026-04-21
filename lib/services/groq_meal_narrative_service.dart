import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/meal_planner_models.dart';
import 'meal_planner_prompts.dart';

/// Groq OpenAI-compatible chat API.
///
/// Pass API key at build/run time:
/// flutter run --dart-define=GROQ_API_KEY=your_key
class GroqMealNarrativeService {
  GroqMealNarrativeService({
    this.apiKey = const String.fromEnvironment(
      'GROQ_API_KEY',
      defaultValue: '',
    ),
    this.model = const String.fromEnvironment(
      'GROQ_MODEL',
      defaultValue: 'llama-3.3-70b-versatile',
    ),
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';

  final String apiKey;
  final String model;
  final http.Client _client;

  bool get isConfigured => apiKey.isNotEmpty;

  Future<String> generateForBasket({
    required PlannerMealSlot slot,
    required List<String> items,
    required String userName,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'GROQ_API_KEY is not set. Run with --dart-define=GROQ_API_KEY=...',
      );
    }

    final content = switch (slot) {
      PlannerMealSlot.breakfast => MealPlannerPrompts.userContentBreakfast(
          userName: userName,
          items: items,
        ),
      PlannerMealSlot.lunch => MealPlannerPrompts.userContentLunch(
          userName: userName,
          items: items,
        ),
      PlannerMealSlot.dinner => MealPlannerPrompts.userContentDinner(
          userName: userName,
          items: items,
        ),
    };

    final res = await _client.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Groq API ${res.statusCode}: ${res.body}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = map['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw Exception('Groq API: no choices in response');
    }

    final msg = choices.first as Map<String, dynamic>;
    final message = msg['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('Groq API: empty content');
    }

    return text.trim();
  }

  // ==========================================
  // THE OVERALL PROMPT FOR VISION ANALYSIS
  // ==========================================
  static const String _visionPrompt = '''
You are NutriMind's expert AI nutritionist. Analyze the provided image of food.
Please provide a concise, structured analysis using the following format exactly:

🍲 Detected: [Dish Name] 
🔥 Estimated Calories: [Number] kcal
🥗 Main Ingredients: [Comma separated list of 3-5 main ingredients]

[A brief, encouraging 1-sentence comment about the meal, e.g., "Great choice! Would you like to add this to your daily meal plan?"]

Important rules:
- Format the output cleanly so it's easy to read on a mobile app. 
- Keep the estimated calories realistic but concise.
- If the image does not clearly contain food, politely reply: "I couldn't detect any food in this image. Please try snapping another photo of your meal!"
''';

  /// Converts image bytes to base64 and sends it to Groq's Vision Model.
  Future<String> analyzeFoodImageBytes(Uint8List imageBytes) async {
    if (!isConfigured) {
      throw StateError(
        'Groq API key is missing. Run Flutter with --dart-define=GROQ_API_KEY=your_key',
      );
    }

    try {
      final base64Image = base64Encode(imageBytes);

      const prompt = '''
$_visionPrompt

For scanner meal-log saves, also include these fields on their own lines:
Nutrition Comment: [A brief, encouraging 1-sentence comment about the meal]
Possible Meal Type: [breakfast/lunch/dinner/snack]
Estimated Price: [Number] PHP or 0 if unknown
''';

      final payload = {
        'model': 'llama-3.2-11b-vision-preview',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 300,
        'temperature': 0.4,
      };

      final response = await _client.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;

        if (choices == null || choices.isEmpty) {
          throw Exception('Groq API: no choices in image response');
        }

        final firstChoice = choices.first as Map<String, dynamic>;
        final message = firstChoice['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;

        if (content == null || content.isEmpty) {
          throw Exception('Groq API: empty image analysis response');
        }

        return content.trim();
      } else {
        developer.log(
          'Groq API Error: ${response.statusCode} - ${response.body}',
          level: 900,
        );
        throw Exception('Failed to analyze image. Please try again.');
      }
    } catch (e) {
      developer.log('Image analysis error: $e', level: 900);
      throw Exception('Failed to connect to AI: $e');
    }
  }

  Future<String> chat(
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    if (!isConfigured) {
      throw StateError('GROQ_API_KEY is not set.');
    }

    const systemPrompt =
        'You are NutriBot, NutriMind\'s expert AI nutrition assistant. '
        'You specialize in Filipino nutrition, Davao local foods, healthy eating, '
        'meal planning, recipes, and cooking tips. Be friendly, concise, and helpful. '
        'Focus on budget-friendly, locally-available Davao ingredients when possible.';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final res = await _client.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': 600,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Groq API ${res.statusCode}: ${res.body}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = map['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw Exception('Groq API: no choices in chat response');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('Groq: empty response');
    }

    return text.trim();
  }

  Future<Map<String, dynamic>> generateRecipeSteps(
    String mealName,
    List<String> ingredients,
  ) async {
    if (!isConfigured) {
      throw StateError('GROQ_API_KEY is not set.');
    }

    final prompt = 'Give a short Filipino-style recipe for "$mealName".\n'
        'Ingredients available: ${ingredients.isEmpty ? "common pantry items" : ingredients.join(", ")}.\n\n'
        'Reply ONLY in this exact JSON format. No markdown. No extra text:\n'
        '{"description":"2-sentence recipe summary","steps":["Step 1...","Step 2...","Step 3...","Step 4..."]}';

    final res = await _client.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 400,
        'temperature': 0.4,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Groq API ${res.statusCode}: ${res.body}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = map['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw Exception('Groq API: no choices in recipe response');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String? ?? '';

    try {
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');

      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        return jsonDecode(
          text.substring(jsonStart, jsonEnd + 1),
        ) as Map<String, dynamic>;
      }
    } catch (_) {
      // Fallback below.
    }

    return {
      'description': 'A delicious $mealName dish made with local ingredients.',
      'steps': [
        'Prepare all ingredients.',
        'Cook using your preferred method.',
        'Season to taste.',
        'Serve hot and enjoy!',
      ],
    };
  }

  void dispose() {
    _client.close();
  }
}
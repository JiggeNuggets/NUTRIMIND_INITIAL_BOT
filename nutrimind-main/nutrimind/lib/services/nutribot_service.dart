import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/nutribot_models.dart';

/// Dedicated AI service for NutriBot chat with context-aware system prompts
/// and simulated token streaming.
class NutribotService {
  NutribotService({
    String? apiKey,
    String? model,
    http.Client? client,
  })  : _apiKey = apiKey ??
            const String.fromEnvironment('GROQ_API_KEY', defaultValue: ''),
        _model = model ??
            const String.fromEnvironment(
              'GROQ_MODEL',
              defaultValue: 'llama-3.3-70b-versatile',
            ),
        _client = client ?? http.Client();

  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  final String _apiKey;
  final String _model;
  final http.Client _client;

  bool get isConfigured => _apiKey.isNotEmpty;

  Stream<String> sendMessage({
    required String userMessage,
    required List<NutribotMessage> history,
    NutribotContext? context,
  }) async* {
    final historyMaps = history
        .where((message) => !message.isStreaming && message.content.isNotEmpty)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
          },
        )
        .toList();

    String fullResponse;

    try {
      if (!isConfigured) {
        throw StateError('GROQ_API_KEY not configured');
      }

      final systemPrompt = _buildSystemPrompt(context);

      final res = await _client
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                ...historyMaps,
                {'role': 'user', 'content': userMessage},
              ],
              'max_tokens': 500,
              'temperature': 0.75,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Groq ${res.statusCode}');
      }

      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = map['choices'] as List<dynamic>?;
      final text =
          (choices?.first as Map?)?['message']?['content'] as String? ?? '';

      if (text.isEmpty) {
        throw Exception('Empty response');
      }

      fullResponse = text.trim();
    } catch (e) {
      developer.log('NutribotService error: $e', level: 900);
      fullResponse = _mockResponse(userMessage, context);
    }

    yield* _streamWords(fullResponse);
  }

  Stream<String> _streamWords(String text) async* {
    final words = text.split(' ');
    for (var i = 0; i < words.length; i++) {
      yield i == 0 ? words[i] : ' ${words[i]}';
      await Future.delayed(const Duration(milliseconds: 26));
    }
  }

  String _buildSystemPrompt(NutribotContext? context) {
    const base =
        'You are NutriBot, a warm and knowledgeable nutrition assistant for '
        'NutriMind, a meal planning app for Davao City, Philippines. '
        'Help users with meal analysis, nutrition insights, healthier food '
        'suggestions, budget-friendly meals using local Philippine ingredients, '
        'recipe guidance, and meal planning. '
        'Be warm, practical, and concise. Use simple language. '
        'Prefer locally available Davao ingredients (malunggay, bangus, '
        'pechay, kangkong, tilapia, monggo, etc.) when relevant. '
        'Format lists with bullet points. Keep answers under 160 words unless '
        'detail is specifically needed. Currency is Philippine Peso (PHP). '
        'You give advice only. You cannot save, update, apply, or change '
        "anything in the user's meal plan, meal log, community post, scanner "
        'result, or profile. Never say you applied, updated, or saved a '
        "change. If asked to apply a change, explain that the user must make "
        'the edit themselves in the relevant NutriMind screen.';

    if (context == null || context.source == NutribotSource.general) {
      return base;
    }

    final contextNote = switch (context.source) {
      NutribotSource.home =>
        'The user opened NutriBot from the Home dashboard. Give broad, '
            'actionable nutrition guidance that fits their day, budget, and '
            'overall goal.',
      NutribotSource.mealLog =>
        'The user is currently viewing their meal log. Help analyze their '
            'meals, suggest improvements, and point out nutritional gaps.',
      NutribotSource.recipeBrowser =>
        'The user is browsing recipes. Help explain recipes, suggest healthier '
            'ingredient swaps, and offer lighter or cheaper alternatives.',
      NutribotSource.mealPlanner =>
        'The user is working on their weekly meal plan. Help optimize for their '
            'health goals and daily budget. Suggest balanced meals.',
      NutribotSource.community =>
        'The user is in the community feature. Help them write, improve, or '
            'respond to food posts in a warm, helpful tone.',
      NutribotSource.profile =>
        'The user opened NutriBot from their profile and settings area. Use '
            'their goal, budget, and profile information to suggest personalized '
            'next steps.',
      NutribotSource.foodScanner =>
        'The user just scanned a food item using the camera. Help explain the '
            'nutritional content, suggest healthy pairings, and give portion advice.',
      NutribotSource.general => '',
    };

    final detailLines = <String>[
      if (context.sourceContext?.trim().isNotEmpty ?? false)
        'Source context: ${context.sourceContext!.trim()}',
      if (context.userGoal?.trim().isNotEmpty ?? false)
        'User goal: ${context.userGoal!.trim()}',
      if (context.attachedMeal != null && context.attachedMeal!.isNotEmpty)
        'Attached meal: ${jsonEncode(context.attachedMeal)}',
      if (context.attachedRecipe != null && context.attachedRecipe!.isNotEmpty)
        'Attached recipe: ${jsonEncode(context.attachedRecipe)}',
      if (context.data != null && context.data!.isNotEmpty)
        'Additional data: ${jsonEncode(context.data)}',
      if (context.initialPrompt?.trim().isNotEmpty ?? false)
        'Suggested opening focus: ${context.initialPrompt!.trim()}',
    ];

    return [
      base,
      contextNote,
      if (detailLines.isNotEmpty) detailLines.join('\n'),
    ].join('\n\n');
  }

  String _mockResponse(String message, NutribotContext? context) {
    final loweredMessage = message.toLowerCase();

    if (loweredMessage.contains('breakfast')) {
      return 'A strong Davao breakfast can be champorado with tuyo or '
          'sinangag with egg and malunggay. Both stay affordable and can give '
          'you a good mix of carbs, protein, and steady energy.';
    }

    if (loweredMessage.contains('protein')) {
      return 'Affordable protein sources in Davao include eggs, sardines, '
          'tofu, dried fish, and chicken breast. Try pairing one of those with '
          'vegetables and rice so the meal stays balanced and filling.';
    }

    if (loweredMessage.contains('budget') ||
        loweredMessage.contains('cheap') ||
        loweredMessage.contains('save')) {
      return 'Budget-friendly meals to rotate this week: arroz caldo with egg, '
          'ginisang munggo with malunggay, pinakbet with rice, and sopas with '
          'bread. They are filling, practical, and easy to build around local ingredients.';
    }

    if (loweredMessage.contains('calorie')) {
      return 'A typical Filipino plate with rice, fish, and vegetables is often '
          'around 450 to 550 kcal. An easy way to lighten it is to trim rice a '
          'little and add more vegetables or lean protein.';
    }

    if (loweredMessage.contains('recipe') || loweredMessage.contains('cook')) {
      return 'Try tinolang manok with sayote and malunggay. It is rich in '
          'protein, easy on the budget, and uses familiar local ingredients.';
    }

    if (loweredMessage.contains('healthy') ||
        loweredMessage.contains('healthier')) {
      return 'A simple healthier plate is half vegetables, a quarter lean '
          'protein, and a quarter rice or another carb source. That keeps the '
          'meal balanced without making it feel restrictive.';
    }

    return switch (context?.source) {
      NutribotSource.home =>
        'You are looking at your NutriMind dashboard, so a helpful next step '
            'is to focus on one simple win today: keep protein in every meal, '
            'add vegetables, and stay within your budget.',
      NutribotSource.mealLog =>
        'Your meal tracking is a great start. To improve balance, add more '
            'leafy greens and a lean protein to meals that feel carb-heavy.',
      NutribotSource.recipeBrowser =>
        'For a healthier version of this recipe, trim excess oil, add more '
            'vegetables, and use herbs or aromatics instead of extra salt.',
      NutribotSource.mealPlanner =>
        'A solid plan rotates fish, chicken, and legumes for protein variety, '
            'keeps lunch hearty, and makes dinner a little lighter.',
      NutribotSource.community =>
        'A strong food post is short, personal, and useful. Share what you '
            'ate, why it worked for you, and one practical nutrition takeaway.',
      NutribotSource.profile =>
        'Your profile gives NutriBot a better picture of your goal and budget. '
            'Start with one habit this week: repeat two affordable high-protein '
            'meals and log them consistently.',
      NutribotSource.foodScanner =>
        'Focus on portion size, then pair the scanned food with a vegetable or '
            'protein source to improve fiber and satiety.',
      _ =>
        'I am here to help you eat well, stay practical, and work within your '
            'budget. Ask me about meals, ingredients, recipes, or health goals.',
    };
  }

  void dispose() => _client.close();
}

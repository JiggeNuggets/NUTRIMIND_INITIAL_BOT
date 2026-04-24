import 'package:uuid/uuid.dart';

enum NutribotState { idle, typing, thinking, streaming, done, error }

enum NutribotSource {
  general,
  home,
  mealLog,
  recipeBrowser,
  mealPlanner,
  community,
  profile,
  foodScanner,
}

class NutribotMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;

  NutribotMessage({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.isStreaming = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  NutribotMessage copyWith({String? content, bool? isStreaming}) =>
      NutribotMessage(
        id: id,
        content: content ?? this.content,
        isUser: isUser,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class NutribotContext {
  final NutribotSource source;
  final String? contextTitle;
  final String? sourceContext;
  final String? initialPrompt;
  final Map<String, dynamic>? attachedMeal;
  final Map<String, dynamic>? attachedRecipe;
  final String? userGoal;
  final Map<String, dynamic>? data;

  const NutribotContext({
    required this.source,
    this.contextTitle,
    this.sourceContext,
    this.initialPrompt,
    this.attachedMeal,
    this.attachedRecipe,
    this.userGoal,
    this.data,
  });

  String get label {
    if (contextTitle != null && contextTitle!.trim().isNotEmpty) {
      return contextTitle!;
    }
    return switch (source) {
      NutribotSource.home => 'Home Assistant',
      NutribotSource.mealLog => 'Meal Log',
      NutribotSource.recipeBrowser => 'Recipe Helper',
      NutribotSource.mealPlanner => 'Meal Planner',
      NutribotSource.community => 'Community Helper',
      NutribotSource.profile => 'Profile Insights',
      NutribotSource.foodScanner => 'Food Scan',
      NutribotSource.general => '',
    };
  }

  String? get detailLabel {
    if (sourceContext != null && sourceContext!.trim().isNotEmpty) {
      return sourceContext!.trim();
    }
    final value = label.trim();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> get metadata {
    return {
      if (sourceContext != null && sourceContext!.trim().isNotEmpty)
        'sourceContext': sourceContext!.trim(),
      if (initialPrompt != null && initialPrompt!.trim().isNotEmpty)
        'initialPrompt': initialPrompt!.trim(),
      if (attachedMeal != null && attachedMeal!.isNotEmpty)
        'attachedMeal': attachedMeal,
      if (attachedRecipe != null && attachedRecipe!.isNotEmpty)
        'attachedRecipe': attachedRecipe,
      if (userGoal != null && userGoal!.trim().isNotEmpty)
        'userGoal': userGoal!.trim(),
      if (data != null && data!.isNotEmpty) 'data': data,
    };
  }

  List<String> get quickChips => switch (source) {
        NutribotSource.home => [
            'Plan my day',
            'What should I eat next?',
            'Stay within my budget',
            'Healthy local meals',
          ],
        NutribotSource.mealLog => [
            'Analyze this meal',
            'Improve my macros',
            'Suggest a healthy swap',
            'Explain calories',
          ],
        NutribotSource.recipeBrowser => [
            'Make it healthier',
            'Substitute ingredients',
            'Calorie breakdown',
            'Cheaper version',
          ],
        NutribotSource.mealPlanner => [
            'Optimize my plan',
            'Lower my budget',
            'Add more variety',
            'Boost protein',
          ],
        NutribotSource.community => [
            'Improve my post',
            'Add nutrition info',
            'Suggest better tags',
            'Make it engaging',
          ],
        NutribotSource.profile => [
            'Plan around my goal',
            'Use my budget better',
            'Improve my routine',
            'Weekly focus',
          ],
        NutribotSource.foodScanner => [
            'Explain nutrients',
            'Healthy pairings',
            'Portion advice',
            'Healthier choice',
          ],
        NutribotSource.general => [
            'Analyze my meal',
            'Suggest breakfast',
            'High protein meals',
            'Low budget options',
          ],
      };
}

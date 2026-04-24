class EngagementConfig {
  EngagementConfig._();

  // App-config product rules. These are intentionally centralized so point,
  // badge, and ranking policy can later move to Firestore/Remote Config.
  static const rulesSource = 'app_config_product_rules';

  static const leaderboardQueryLimit = 50;
  static const leaderboardDisplayLimit = 10;
  static const leaderboardPrimarySort = 'points_desc';
  static const leaderboardTieBreakSort = 'displayName_asc';

  static const communityHelperCommentThreshold = 5;
  static const consistentPlannerWeeklyMealThreshold = 4;
  static const mealLoggingStreakDays = 7;

  static const firstMealLoggedBadge = 'first_meal_logged';
  static const firstFoodScanBadge = 'first_food_scan';
  static const firstPostSharedBadge = 'first_post_shared';
  static const communityHelperBadge = 'community_helper';
  static const budgetSaverBadge = 'budget_saver';
  static const recipeExplorerBadge = 'recipe_explorer';
  static const consistentPlannerBadge = 'consistent_planner';
  static const sevenDayMealLoggingStreakBadge = 'seven_day_meal_logging_streak';

  static const actionRules = <String, EngagementActionRule>{
    'mealLogged': EngagementActionRule(
      counterField: 'mealsLogged',
      points: 10,
    ),
    'scannedMeal': EngagementActionRule(
      counterField: 'scannedMeals',
      points: 15,
    ),
    'recipeSaved': EngagementActionRule(
      counterField: 'recipesSaved',
      points: 10,
    ),
    'postCreated': EngagementActionRule(
      counterField: 'postsCreated',
      points: 8,
    ),
    'commentCreated': EngagementActionRule(
      counterField: 'commentsCreated',
      points: 5,
    ),
    'budgetFriendlyMeal': EngagementActionRule(
      counterField: 'budgetFriendlyMeals',
      points: 10,
    ),
    'plannedMealSaved': EngagementActionRule(
      counterField: 'plannedMealsSaved',
      points: 0,
    ),
  };

  static const badgeDefinitions = <String, EngagementBadgeDefinition>{
    firstMealLoggedBadge: EngagementBadgeDefinition(
      title: 'First Meal Logged',
      description: 'Logged your first meal in NutriMind.',
      icon: 'restaurant_menu',
    ),
    firstFoodScanBadge: EngagementBadgeDefinition(
      title: 'First Food Scan',
      description: 'Saved your first scanned meal.',
      icon: 'document_scanner',
    ),
    firstPostSharedBadge: EngagementBadgeDefinition(
      title: 'First Post Shared',
      description: 'Shared your first post with the community.',
      icon: 'forum',
    ),
    communityHelperBadge: EngagementBadgeDefinition(
      title: 'Community Helper',
      description: 'Joined the conversation with helpful comments.',
      icon: 'volunteer_activism',
    ),
    budgetSaverBadge: EngagementBadgeDefinition(
      title: 'Budget Saver',
      description: 'Kept a logged meal day within your food budget.',
      icon: 'savings',
    ),
    recipeExplorerBadge: EngagementBadgeDefinition(
      title: 'Recipe Explorer',
      description: 'Saved an AI or dataset recipe.',
      icon: 'auto_awesome',
    ),
    consistentPlannerBadge: EngagementBadgeDefinition(
      title: 'Consistent Planner',
      description: 'Saved four planned meals in one week.',
      icon: 'event_available',
    ),
    sevenDayMealLoggingStreakBadge: EngagementBadgeDefinition(
      title: '7-Day Meal Logging Streak',
      description: 'Logged meals across seven consecutive days.',
      icon: 'local_fire_department',
    ),
  };

  static EngagementActionRule actionRuleFor(String key) {
    return actionRules[key] ??
        EngagementActionRule(counterField: key, points: 0);
  }

  static EngagementBadgeDefinition badgeDefinitionFor(String badgeId) {
    return badgeDefinitions[badgeId] ??
        EngagementBadgeDefinition(
          title: badgeId,
          description: 'Earned from real NutriMind activity.',
          icon: 'emoji_events',
        );
  }

  static int compareLeaderboardRows({
    required int aPoints,
    required String aDisplayName,
    required int bPoints,
    required String bDisplayName,
  }) {
    final pointCompare = bPoints.compareTo(aPoints);
    if (pointCompare != 0) return pointCompare;
    return aDisplayName.compareTo(bDisplayName);
  }
}

class EngagementActionRule {
  const EngagementActionRule({
    required this.counterField,
    required this.points,
  });

  final String counterField;
  final int points;
}

class EngagementBadgeDefinition {
  const EngagementBadgeDefinition({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final String icon;
}

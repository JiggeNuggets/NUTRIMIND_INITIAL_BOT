import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../models/badge_model.dart';
import '../../models/weekly_stats_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../services/engagement_service.dart';
import '../../widgets/state_views.dart';
import '../onboarding/splash_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final EngagementService _engagementService = EngagementService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final mealProv = context.watch<MealProvider>();

    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.bgGreen,
        surfaceTintColor: Colors.transparent,
        title: const Text('NutriMind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: AppTheme.softGreen,
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28))
                          : null,
                    ),
                    if (user?.isPremium == true)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.orangeAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Loading...',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark)),
                      Text(user?.email ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMid)),
                      const SizedBox(height: 4),
                      Text(
                          'Health Enthusiast • ${user?.location ?? 'Davao City'}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textLight)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ModernAppTheme.white,
                    ModernAppTheme.softGreen.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
                border: Border.all(color: ModernAppTheme.divider),
                boxShadow: ModernAppTheme.shadowSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statBox('${user?.weight.toStringAsFixed(1) ?? '--'} kg',
                      'Weight'),
                  _vDiv(),
                  _statBox('${user?.height.toStringAsFixed(0) ?? '--'} cm',
                      'Height'),
                  _vDiv(),
                  _statBox(_dailyBudgetLabel(user), 'Daily Budget'),
                  _vDiv(),
                  _statBox('${mealProv.loggedCount}', "Today's Logs"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BMI Card
            _buildBMICard(user),
            const SizedBox(height: 24),

            // DSS Settings
            _buildDSSSettings(context, user),
            const SizedBox(height: 24),

            // Milestones
            _buildMilestones(user?.uid ?? ''),
            const SizedBox(height: 24),

            // Account menu
            _buildAccountMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.primaryGreen)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMid)),
      ],
    );
  }

  String _dailyBudgetLabel(dynamic user) {
    if (user == null ||
        user.budgetConfigured != true ||
        user.dailyBudget <= 0) {
      return '--';
    }
    return '${AppTheme.currency}${user.dailyBudget.toStringAsFixed(0)}';
  }

  Widget _vDiv() => Container(
      width: 1, height: 28, color: AppTheme.accentGreen.withValues(alpha: 0.4));

  Widget _buildBMICard(user) {
    if (user == null) return const SizedBox.shrink();
    final weight = (user.weight as double?) ?? 0;
    final height = (user.height as double?) ?? 0;
    if (weight <= 0 || height <= 0) return const SizedBox.shrink();

    final heightM = height / 100;
    final bmi = weight / (heightM * heightM);

    String category;
    Color bmiColor;
    String advice;
    if (bmi < 18.5) {
      category = 'Underweight';
      bmiColor = AppTheme.infoBlue;
      advice = 'Consider nutrient-dense foods to gain healthy weight.';
    } else if (bmi < 25) {
      category = 'Normal';
      bmiColor = AppTheme.primaryGreen;
      advice = 'Great! Maintain your healthy lifestyle.';
    } else if (bmi < 30) {
      category = 'Overweight';
      bmiColor = AppTheme.orangeAccent;
      advice = 'Focus on balanced meals and regular physical activity.';
    } else {
      category = 'Obese';
      bmiColor = AppTheme.errorRed;
      advice = 'Consult a nutritionist for a personalized plan.';
    }

    final pct = ((bmi - 10) / 30).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        border: Border.all(color: bmiColor.withValues(alpha: 0.3)),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: bmiColor, size: 18),
              const SizedBox(width: 8),
              const Text('Body Mass Index (BMI)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(bmi.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: bmiColor)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bmiColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(category,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: bmiColor)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(bmiColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('<18.5',
                  style: TextStyle(fontSize: 9, color: AppTheme.textLight)),
              Text('18.5–24.9',
                  style: TextStyle(fontSize: 9, color: AppTheme.textLight)),
              Text('25–29.9',
                  style: TextStyle(fontSize: 9, color: AppTheme.textLight)),
              Text('≥30',
                  style: TextStyle(fontSize: 9, color: AppTheme.textLight)),
            ],
          ),
          const SizedBox(height: 10),
          Text(advice,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textMid, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildDSSSettings(BuildContext context, user) {
    final u = user;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        border: Border.all(color: ModernAppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: AppTheme.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text('DSS Intelligence Settings',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Adjust how the AI Decision Support System powers your nutritional goals.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textMid, height: 1.4)),
          const SizedBox(height: 14),

          // Budget slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Budget',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              Text('₱${(u?.dailyBudget ?? 150).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          SliderTheme(
            data: const SliderThemeData(
              activeTrackColor: AppTheme.primaryGreen,
              inactiveTrackColor: Color(0xFFB7DFB7),
              thumbColor: AppTheme.primaryGreen,
              trackHeight: 4,
            ),
            child: Slider(
              value: (u?.dailyBudget ?? 150).clamp(50, 500),
              min: 50,
              max: 500,
              divisions: 45,
              onChanged: (v) {},
              onChangeEnd: (v) => _updateSettings(
                context,
                dailyBudget: v,
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₱50',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 10)),
              Text('₱500',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),

          // Budget Buffer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget Buffer',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              Text('${(u?.budgetBuffer ?? 15).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen)),
            ],
          ),
          SliderTheme(
            data: const SliderThemeData(
              activeTrackColor: AppTheme.primaryGreen,
              inactiveTrackColor: Color(0xFFB7DFB7),
              thumbColor: AppTheme.primaryGreen,
              trackHeight: 4,
            ),
            child: Slider(
              value: (u?.budgetBuffer ?? 15).clamp(0, 50),
              min: 0,
              max: 50,
              divisions: 10,
              onChanged: (v) {},
              onChangeEnd: (v) => _updateSettings(
                context,
                budgetBuffer: v,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Allow non-local
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allow non-local foods',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark)),
                    Text('Expands beyond Davao-origin products',
                        style:
                            TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
              Switch(
                value: u?.allowNonLocal ?? false,
                onChanged: (v) => _updateSettings(
                  context,
                  allowNonLocal: v,
                ),
                activeThumbColor: AppTheme.primaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestones(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Milestones',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark)),
        const Text("Track your journey through Davao's flavors.",
            style: TextStyle(fontSize: 12, color: AppTheme.textMid)),
        const SizedBox(height: 14),

        const Text('Your Badges',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark)),
        const SizedBox(height: 10),
        if (uid.isEmpty)
          _emptyMilestoneBox('Sign in to earn and view your badges.')
        else
          _BadgesSection(uid: uid, engagementService: _engagementService),
        const SizedBox(height: 20),

        // Weekly leaderboard
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weekly Rankings',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark)),
            Text('Davao City',
                style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ],
        ),
        const SizedBox(height: 10),
        _LeaderboardSection(
          currentUid: uid,
          engagementService: _engagementService,
        ),
      ],
    );
  }

  Widget _emptyMilestoneBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.textMid,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildAccountMenu(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Overview',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
            border: Border.all(color: AppTheme.divider),
            boxShadow: ModernAppTheme.shadowSm,
          ),
          child: Column(
            children: [
              _menuItem(
                  Icons.person_outline,
                  'Personal Info',
                  AppTheme.textDark,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()))),
              const Divider(height: 1, indent: 56, color: AppTheme.divider),
              _menuItem(Icons.trending_up_outlined, 'Progress',
                  AppTheme.textDark, () {}),
              const Divider(height: 1, indent: 56, color: AppTheme.divider),
              _menuItem(Icons.leaderboard_outlined, 'Ranking',
                  AppTheme.textDark, () {}),
              const Divider(height: 1, indent: 56, color: AppTheme.divider),
              _menuItem(Icons.logout, 'Logout', AppTheme.errorRed,
                  () => _confirmLogout(context),
                  showChevron: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label, Color color, VoidCallback onTap,
      {bool showChevron = true}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      trailing: showChevron
          ? const Icon(Icons.chevron_right, color: AppTheme.textLight, size: 18)
          : null,
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textMid)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              minimumSize: const Size(0, 42),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSettings(
    BuildContext context, {
    double? dailyBudget,
    double? budgetBuffer,
    bool? allowNonLocal,
  }) async {
    try {
      await context.read<AuthProvider>().updateSettings(
            dailyBudget: dailyBudget,
            budgetBuffer: budgetBuffer,
            allowNonLocal: allowNonLocal,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save profile setting. Please try again.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

IconData _profileBadgeIcon(String icon) {
  return switch (icon) {
    'restaurant_menu' => Icons.restaurant_menu,
    'document_scanner' => Icons.document_scanner_outlined,
    'forum' => Icons.forum_outlined,
    'volunteer_activism' => Icons.volunteer_activism_outlined,
    'savings' => Icons.savings_outlined,
    'auto_awesome' => Icons.auto_awesome,
    'event_available' => Icons.event_available_outlined,
    'local_fire_department' => Icons.local_fire_department_outlined,
    _ => Icons.emoji_events_outlined,
  };
}

Widget _profileBadgeTile(BadgeModel badge) {
  return SizedBox(
    width: 76,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.softGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Icon(
            _profileBadgeIcon(badge.icon),
            color: AppTheme.primaryGreen,
            size: 25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          badge.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    ),
  );
}

String _profileLeaderSubtitle(WeeklyStatsModel stat) {
  final parts = <String>[
    if (stat.mealsLogged > 0) '${stat.mealsLogged} meals',
    if (stat.scannedMeals > 0) '${stat.scannedMeals} scans',
    if (stat.postsCreated > 0) '${stat.postsCreated} posts',
    if (stat.commentsCreated > 0) '${stat.commentsCreated} comments',
    if (stat.recipesSaved > 0) '${stat.recipesSaved} recipes',
  ];
  return parts.isEmpty ? 'Active this week' : parts.take(3).join(', ');
}

Widget _profileRankRow({
  required int rank,
  required WeeklyStatsModel stat,
  required bool isYou,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: isYou ? AppTheme.softGreen : AppTheme.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isYou ? AppTheme.accentGreen : AppTheme.divider,
      ),
      boxShadow: isYou ? ModernAppTheme.shadowSm : ModernAppTheme.shadowNone,
    ),
    child: Row(
      children: [
        Text('$rank',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: rank == 1 ? AppTheme.primaryGreen : AppTheme.textMid)),
        const SizedBox(width: 14),
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.softGreen,
          backgroundImage:
              stat.photoUrl != null ? NetworkImage(stat.photoUrl!) : null,
          child: stat.photoUrl == null
              ? Text(stat.displayName.isNotEmpty ? stat.displayName[0] : 'U',
                  style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stat.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textDark)),
              Text(_profileLeaderSubtitle(stat),
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMid)),
            ],
          ),
        ),
        Text('${stat.points} pts',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.primaryGreen)),
      ],
    ),
  );
}

/// Streams the signed-in user's badges with a retry button on failure.
class _BadgesSection extends StatefulWidget {
  const _BadgesSection({
    required this.uid,
    required this.engagementService,
  });

  final String uid;
  final EngagementService engagementService;

  @override
  State<_BadgesSection> createState() => _BadgesSectionState();
}

class _BadgesSectionState extends State<_BadgesSection> {
  int _retryTick = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BadgeModel>>(
      key: ValueKey('badges-${widget.uid}-$_retryTick'),
      stream: widget.engagementService.badgesStream(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingStateView(),
          );
        }
        if (snapshot.hasError) {
          return InlineErrorStateCard(
            error: snapshot.error,
            message: 'Could not load badges.',
            onRetry: () => setState(() => _retryTick++),
          );
        }
        final badges = snapshot.data ?? const <BadgeModel>[];
        if (badges.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Text(
              'No badges earned yet. Start logging meals to earn your first badge.',
              style: TextStyle(
                color: AppTheme.textMid,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: badges.map(_profileBadgeTile).toList(growable: false),
        );
      },
    );
  }
}

/// Streams the weekly leaderboard with a retry button on failure.
class _LeaderboardSection extends StatefulWidget {
  const _LeaderboardSection({
    required this.currentUid,
    required this.engagementService,
  });

  final String currentUid;
  final EngagementService engagementService;

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  int _retryTick = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WeeklyStatsModel>>(
      key: ValueKey('leaderboard-$_retryTick'),
      stream: widget.engagementService.weeklyLeaderboardStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingStateView(),
          );
        }
        if (snapshot.hasError) {
          return InlineErrorStateCard(
            error: snapshot.error,
            message: 'Could not load weekly rankings.',
            onRetry: () => setState(() => _retryTick++),
          );
        }
        final leaders = snapshot.data ?? const <WeeklyStatsModel>[];
        if (leaders.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Text(
              'No weekly activity yet.',
              style: TextStyle(
                color: AppTheme.textMid,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          );
        }
        return Column(
          children: leaders.asMap().entries.map((entry) {
            return _profileRankRow(
              rank: entry.key + 1,
              stat: entry.value,
              isYou: entry.value.uid == widget.currentUid,
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

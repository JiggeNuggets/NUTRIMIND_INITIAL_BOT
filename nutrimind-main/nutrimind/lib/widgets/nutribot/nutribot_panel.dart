import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nutribot_models.dart';
import '../../providers/nutribot_provider.dart';
import '../../theme/modern_app_theme.dart';
import 'chat_bubble_widget.dart';
import 'composer_widget.dart';
import 'nutri_orb_widget.dart';

class NutriBotPanel extends StatelessWidget {
  const NutriBotPanel({
    super.key,
    this.nutribotContext,
    this.onBack,
    this.showHeader = true,
  });

  final NutribotContext? nutribotContext;
  final VoidCallback? onBack;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NutriBotController(nutribotContext: nutribotContext),
      child: _NutriBotPanelView(
        nutribotContext: nutribotContext,
        onBack: onBack,
        showHeader: showHeader,
      ),
    );
  }
}

class _NutriBotPanelView extends StatefulWidget {
  const _NutriBotPanelView({
    required this.showHeader,
    this.nutribotContext,
    this.onBack,
  });

  final NutribotContext? nutribotContext;
  final VoidCallback? onBack;
  final bool showHeader;

  @override
  State<_NutriBotPanelView> createState() => _NutriBotPanelViewState();
}

class _NutriBotPanelViewState extends State<_NutriBotPanelView> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _didBootstrap = false;
  String? _lastScrollSignature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didBootstrap) return;
    _didBootstrap = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NutriBotController>().bootstrapInitialPrompt();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NutriBotPanelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nutribotContext != widget.nutribotContext) {
      context.read<NutriBotController>().updateContext(widget.nutribotContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NutriBotController>(
      builder: (context, bot, _) {
        _scheduleScrollIfNeeded(bot);

        final panelCopy = _PanelCopy.fromContext(bot.nutribotContext);
        final actions = panelCopy.actions.take(4).toList(growable: false);

        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFF6FBF7),
          ),
          child: Column(
            children: [
              if (widget.showHeader) _NutriBotHeader(onBack: widget.onBack),
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  children: [
                    _AiCoreSection(
                      state: bot.botState,
                      statusText: bot.statusText,
                    ),
                    const SizedBox(height: 18),
                    _PrimaryActions(
                      actions: actions,
                      enabled: !bot.isBusy,
                      onSelected: bot.sendMessage,
                    ),
                    const SizedBox(height: 16),
                    _SuggestionCard(
                      suggestion: panelCopy.suggestion,
                      suggestionPrompt: panelCopy.suggestionPrompt,
                      enabled: !bot.isBusy,
                      onUseSuggestion: bot.sendMessage,
                    ),
                    if (bot.messages.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      ...bot.messages.map((message) => ChatBubble(
                            message: message,
                          )),
                    ],
                  ],
                ),
              ),
              ComposerWidget(
                onSend: bot.sendMessage,
                onTypingChanged: bot.onTypingChanged,
                botState: bot.botState,
              ),
            ],
          ),
        );
      },
    );
  }

  void _scheduleScrollIfNeeded(NutriBotController bot) {
    if (bot.messages.isEmpty) return;
    final last = bot.messages.last;
    final signature =
        '${bot.messages.length}:${last.content.length}:${last.isStreaming}';
    if (_lastScrollSignature == signature) return;
    _lastScrollSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _NutriBotHeader extends StatelessWidget {
  const _NutriBotHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: ModernAppTheme.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: ModernAppTheme.textDark,
            tooltip: 'Back',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NutriBot',
                  style: TextStyle(
                    color: ModernAppTheme.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 3),
                _OnlineStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineStatus extends StatelessWidget {
  const _OnlineStatus();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Online',
          style: TextStyle(
            color: ModernAppTheme.primaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AiCoreSection extends StatelessWidget {
  const _AiCoreSection({
    required this.state,
    required this.statusText,
  });

  final NutribotState state;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          NutriOrb(state: state, size: 58),
          const SizedBox(height: 4),
          const Text(
            'How can I help you today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ModernAppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              statusText,
              key: ValueKey(statusText),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ModernAppTheme.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.actions,
    required this.enabled,
    required this.onSelected,
  });

  final List<_PanelAction> actions;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final action = actions[index];
          return _ActionButton(
            action: action,
            enabled: enabled,
            onTap: () => onSelected(action.prompt),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final _PanelAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ModernAppTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  color: ModernAppTheme.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  action.label,
                  style: const TextStyle(
                    color: ModernAppTheme.textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.suggestionPrompt,
    required this.enabled,
    required this.onUseSuggestion,
  });

  final String suggestion;
  // Prompt sent to NutriBot when the user taps "Use Suggestion". NutriBot only
  // streams a chat reply in response; it does NOT write to Firestore, the meal
  // planner, meal log, community draft, scanner, or profile. Labels and copy
  // must reflect that it is advice, not an applied change.
  final String suggestionPrompt;
  final bool enabled;
  final ValueChanged<String> onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ModernAppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: ModernAppTheme.softGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: ModernAppTheme.primaryGreen,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Suggestion',
                  style: TextStyle(
                    color: ModernAppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    enabled ? () => onUseSuggestion(suggestionPrompt) : null,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Use Suggestion'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggestion,
            style: const TextStyle(
              color: ModernAppTheme.textMid,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 13,
                color: ModernAppTheme.textLight,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'NutriBot gives advice only. It will not change your meal plan, meal log, or post.',
                  style: TextStyle(
                    color: ModernAppTheme.textLight,
                    fontSize: 11,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelAction {
  const _PanelAction({
    required this.label,
    required this.prompt,
    required this.icon,
  });

  final String label;
  final String prompt;
  final IconData icon;
}

class _PanelCopy {
  const _PanelCopy({
    required this.actions,
    required this.suggestion,
    required this.suggestionPrompt,
  });

  final List<_PanelAction> actions;
  final String suggestion;
  // Prompt sent to NutriBot when the user taps "Use Suggestion". The bot
  // replies as chat only; nothing is written to Firestore or feature state.
  final String suggestionPrompt;

  factory _PanelCopy.fromContext(NutribotContext? context) {
    final source = context?.source ?? NutribotSource.general;

    return switch (source) {
      NutribotSource.community => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Improve my post',
              prompt:
                  'Improve my food post so it is clear, helpful, and friendly.',
              icon: Icons.edit_note_rounded,
            ),
            _PanelAction(
              label: 'Add nutrition info',
              prompt: 'Add a short nutrition insight to this community post.',
              icon: Icons.monitor_heart_outlined,
            ),
            _PanelAction(
              label: 'Suggest better tags',
              prompt: 'Suggest focused tags for this community food post.',
              icon: Icons.sell_outlined,
            ),
            _PanelAction(
              label: 'Make it engaging',
              prompt:
                  'Make this post more engaging while keeping it practical.',
              icon: Icons.chat_bubble_outline_rounded,
            ),
          ],
          suggestion:
              'Keep the post useful: one personal detail, one nutrition takeaway, and a simple question for the community.',
          suggestionPrompt:
              'Using this suggestion, show me a polished draft I could copy into my community post. Do not claim you saved or updated anything.',
        ),
      NutribotSource.foodScanner => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Explain nutrients',
              prompt: 'Explain the key nutrients in this scanned food.',
              icon: Icons.insights_outlined,
            ),
            _PanelAction(
              label: 'Healthy pairings',
              prompt: 'Suggest healthy pairings for this scanned food.',
              icon: Icons.restaurant_menu_outlined,
            ),
            _PanelAction(
              label: 'Portion advice',
              prompt: 'Give practical portion advice for this scanned food.',
              icon: Icons.pie_chart_outline_rounded,
            ),
            _PanelAction(
              label: 'Healthier choice',
              prompt: 'Suggest a healthier version of this food.',
              icon: Icons.eco_outlined,
            ),
          ],
          suggestion:
              'Review portion size, cooking method, and a vegetable or protein pairing before saving the scan.',
          suggestionPrompt:
              'Using the scan context, explain what I should review before saving. Give advice only.',
        ),
      NutribotSource.mealPlanner => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Optimize my plan',
              prompt:
                  'Optimize my meal plan for my goal, budget, and calories.',
              icon: Icons.tune_rounded,
            ),
            _PanelAction(
              label: 'Lower my budget',
              prompt: 'Lower the cost of my meal plan without losing balance.',
              icon: Icons.savings_outlined,
            ),
            _PanelAction(
              label: 'Add variety',
              prompt: 'Add more variety to my meal plan.',
              icon: Icons.shuffle_rounded,
            ),
            _PanelAction(
              label: 'Boost protein',
              prompt: 'Boost protein in my plan using affordable local foods.',
              icon: Icons.fitness_center_rounded,
            ),
          ],
          suggestion:
              'Balance protein, fiber, and budget first. Variety works best after the daily targets are covered.',
          suggestionPrompt:
              'Show me how this planning rule would look for my current meal planner context. Suggest only — I will edit the planner myself.',
        ),
      NutribotSource.mealLog => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Analyze this meal',
              prompt: 'Analyze my current meal log and find one improvement.',
              icon: Icons.analytics_outlined,
            ),
            _PanelAction(
              label: 'Improve macros',
              prompt: 'Suggest a macro improvement for my logged meals.',
              icon: Icons.donut_large_rounded,
            ),
            _PanelAction(
              label: 'Healthy swap',
              prompt: 'Suggest a healthier swap for my current meals.',
              icon: Icons.swap_horiz_rounded,
            ),
            _PanelAction(
              label: 'Explain calories',
              prompt: 'Explain my calories in simple terms.',
              icon: Icons.local_fire_department_outlined,
            ),
          ],
          suggestion:
              'Start with the highest-impact meal: add protein or vegetables before changing the whole day.',
          suggestionPrompt:
              'Explain how this suggestion would fit my current meal log. Give advice only — I will update my meals myself.',
        ),
      NutribotSource.recipeBrowser => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Make healthier',
              prompt: 'Make this recipe healthier without losing flavor.',
              icon: Icons.eco_outlined,
            ),
            _PanelAction(
              label: 'Swap ingredients',
              prompt: 'Suggest ingredient substitutions for this recipe.',
              icon: Icons.swap_horiz_rounded,
            ),
            _PanelAction(
              label: 'Calories',
              prompt: 'Explain the calorie breakdown for this recipe.',
              icon: Icons.local_fire_department_outlined,
            ),
            _PanelAction(
              label: 'Cheaper version',
              prompt: 'Make this recipe cheaper with local ingredients.',
              icon: Icons.payments_outlined,
            ),
          ],
          suggestion:
              'A good recipe tweak changes one thing at a time: oil, portion, vegetable volume, or protein.',
          suggestionPrompt:
              'Show how this recipe tweak would work for my current recipe. Give advice only.',
        ),
      NutribotSource.profile => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Plan goal',
              prompt: 'Plan meals around my current health goal.',
              icon: Icons.flag_outlined,
            ),
            _PanelAction(
              label: 'Use budget',
              prompt: 'Help me use my food budget better.',
              icon: Icons.savings_outlined,
            ),
            _PanelAction(
              label: 'Build routine',
              prompt: 'Suggest a realistic nutrition routine for me.',
              icon: Icons.calendar_month_outlined,
            ),
            _PanelAction(
              label: 'Weekly focus',
              prompt: 'Give me one weekly nutrition focus.',
              icon: Icons.check_circle_outline,
            ),
          ],
          suggestion:
              'Your profile is most useful when it becomes one repeatable habit, not a complicated rule set.',
          suggestionPrompt:
              'Using my profile context, suggest one nutrition habit I could try this week. Advice only.',
        ),
      NutribotSource.home => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Plan my day',
              prompt: 'Plan one practical nutrition focus for my day.',
              icon: Icons.today_outlined,
            ),
            _PanelAction(
              label: 'Next meal',
              prompt: 'Suggest what I should eat next.',
              icon: Icons.restaurant_menu_outlined,
            ),
            _PanelAction(
              label: 'Stay on budget',
              prompt: 'Help me stay within my food budget today.',
              icon: Icons.savings_outlined,
            ),
            _PanelAction(
              label: 'Local meals',
              prompt: 'Suggest healthy local Davao meals.',
              icon: Icons.location_on_outlined,
            ),
          ],
          suggestion:
              'Choose one realistic nutrition win for today, then let your meals support that choice.',
          suggestionPrompt:
              'Using my dashboard context, suggest one nutrition focus I could aim for today. Advice only.',
        ),
      NutribotSource.general => const _PanelCopy(
          actions: [
            _PanelAction(
              label: 'Analyze meal',
              prompt: 'Analyze my meal and suggest one improvement.',
              icon: Icons.analytics_outlined,
            ),
            _PanelAction(
              label: 'Breakfast',
              prompt: 'Suggest a healthy affordable breakfast.',
              icon: Icons.breakfast_dining_outlined,
            ),
            _PanelAction(
              label: 'High protein',
              prompt: 'Suggest high-protein affordable meals.',
              icon: Icons.fitness_center_rounded,
            ),
            _PanelAction(
              label: 'Low budget',
              prompt: 'Suggest low-budget balanced meals.',
              icon: Icons.savings_outlined,
            ),
          ],
          suggestion:
              'Ask for one clear outcome at a time: meal idea, food swap, nutrition explanation, or budget check.',
          suggestionPrompt:
              'Help me choose the best next nutrition question to ask. Advice only.',
        ),
    };
  }
}

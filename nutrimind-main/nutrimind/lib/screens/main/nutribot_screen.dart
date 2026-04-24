import 'package:flutter/material.dart';

import '../../models/nutribot_models.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/nutribot/nutribot_panel.dart';

class NutribotScreen extends StatelessWidget {
  const NutribotScreen({super.key, this.nutribotContext});

  final NutribotContext? nutribotContext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ModernAppTheme.bgGreen,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: NutriBotPanel(
              nutribotContext: nutribotContext,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }
}

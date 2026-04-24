import 'package:flutter/material.dart';

import '../../models/nutribot_models.dart';
import 'nutribot_screen.dart';

/// Legacy route shim that forwards to the shared NutriBot screen.
@Deprecated('Use NutribotScreen directly.')
class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key, this.nutribotContext});

  final NutribotContext? nutribotContext;

  @override
  Widget build(BuildContext context) {
    return NutribotScreen(nutribotContext: nutribotContext);
  }
}

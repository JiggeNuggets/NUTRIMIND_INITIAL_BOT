import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/profile_setup_screen.dart';
import '../onboarding/splash_screen.dart';
import '../main/main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2D6A4F),
                ),
              ),
            );
          case AuthStatus.authenticated:
            final user = auth.userModel;
            if (user == null) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2D6A4F),
                  ),
                ),
              );
            }
            if (_needsSetup(user)) {
              return const ProfileSetupScreen();
            }
            return const MainShell();
          case AuthStatus.unauthenticated:
            return const SplashScreen();
        }
      },
    );
  }

  bool _needsSetup(UserModel user) {
    if (!user.profileCompleted) return true;
    if (!user.budgetConfigured) return true;
    if (user.age <= 0) return true;
    if (user.height <= 0) return true;
    if (user.weight <= 0) return true;
    if (user.dailyBudget <= 0) return true;
    final gender = user.gender.trim().toLowerCase();
    if (gender != 'male' && gender != 'female' && gender != 'other') {
      return true;
    }
    if (user.goal.trim().isEmpty) return true;
    return false;
  }
}

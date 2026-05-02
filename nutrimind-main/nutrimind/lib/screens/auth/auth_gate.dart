import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../main/main_shell.dart';
import '../onboarding/profile_setup_screen.dart';
import '../onboarding/splash_screen.dart';

const String _profileUnavailableMessage =
    'We could not load your profile. Please check your connection and try again.';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const _AuthGateLoadingView();
          case AuthStatus.authenticated:
            final user = auth.userModel;
            if (user == null) {
              return _AuthGateRecoveryView(
                onRetry: auth.retryProfileLoad,
                onSignOut: auth.signOut,
              );
            }
            if (_needsSetup(user)) {
              return const ProfileSetupScreen();
            }
            return const MainShell();
          case AuthStatus.profileLoadFailed:
            return _AuthGateRecoveryView(
              onRetry: auth.retryProfileLoad,
              onSignOut: auth.signOut,
            );
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

class _AuthGateLoadingView extends StatelessWidget {
  const _AuthGateLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2D6A4F),
        ),
      ),
    );
  }
}

class _AuthGateRecoveryView extends StatelessWidget {
  const _AuthGateRecoveryView({
    required this.onRetry,
    required this.onSignOut,
  });

  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 48
                      ? constraints.maxHeight - 48
                      : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_circle_outlined,
                          size: 56,
                          color: Color(0xFF2D6A4F),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Profile unavailable',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          _profileUnavailableMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF5F6B66),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => onRetry(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D6A4F),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Retry'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => onSignOut(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2D6A4F),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Sign out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

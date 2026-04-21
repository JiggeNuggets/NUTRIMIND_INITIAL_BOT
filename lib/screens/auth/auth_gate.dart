import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
            return const MainShell();
          case AuthStatus.unauthenticated:
            return const SplashScreen();
        }
      },
    );
  }
}

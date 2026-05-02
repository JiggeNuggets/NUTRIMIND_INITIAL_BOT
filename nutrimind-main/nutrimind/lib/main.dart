import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/modern_app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/meal_provider.dart';
import 'providers/community_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const NutriMindApp());
}

class NutriMindApp extends StatelessWidget {
  const NutriMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'NutriMind',
        debugShowCheckedModeBanner: false,
        theme: ModernAppTheme.lightTheme,
        home: const _AuthScopedProviderCleanup(
          child: AuthGate(),
        ),
      ),
    );
  }
}

class _AuthScopedProviderCleanup extends StatefulWidget {
  const _AuthScopedProviderCleanup({required this.child});

  final Widget child;

  @override
  State<_AuthScopedProviderCleanup> createState() =>
      _AuthScopedProviderCleanupState();
}

class _AuthScopedProviderCleanupState
    extends State<_AuthScopedProviderCleanup> {
  String? _activeUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nextUid = auth.status == AuthStatus.authenticated
        ? auth.userModel?.uid.trim()
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncUserScopedProviders(nextUid);
    });

    return widget.child;
  }

  void _syncUserScopedProviders(String? nextUid) {
    final safeUid = nextUid == null || nextUid.isEmpty ? null : nextUid;
    if (_activeUid == safeUid) return;

    if (_activeUid != null) {
      context.read<MealProvider>().clearUserScopedState();
      context.read<NotificationProvider>().clearUserScopedState();
      context.read<CommunityProvider>().clearAuthScopedState();
    }

    _activeUid = safeUid;
  }
}

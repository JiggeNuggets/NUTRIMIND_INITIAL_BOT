import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main/main_shell.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleGoogle(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (success && context.mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
    } else if (auth.error != null && context.mounted) {
      _showError(context, auth.error!);
      auth.clearError();
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      body: Column(
        children: [
          // Hero image section
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Color(0xFF1A3326)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.35,
                          child: GridView.count(
                            crossAxisCount: 3,
                            physics: const NeverScrollableScrollPhysics(),
                            children: List.generate(
                                15,
                                (i) => Container(
                                      margin: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen.withValues(
                                            alpha: 0.3 + (i % 4) * 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        [
                                          Icons.eco,
                                          Icons.restaurant,
                                          Icons.local_florist,
                                          Icons.grain
                                        ][i % 4],
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        size: 28,
                                      ),
                                    )),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppTheme.darkGreen.withValues(alpha: 0.9)
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Logo
                      Positioned(
                        top: 56,
                        left: 24,
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.eco,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text('NutriMind',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      // Featured card
                      Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.restaurant,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Local Fresh Durian & Pomelo Salad',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text('Davao City • Today\'s Pick',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom CTA
          Expanded(
            flex: 4,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                            children: [
                              TextSpan(text: 'Your Personal\nEditorial Food\n'),
                              TextSpan(
                                  text: 'Sanctuary.',
                                  style:
                                      TextStyle(color: AppTheme.primaryGreen)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'AI-curated Davao local foods, personalized meal plans, budget-smart every day.',
                          style: TextStyle(
                              color: AppTheme.textMid,
                              fontSize: 13,
                              height: 1.55),
                        ),
                        // Avoid Spacer() flex overflow on smaller web viewports.
                        const SizedBox(height: 12),
                        // Google Sign In
                        ElevatedButton.icon(
                          onPressed: auth.loading
                              ? null
                              : () => _handleGoogle(context),
                          icon: auth.loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.g_mobiledata, size: 22),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 10),
                        // Email Sign Up
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen())),
                          icon: const Icon(Icons.email_outlined, size: 18),
                          label: const Text('Sign up with Email',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            side: const BorderSide(
                                color: AppTheme.divider, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            foregroundColor: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Already have account
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen())),
                            child: const Text(
                              'Already have an account? Sign in',
                              style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

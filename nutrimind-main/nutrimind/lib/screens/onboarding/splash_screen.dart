import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
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
    await auth.signInWithGoogle();
    if (auth.firebaseUser != null && context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (auth.error != null && context.mounted) {
      debugPrint('Splash Google sign-in failed: ${auth.error}');
      _showError(context, 'Could not continue with Google. Please try again.');
      auth.clearError();
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.errorRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Hero (55%) ───────────────────────────────────────────────────
          const Expanded(
            flex: 55,
            child: _HeroSection(),
          ),

          // ── Bottom panel (45%) ───────────────────────────────────────────
          Expanded(
            flex: 45,
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Heading
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 31,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                  letterSpacing: -0.7,
                                  height: 1.2,
                                ),
                                children: [
                                  TextSpan(text: 'Your Personal\nFood '),
                                  TextSpan(
                                    text: 'Sanctuary.',
                                    style:
                                        TextStyle(color: AppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Subtitle
                            const Text(
                              'AI-curated Davao local foods, personalized meal plans, and budget-smart choices.',
                              style: TextStyle(
                                color: AppTheme.textMid,
                                fontSize: 13.5,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Continue with Google
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: auth.loading
                                    ? null
                                    : () => _handleGoogle(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E6B45),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: auth.loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'G',
                                                style: TextStyle(
                                                  color: Color(0xFF2E6B45),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Continue with Google',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Sign up with Email
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen())),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textDark,
                                  side: const BorderSide(
                                      color: AppTheme.divider, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.email_outlined,
                                        size: 20, color: AppTheme.primaryGreen),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sign up with Email',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // OR divider
                            const Row(children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: AppTheme.textLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ]),
                            const SizedBox(height: 14),

                            // Already have an account
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen())),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: AppTheme.textMid),
                                    children: [
                                      TextSpan(
                                          text: 'Already have an account? '),
                                      TextSpan(
                                        text: 'Sign in',
                                        style: TextStyle(
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor:
                                              AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2318), Color(0xFF133D24), Color(0xFF1A5230)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative blurred leaf shapes (top-right)
            Positioned(
              top: -30,
              right: -40,
              child: _leafBlob(160, 0.12),
            ),
            Positioned(
              top: 50,
              left: -50,
              child: _leafBlob(130, 0.08),
            ),
            Positioned(
              bottom: 70,
              right: -10,
              child: _leafBlob(100, 0.1),
            ),
            Positioned(
              bottom: 90,
              left: 10,
              child: _leafBlob(80, 0.07),
            ),

            // Center: logo + name + tagline
            Center(
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 3D logo — tries PNG first, falls back to icon composite
                    const _LogoWidget(),
                    const SizedBox(height: 22),

                    // NUTRIMIND gradient text
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'NUTRI',
                            style: TextStyle(color: Color(0xFF76D442)),
                          ),
                          TextSpan(
                            text: 'MIND',
                            style: TextStyle(color: Color(0xFF4BA8E0)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tagline with dashes
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 22,
                            height: 1.5,
                            color: const Color(0xFFFFD54F)),
                        const SizedBox(width: 8),
                        const Text(
                          'NOURISH YOUR BODY. EMPOWER YOUR MIND.',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                            width: 22,
                            height: 1.5,
                            color: const Color(0xFFFFD54F)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leafBlob(double size, double opacity) {
    return Icon(Icons.eco,
        size: size, color: Colors.white.withValues(alpha: opacity));
  }
}

// ── 3D Logo widget ───────────────────────────────────────────────────────────

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    // The PNG logo asset is optional — use the icon composite as the
    // primary logo to avoid a 404 on web when the file is absent.
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Image.asset(
      'assets/images/food/logo/nutrimind_logo_transparent.png',
      width: compact ? 142 : 168,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const _IconLogo(),
    );
  }
}

class _IconLogo extends StatelessWidget {
  const _IconLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      height: 155,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.85,
          colors: [Color(0xFF2A7D42), Color(0xFF0D3B22)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left half — leaf (green)
          Positioned(
            left: 18,
            child: Icon(Icons.eco,
                size: 80,
                color: const Color(0xFF76D442).withValues(alpha: 0.95)),
          ),
          // Right half — brain (blue)
          Positioned(
            right: 18,
            child: Icon(Icons.psychology,
                size: 72,
                color: const Color(0xFF4BA8E0).withValues(alpha: 0.95)),
          ),
          // White center divider line
          Container(
            width: 2.5,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave clipper ─────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 36);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 28,
      size.width,
      size.height - 36,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

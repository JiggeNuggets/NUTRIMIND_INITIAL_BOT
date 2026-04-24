import 'package:flutter/material.dart';
import '../../models/nutribot_models.dart';

class NutriOrb extends StatefulWidget {
  final NutribotState state;
  final double size;

  const NutriOrb({super.key, required this.state, this.size = 110});

  @override
  State<NutriOrb> createState() => _NutriOrbState();
}

class _NutriOrbState extends State<NutriOrb> with TickerProviderStateMixin {
  late AnimationController _breathCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _applyState(widget.state, initial: true);
  }

  @override
  void didUpdateWidget(NutriOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _applyState(widget.state);
    }
  }

  void _applyState(NutribotState state, {bool initial = false}) {
    switch (state) {
      case NutribotState.idle:
      case NutribotState.done:
        _setBreath(3200);
        _setGlow(2600);
        _rippleCtrl.stop();
        _rippleCtrl.reset();

      case NutribotState.typing:
        _setBreath(2000);
        _setGlow(1800);
        _rippleCtrl.stop();
        _rippleCtrl.reset();

      case NutribotState.thinking:
        _setBreath(1100);
        _setGlow(1000);
        _rippleCtrl.duration = const Duration(milliseconds: 1600);
        if (!_rippleCtrl.isAnimating) _rippleCtrl.repeat();

      case NutribotState.streaming:
        _setBreath(700);
        _setGlow(700);
        _rippleCtrl.duration = const Duration(milliseconds: 1100);
        if (!_rippleCtrl.isAnimating) _rippleCtrl.repeat();

      case NutribotState.error:
        _setBreath(2400);
        _setGlow(2000);
        _rippleCtrl.stop();
        _rippleCtrl.reset();
    }
  }

  void _setBreath(int ms) {
    _breathCtrl
      ..stop()
      ..duration = Duration(milliseconds: ms)
      ..repeat(reverse: true);
  }

  void _setGlow(int ms) {
    _glowCtrl
      ..stop()
      ..duration = Duration(milliseconds: ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _glowCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  _OrbColors get _colors => switch (widget.state) {
        NutribotState.error => const _OrbColors(
            glow: Color(0xFFFBBF24),
            coreLight: Color(0xFFFEF3C7),
            coreMid: Color(0xFFFBBF24),
            coreDark: Color(0xFFD97706),
          ),
        NutribotState.streaming => const _OrbColors(
            glow: Color(0xFF10B981),
            coreLight: Color(0xFF6EE7B7),
            coreMid: Color(0xFF34D399),
            coreDark: Color(0xFF047857),
          ),
        _ => const _OrbColors(
            glow: Color(0xFF34D399),
            coreLight: Color(0xFFA7F3D0),
            coreMid: Color(0xFF6EE7B7),
            coreDark: Color(0xFF059669),
          ),
      };

  bool get _showRipple =>
      widget.state == NutribotState.thinking ||
      widget.state == NutribotState.streaming;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final c = _colors;
    final breathMin = widget.state == NutribotState.streaming ? 0.98 : 0.94;
    final breathMax = widget.state == NutribotState.streaming ? 1.07 : 1.05;

    return AnimatedBuilder(
      animation: Listenable.merge([_breathCtrl, _glowCtrl, _rippleCtrl]),
      builder: (_, __) {
        final breathVal =
            breathMin + (breathMax - breathMin) * _breathCtrl.value;
        final glowVal = 0.5 + 0.5 * _glowCtrl.value;

        return SizedBox(
          width: s * 1.65,
          height: s * 1.65,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Ripple rings (thinking / streaming)
              if (_showRipple)
                CustomPaint(
                  size: Size(s * 1.65, s * 1.65),
                  painter: _RipplePainter(
                    progress: _rippleCtrl.value,
                    color: c.glow,
                    maxRadius: s * 0.8,
                  ),
                ),

              // Outer atmospheric glow
              Container(
                width: s * 1.55 * breathVal,
                height: s * 1.55 * breathVal,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.glow.withValues(alpha: 0.13 * glowVal),
                      blurRadius: s * 0.7,
                      spreadRadius: s * 0.08,
                    ),
                  ],
                ),
              ),

              // Mid soft ring
              Container(
                width: s * 1.18,
                height: s * 1.18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.glow.withValues(alpha: 0.10 * glowVal),
                ),
              ),

              // Main orb body with breathing
              Transform.scale(
                scale: breathVal,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [c.coreLight, c.coreMid, c.coreDark],
                      stops: const [0.0, 0.52, 1.0],
                      center: const Alignment(-0.28, -0.28),
                      radius: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.glow.withValues(alpha: 0.55 * glowVal),
                        blurRadius: s * 0.38,
                        offset: Offset(0, s * 0.08),
                      ),
                      BoxShadow(
                        color: c.coreDark.withValues(alpha: 0.25),
                        blurRadius: s * 0.2,
                        offset: Offset(0, s * 0.12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Upper-left shine
                      Positioned(
                        top: s * 0.14,
                        left: s * 0.18,
                        child: Container(
                          width: s * 0.28,
                          height: s * 0.18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(s * 0.1),
                            color:
                                Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      // Center soft dot
                      Center(
                        child: Container(
                          width: s * 0.16,
                          height: s * 0.16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrbColors {
  final Color glow;
  final Color coreLight;
  final Color coreMid;
  final Color coreDark;

  const _OrbColors({
    required this.glow,
    required this.coreLight,
    required this.coreMid,
    required this.coreDark,
  });
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double maxRadius;

  const _RipplePainter({
    required this.progress,
    required this.color,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < 3; i++) {
      final offset = i / 3.0;
      final p = ((progress + offset) % 1.0);
      final radius = maxRadius * (0.55 + 0.45 * p);
      final opacity = (1.0 - p) * 0.38;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1.0 - p),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

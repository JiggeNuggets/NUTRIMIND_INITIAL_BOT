import 'package:flutter/material.dart';
import '../../models/nutribot_models.dart';
import '../../theme/modern_app_theme.dart';

class ChatBubble extends StatelessWidget {
  final NutribotMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return message.isUser
        ? _UserBubble(message: message)
        : _BotBubble(message: message);
  }
}

// ─── User bubble ─────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final NutribotMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 56),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ModernAppTheme.primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(5),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        ModernAppTheme.primaryGreen.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // User avatar dot
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: ModernAppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Bot bubble ──────────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  final NutribotMessage message;
  const _BotBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Orb mini avatar
          _OrbAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: ModernAppTheme.divider,
                  width: 1,
                ),
                boxShadow: ModernAppTheme.shadowMd,
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? const _ThinkingDots()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MessageText(text: message.content),
                        if (message.isStreaming) ...[
                          const SizedBox(height: 4),
                          _StreamingCursor(),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini orb avatar ────────────────────────────────────────────────────────

class _OrbAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color(0xFFA7F3D0),
            Color(0xFF6EE7B7),
            Color(0xFF059669),
          ],
          stops: [0.0, 0.5, 1.0],
          center: Alignment(-0.3, -0.3),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: const Center(
          child: Text('N', style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          )),
        ),
      ),
    );
  }
}

// ─── Message text (supports basic markdown-like formatting) ─────────────────

class _MessageText extends StatelessWidget {
  final String text;
  const _MessageText({required this.text});

  @override
  Widget build(BuildContext context) {
    // Simple rendering; replace with flutter_markdown for full support
    return Text(
      text,
      style: const TextStyle(
        color: ModernAppTheme.textDark,
        fontSize: 14.5,
        height: 1.5,
      ),
    );
  }
}

// ─── Streaming cursor blink ──────────────────────────────────────────────────

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value,
        child: Container(
          width: 8,
          height: 2,
          decoration: BoxDecoration(
            color: ModernAppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

// ─── Thinking dots ───────────────────────────────────────────────────────────

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final delay = i / 3.0;
              final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
              final scale = 0.6 + 0.4 * (1 - (2 * t - 1).abs().clamp(0.0, 1.0));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ModernAppTheme.accentGreen,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

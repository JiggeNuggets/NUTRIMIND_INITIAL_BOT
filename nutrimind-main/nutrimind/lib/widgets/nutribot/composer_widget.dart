import 'package:flutter/material.dart';
import '../../models/nutribot_models.dart';
import '../../theme/modern_app_theme.dart';

class ComposerWidget extends StatefulWidget {
  final ValueChanged<String> onSend;
  final ValueChanged<bool> onTypingChanged;
  final NutribotState botState;

  const ComposerWidget({
    super.key,
    required this.onSend,
    required this.onTypingChanged,
    required this.botState,
  });

  @override
  State<ComposerWidget> createState() => _ComposerWidgetState();
}

class _ComposerWidgetState extends State<ComposerWidget> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  bool get _busy =>
      widget.botState == NutribotState.thinking ||
      widget.botState == NutribotState.streaming;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
      widget.onTypingChanged(has);
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    _ctrl.clear();
    widget.onSend(text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: ModernAppTheme.divider,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: ModernAppTheme.bgGreen,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focus.hasFocus
                      ? ModernAppTheme.accentGreen
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Focus(
                onFocusChange: (_) => setState(() {}),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  enabled: !_busy,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: ModernAppTheme.textDark,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        _busy ? 'NutriBot is responding...' : 'Ask NutriBot...',
                    hintStyle: const TextStyle(
                      color: ModernAppTheme.textHint,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            active: _hasText && !_busy,
            loading: _busy,
            onTap: _send,
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  const _SendButton({
    required this.active,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              active ? ModernAppTheme.primaryGreen : ModernAppTheme.softGreen,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ModernAppTheme.primaryGreen.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ModernAppTheme.primaryGreen,
                ),
              )
            : Icon(
                Icons.send_rounded,
                size: 20,
                color: active ? Colors.white : ModernAppTheme.accentGreen,
              ),
      ),
    );
  }
}

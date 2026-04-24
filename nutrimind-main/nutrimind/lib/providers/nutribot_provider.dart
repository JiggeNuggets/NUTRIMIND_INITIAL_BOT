import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/nutribot_models.dart';
import '../services/nutribot_service.dart';

class NutriBotController extends ChangeNotifier {
  NutriBotController({
    NutribotContext? nutribotContext,
    NutribotService? service,
  })  : _nutribotContext = nutribotContext,
        _service = service ?? NutribotService();

  final NutribotService _service;
  final List<NutribotMessage> _messages = [];

  NutribotContext? _nutribotContext;
  NutribotState _botState = NutribotState.idle;
  String _statusText = 'Ready when you are';
  bool _userIsTyping = false;
  bool _didBootstrapPrompt = false;
  bool _disposed = false;

  Timer? _statusTimer;
  int _statusIdx = 0;

  static const List<String> _thinkingStatuses = [
    'Analyzing your context...',
    'Checking nutrition details...',
    'Looking for practical swaps...',
    'Balancing budget and goals...',
  ];

  NutribotContext? get nutribotContext => _nutribotContext;
  List<NutribotMessage> get messages => List.unmodifiable(_messages);
  NutribotState get botState => _botState;
  String get statusText => _statusText;

  bool get isBusy =>
      _botState == NutribotState.thinking ||
      _botState == NutribotState.streaming;

  void updateContext(NutribotContext? context) {
    _nutribotContext = context;
    _safeNotify();
  }

  void onTypingChanged(bool typing) {
    if (_userIsTyping == typing) return;
    _userIsTyping = typing;
    if (_botState == NutribotState.idle || _botState == NutribotState.done) {
      _setBotState(
        typing ? NutribotState.typing : NutribotState.idle,
        status: typing ? 'Listening...' : 'Ready when you are',
      );
    }
  }

  Future<void> bootstrapInitialPrompt() async {
    if (_didBootstrapPrompt) return;
    final initialPrompt = _nutribotContext?.initialPrompt?.trim();
    if (initialPrompt == null || initialPrompt.isEmpty) return;

    _didBootstrapPrompt = true;
    await sendMessage(initialPrompt);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isBusy) return;

    final history = List<NutribotMessage>.from(_messages);

    _messages.add(NutribotMessage(content: trimmed, isUser: true));
    _startThinkingCycle();
    _messages.add(
      NutribotMessage(content: '', isUser: false, isStreaming: true),
    );
    _safeNotify();

    var firstToken = true;

    try {
      await for (final token in _service.sendMessage(
        userMessage: trimmed,
        history: history,
        context: _nutribotContext,
      )) {
        if (_disposed) return;
        if (firstToken) {
          firstToken = false;
          _stopThinkingCycle();
          _setBotState(
            NutribotState.streaming,
            status: 'Sharing a focused answer...',
          );
        }

        final idx = _messages.length - 1;
        _messages[idx] =
            _messages[idx].copyWith(content: _messages[idx].content + token);
        _safeNotify();
      }

      if (_disposed) return;
      _stopThinkingCycle();
      final idx = _messages.length - 1;
      _messages[idx] = _messages[idx].copyWith(isStreaming: false);
      _botState = NutribotState.done;
      _statusText = 'Here to help anytime';
      _safeNotify();

      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed) {
          _setBotState(NutribotState.idle, status: 'Ready when you are');
        }
      });
    } catch (_) {
      if (_disposed) return;
      _stopThinkingCycle();
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          content:
              'I could not finish that response. Try asking again in a simpler way.',
          isStreaming: false,
        );
      }
      _botState = NutribotState.error;
      _statusText = 'Something got interrupted';
      _safeNotify();
    }
  }

  void _startThinkingCycle() {
    _statusIdx = 0;
    _setBotState(NutribotState.thinking, status: _thinkingStatuses[0]);
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (_disposed) return;
      _statusIdx = (_statusIdx + 1) % _thinkingStatuses.length;
      _statusText = _thinkingStatuses[_statusIdx];
      _safeNotify();
    });
  }

  void _stopThinkingCycle() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _setBotState(NutribotState state, {String? status}) {
    _botState = state;
    if (status != null) _statusText = status;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopThinkingCycle();
    _service.dispose();
    super.dispose();
  }
}

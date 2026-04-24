import 'dart:async';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/modern_app_theme.dart';

/// Returns true when an error looks like a connectivity / Firebase-unavailable
/// failure so callers can show an offline-flavoured state instead of a generic
/// error. Keeps the heuristic in one place.
bool isOfflineError(Object? error) {
  if (error == null) return false;
  if (error is SocketException || error is TimeoutException) return true;
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'unavailable' ||
        code == 'network-request-failed' ||
        code == 'deadline-exceeded' ||
        code == 'cancelled') {
      return true;
    }
  }
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('network request failed') ||
      text.contains('connection closed') ||
      text.contains('xmlhttprequest error') ||
      text.contains('clientexception') ||
      text.contains('unavailable');
}

/// Centred loading indicator with an optional caption. Use inside a Scaffold
/// body, a SliverFillRemaining, or an Expanded child.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryGreen,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state with icon, title, optional message, and optional
/// call-to-action button.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 16 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 36 : 48,
              color: AppTheme.textLight,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMid,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textLight,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error / offline state with a retry button. Pass [error] so the widget can
/// auto-detect offline-looking failures and flip to the offline styling.
/// Override with [isOffline] when you already know the condition.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    this.error,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    bool? isOffline,
    this.compact = false,
  }) : _isOfflineOverride = isOffline;

  final Object? error;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool? _isOfflineOverride;
  final bool compact;

  bool get _offline => _isOfflineOverride ?? isOfflineError(error);

  @override
  Widget build(BuildContext context) {
    final offline = _offline;
    final resolvedTitle = title ??
        (offline ? "You're offline" : 'Something went wrong');
    final resolvedMessage = message ??
        (offline
            ? 'Check your internet connection and try again.'
            : 'We could not load this right now. Please try again.');
    final icon = offline ? Icons.wifi_off_rounded : Icons.error_outline;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 16 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(
                color: offline
                    ? AppTheme.orangeAccent.withValues(alpha: 0.14)
                    : AppTheme.errorRed.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: offline ? AppTheme.orangeAccent : AppTheme.errorRed,
                size: compact ? 24 : 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              resolvedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              resolvedMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textMid,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline card variant suitable for list headers / mid-screen placements where
/// a full-height centred state would be too much. Uses the same auto-offline
/// logic as [ErrorStateView].
class InlineErrorStateCard extends StatelessWidget {
  const InlineErrorStateCard({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final offline = isOfflineError(error);
    final resolvedMessage = message ??
        (offline
            ? "You're offline. Reconnect to load the latest data."
            : 'Could not load. Please try again.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        border: Border.all(
          color: offline
              ? AppTheme.orangeAccent.withValues(alpha: 0.45)
              : AppTheme.errorRed.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.wifi_off_rounded : Icons.error_outline,
            color: offline ? AppTheme.orangeAccent : AppTheme.errorRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resolvedMessage,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(retryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

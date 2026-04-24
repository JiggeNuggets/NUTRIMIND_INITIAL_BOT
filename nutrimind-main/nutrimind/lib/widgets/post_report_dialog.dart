import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/community_config.dart';
import '../models/post_model.dart';
import '../models/report_model.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../theme/app_theme.dart';

Future<void> showPostReportDialog(
  BuildContext context, {
  required PostModel post,
}) async {
  final user = context.read<AuthProvider>().userModel;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in before reporting posts.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (user.uid == post.userId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot report your own post.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final result = await showDialog<ReportPostResult>(
    context: context,
    builder: (_) => _PostReportDialog(post: post),
  );

  if (!context.mounted || result == null) return;
  final message = result == ReportPostResult.duplicate
      ? 'You already reported this post.'
      : 'Report submitted. Thank you for helping keep NutriMind safe.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: result == ReportPostResult.duplicate
          ? AppTheme.orangeAccent
          : AppTheme.primaryGreen,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _PostReportDialog extends StatefulWidget {
  const _PostReportDialog({required this.post});

  final PostModel post;

  @override
  State<_PostReportDialog> createState() => _PostReportDialogState();
}

class _PostReportDialogState extends State<_PostReportDialog> {
  static const _reasons = CommunityConfig.reportReasons;

  final _detailsCtrl = TextEditingController();
  String _reason = _reasons.first;
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      final result = await context.read<CommunityProvider>().reportPost(
            post: widget.post,
            reporter: user,
            reason: _reason,
            details: _detailsCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit report. Please try again.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Report Post',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons
                .map(
                  (reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason),
                  ),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (value) => setState(() => _reason = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsCtrl,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Details',
              hintText: 'Optional context for moderators',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textMid),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.flag_outlined, size: 18),
          label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
        ),
      ],
    );
  }
}

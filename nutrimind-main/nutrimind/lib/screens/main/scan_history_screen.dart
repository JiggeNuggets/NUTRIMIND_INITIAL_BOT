import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/scanned_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/state_views.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final FirestoreService _firestore = FirestoreService();
  int _streamKey = 0;

  String? get _uid => context.read<AuthProvider>().userModel?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().userModel?.uid;

    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        title: const Text('Scan History'),
      ),
      body: SafeArea(
        top: false,
        child: uid == null || uid.isEmpty
            ? ErrorStateView(
                title: 'Sign in required',
                message: 'Please sign in before viewing scan history.',
                onRetry: () => setState(() => _streamKey++),
              )
            : StreamBuilder<List<ScannedItemModel>>(
                key: ValueKey(_streamKey),
                stream: _firestore.listenToScannedItems(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const LoadingStateView(
                      message: 'Loading scan history...',
                    );
                  }

                  if (snapshot.hasError) {
                    return ErrorStateView(
                      error: snapshot.error,
                      title: 'Could not load scan history',
                      message:
                          'Your scanned meals could not be loaded right now.',
                      onRetry: () => setState(() => _streamKey++),
                    );
                  }

                  final scans = snapshot.data ?? const <ScannedItemModel>[];
                  if (scans.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.history_rounded,
                      title: 'No scanned items yet',
                      message:
                          'Confirmed food scans will appear here after saving to Meal Log.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: scans.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ScanHistorySummaryCard(count: scans.length);
                      }
                      final scan = scans[index - 1];
                      return _ScanHistoryCard(
                        scan: scan,
                        onDelete: () => _confirmDelete(scan),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<void> _confirmDelete(ScannedItemModel scan) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scan history item?'),
        content: Text('Remove ${scan.name} from Scan History.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _firestore.deleteScannedItem(uid, scan.id);
      _showSnack('Scan history item deleted.');
    } catch (_) {
      _showSnack('Could not delete scan history item. Please try again.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ScanHistorySummaryCard extends StatelessWidget {
  const _ScanHistorySummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModernAppTheme.mediumGray),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ModernAppTheme.softGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: ModernAppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count confirmed scan${count == 1 ? '' : 's'}',
                  style: ModernAppTheme.cardTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Latest saved scanner results appear first.',
                  style: TextStyle(
                    color: ModernAppTheme.textMid,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  const _ScanHistoryCard({
    required this.scan,
    required this.onDelete,
  });

  final ScannedItemModel scan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MMM d, yyyy - h:mm a').format(scan.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ModernAppTheme.mediumGray),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ModernAppTheme.softGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: ModernAppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ModernAppTheme.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: ModernAppTheme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ScanMetricTag(
                      icon: Icons.local_fire_department_outlined,
                      label: '${scan.calories} kcal',
                    ),
                    _ScanMetricTag(
                      icon: Icons.payments_outlined,
                      label: 'PHP ${scan.price.toStringAsFixed(0)}',
                    ),
                    _ScanMetricTag(
                      icon: Icons.restaurant_menu_outlined,
                      label: _mealTypeLabel(scan.mealType),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete scan history item',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.textMid,
            ),
          ),
        ],
      ),
    );
  }

  String _mealTypeLabel(String value) {
    if (value.trim().isEmpty) return 'Meal';
    final normalized = value.trim().toLowerCase();
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _ScanMetricTag extends StatelessWidget {
  const _ScanMetricTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ModernAppTheme.lightGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ModernAppTheme.textMid),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: ModernAppTheme.textMid,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pantry_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/state_views.dart';

const List<String> _pantryUnits = [
  'pcs',
  'kg',
  'g',
  'cup',
  'pack',
  'can',
  'bundle',
];

const List<String> _pantryCategories = [
  'vegetable',
  'fruit',
  'meat',
  'fish',
  'grain',
  'canned',
  'dairy',
  'condiment',
  'other',
];

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key, this.openAddOnStart = false});

  final bool openAddOnStart;

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final FirestoreService _firestore = FirestoreService();
  int _streamKey = 0;
  bool _openedInitialSheet = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAddOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openedInitialSheet) return;
        _openedInitialSheet = true;
        _openItemSheet();
      });
    }
  }

  String? get _uid => context.read<AuthProvider>().userModel?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().userModel?.uid;

    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        title: const Text('Pantry'),
        actions: [
          IconButton(
            tooltip: 'Add pantry item',
            onPressed: _openItemSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openItemSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
      body: SafeArea(
        top: false,
        child: uid == null || uid.isEmpty
            ? ErrorStateView(
                title: 'Sign in required',
                message: 'Please sign in before managing pantry items.',
                onRetry: () => setState(() => _streamKey++),
              )
            : StreamBuilder<List<PantryItemModel>>(
                key: ValueKey(_streamKey),
                stream: _firestore.pantryItemsStream(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const LoadingStateView(
                      message: 'Loading pantry items...',
                    );
                  }

                  if (snapshot.hasError) {
                    return ErrorStateView(
                      error: snapshot.error,
                      title: 'Could not load pantry',
                      message:
                          'Your pantry items could not be loaded right now.',
                      onRetry: () => setState(() => _streamKey++),
                    );
                  }

                  final items = snapshot.data ?? const <PantryItemModel>[];
                  if (items.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.kitchen_outlined,
                      title: 'No pantry items yet.',
                      message:
                          'Add ingredients you have at home or bought from the palengke.',
                      actionLabel: 'Add Pantry Item',
                      onAction: _openItemSheet,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _PantrySummaryCard(items: items);
                      }
                      final item = items[index - 1];
                      return _PantryItemCard(
                        item: item,
                        onEdit: () => _openItemSheet(item: item),
                        onDelete: () => _confirmDelete(item),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openItemSheet({PantryItemModel? item}) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      _showSnack('Please sign in before adding pantry items.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PantryItemSheet(
        item: item,
        onSave: (draft) => _saveItem(uid: uid, draft: draft, item: item),
      ),
    );
  }

  Future<void> _saveItem({
    required String uid,
    required _PantryItemDraft draft,
    PantryItemModel? item,
  }) async {
    try {
      if (item == null) {
        await _firestore.addPantryItem(
          uid: uid,
          name: draft.name,
          quantity: draft.quantity,
          unit: draft.unit,
          category: draft.category,
          isPalengkeItem: draft.isPalengkeItem,
        );
      } else {
        await _firestore.updatePantryItem(
          uid: uid,
          itemId: item.id,
          name: draft.name,
          quantity: draft.quantity,
          unit: draft.unit,
          category: draft.category,
          isPalengkeItem: draft.isPalengkeItem,
        );
      }
      _showSnack(item == null ? 'Pantry item added.' : 'Pantry item updated.');
    } catch (_) {
      _showSnack('Could not save pantry item. Please try again.');
      rethrow;
    }
  }

  Future<void> _confirmDelete(PantryItemModel item) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pantry item?'),
        content: Text('Remove ${item.name} from your pantry list.'),
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
      await _firestore.deletePantryItem(uid, item.id);
      _showSnack('Pantry item deleted.');
    } catch (_) {
      _showSnack('Could not delete pantry item. Please try again.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PantrySummaryCard extends StatelessWidget {
  const _PantrySummaryCard({required this.items});

  final List<PantryItemModel> items;

  @override
  Widget build(BuildContext context) {
    final palengkeCount = items.where((item) => item.isPalengkeItem).length;

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
              Icons.kitchen_outlined,
              color: ModernAppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} pantry item${items.length == 1 ? '' : 's'}',
                  style: ModernAppTheme.cardTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  '$palengkeCount marked as palengke / wet-market items',
                  style: const TextStyle(
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

class _PantryItemCard extends StatelessWidget {
  const _PantryItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final PantryItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ModernAppTheme.mediumGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _categoryColor(item.category).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _categoryIcon(item.category),
              color: _categoryColor(item.category),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ModernAppTheme.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniTag(
                      icon: Icons.scale_outlined,
                      label: '${_formatQuantity(item.quantity)} ${item.unit}',
                    ),
                    _MiniTag(
                      icon: Icons.category_outlined,
                      label: _categoryLabel(item.category),
                    ),
                    if (item.isPalengkeItem)
                      const _MiniTag(
                        icon: Icons.storefront_outlined,
                        label: 'Palengke',
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Pantry item actions',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  static IconData _categoryIcon(String category) {
    return switch (category) {
      'vegetable' => Icons.eco_outlined,
      'fruit' => Icons.local_florist_outlined,
      'meat' => Icons.restaurant_menu_outlined,
      'fish' => Icons.set_meal_outlined,
      'grain' => Icons.rice_bowl_outlined,
      'canned' => Icons.inventory_2_outlined,
      'dairy' => Icons.icecream_outlined,
      'condiment' => Icons.soup_kitchen_outlined,
      _ => Icons.kitchen_outlined,
    };
  }

  static Color _categoryColor(String category) {
    return switch (category) {
      'vegetable' => ModernAppTheme.primaryGreen,
      'fruit' => ModernAppTheme.warning,
      'meat' => ModernAppTheme.error,
      'fish' => ModernAppTheme.info,
      'grain' => const Color(0xFF8D6E63),
      'canned' => const Color(0xFF607D8B),
      'dairy' => const Color(0xFF7E57C2),
      'condiment' => const Color(0xFF795548),
      _ => ModernAppTheme.textMid,
    };
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

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

class _PantryItemDraft {
  const _PantryItemDraft({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.isPalengkeItem,
  });

  final String name;
  final double quantity;
  final String unit;
  final String category;
  final bool isPalengkeItem;
}

class _PantryItemSheet extends StatefulWidget {
  const _PantryItemSheet({
    required this.onSave,
    this.item,
  });

  final PantryItemModel? item;
  final Future<void> Function(_PantryItemDraft draft) onSave;

  @override
  State<_PantryItemSheet> createState() => _PantryItemSheetState();
}

class _PantryItemSheetState extends State<_PantryItemSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  late String _unit;
  late String _category;
  late bool _isPalengkeItem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item == null
        ? ''
        : item.quantity % 1 == 0
            ? item.quantity.toStringAsFixed(0)
            : item.quantity.toString();
    _unit = _pantryUnits.contains(item?.unit) ? item!.unit : 'pcs';
    _category =
        _pantryCategories.contains(item?.category) ? item!.category : 'other';
    _isPalengkeItem = item?.isPalengkeItem ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final draft = _PantryItemDraft(
        name: _nameController.text.trim(),
        quantity: double.parse(_quantityController.text.trim()),
        unit: _unit,
        category: _category,
        isPalengkeItem: _isPalengkeItem,
      );
      await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: ModernAppTheme.shadowXl,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.item == null
                          ? 'Add Pantry Item'
                          : 'Edit Pantry Item',
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppTheme.textMid),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _label('Item name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Example: tomatoes',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Quantity'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(hintText: '2'),
                            validator: (value) {
                              final quantity =
                                  double.tryParse(value?.trim() ?? '');
                              if (quantity == null || quantity <= 0) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Unit'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _unit,
                            decoration: const InputDecoration(),
                            items: _pantryUnits
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _unit = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Category'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(),
                  items: _pantryCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(category)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  value: _isPalengkeItem,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primaryGreen,
                  activeTrackColor:
                      AppTheme.primaryGreen.withValues(alpha: 0.24),
                  title: const Text(
                    'Palengke / wet-market item',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Use for fresh market ingredients without barcodes.',
                    style: TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _isPalengkeItem = value;
                  }),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saving...' : 'Save Pantry Item'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textDark,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _categoryLabel(String category) {
  return switch (category) {
    'vegetable' => 'Vegetable',
    'fruit' => 'Fruit',
    'meat' => 'Meat',
    'fish' => 'Fish',
    'grain' => 'Grain',
    'canned' => 'Canned',
    'dairy' => 'Dairy',
    'condiment' => 'Condiment',
    _ => 'Other',
  };
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _locationCtrl;
  late double _height;
  late double _weight;
  late int _age;
  late String _gender;
  bool _saving = false;

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _locationCtrl = TextEditingController(
        text: user?.location ?? 'Davao City, Philippines');
    _height = user?.height ?? 168;
    _weight = user?.weight ?? 64;
    _age = user?.age ?? 28;
    _gender = user?.gender ?? 'Male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final file = await _storageService.pickImage(source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _pickedImage = file;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open image picker. Check app permissions.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryGreen),
              title: const Text('Camera',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryGreen),
              title: const Text('Photo Library',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textMid),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheetCtx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please sign in before editing your profile.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    try {
      if (_pickedImage != null) {
        final url =
            await _storageService.uploadProfileImage(user.uid, _pickedImage!);
        await auth.updateProfilePhoto(url);
      }

      await FirestoreService().updateUser(user.uid, {
        'name': _nameCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'height': _height,
        'weight': _weight,
        'age': _age,
        'gender': _gender,
      });

      await auth.updateOnboarding(
        goal: user.goal,
        gender: _gender,
        height: _height,
        weight: _weight,
        age: _age,
      );

      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    ImageProvider? avatarImage;
    if (_imageBytes != null) {
      avatarImage = MemoryImage(_imageBytes!);
    } else if (user?.photoUrl != null) {
      avatarImage = NetworkImage(user!.photoUrl!);
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryGreen))
                  : const Text('Save',
                      style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with camera tap
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppTheme.softGreen,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Text(
                                _nameCtrl.text.isNotEmpty
                                    ? _nameCtrl.text[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 32),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('Tap photo to change',
                    style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
              ),
              const SizedBox(height: 24),

              _label('Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Your name'),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 18),

              _label('Location'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationCtrl,
                decoration:
                    const InputDecoration(hintText: 'Davao City, Philippines'),
              ),
              const SizedBox(height: 24),

              _label('Gender'),
              const SizedBox(height: 10),
              Row(
                children: ['Male', 'Female', 'Other'].map((g) {
                  final sel = _gender == g;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryGreen : AppTheme.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel
                                  ? AppTheme.primaryGreen
                                  : AppTheme.divider),
                        ),
                        child: Text(g,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: sel ? Colors.white : AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _buildNumSlider('Height', _height, 140, 210, 'cm',
                  (v) => setState(() => _height = v)),
              const SizedBox(height: 18),
              _buildNumSlider('Weight', _weight, 30, 150, 'kg',
                  (v) => setState(() => _weight = v)),
              const SizedBox(height: 18),
              _buildNumSlider('Age', _age.toDouble(), 10, 80, 'yrs',
                  (v) => setState(() => _age = v.toInt())),

              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark));

  Widget _buildNumSlider(String label, double value, double min, double max,
      String unit, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label(label),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: AppTheme.softGreen,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryGreen,
            inactiveTrackColor: AppTheme.divider,
            thumbColor: AppTheme.primaryGreen,
            overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../../config/community_config.dart';
import '../../models/nutribot_models.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  String _category = CommunityConfig.defaultPostCategory;
  final List<String> _categories = CommunityConfig.categories;
  final List<String> _selectedTags = [];
  final List<String> _availableTags = CommunityConfig.suggestedTags;
  bool _submitting = false;

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  final _storageService = StorageService();

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPostImage(ImageSource source) async {
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
              onTap: () => _pickPostImage(ImageSource.camera),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryGreen),
              title: const Text('Photo Library',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _pickPostImage(ImageSource.gallery),
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

  Future<void> _publish() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please write something before publishing.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final community = context.read<CommunityProvider>();
    final user = auth.userModel;
    if (user == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please sign in before publishing.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    try {
      String? imageUrl;
      if (_pickedImage != null) {
        final imageId = const Uuid().v4();
        imageUrl = await _storageService.uploadPostImage(
            user.uid, imageId, _pickedImage!);
        if (!mounted) return;
      }

      final success = await community.createPost(
        userId: user.uid,
        userName: user.name,
        userPhotoUrl: user.photoUrl,
        location: user.location,
        content: _contentCtrl.text.trim(),
        category: _category,
        imageUrl: imageUrl,
        tags: _selectedTags,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (success) {
        _showPublishedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to publish. Please try again.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showPublishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: AppTheme.softGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check,
                    color: AppTheme.primaryGreen, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Post Published!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Your post has been shared with the NutriMind community. Others can now see your finds!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textMid, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('View My Post'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Back to Feed',
                    style: TextStyle(color: AppTheme.textMid)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  NutribotContext _buildNutribotContext() {
    final user = context.read<AuthProvider>().userModel;
    final hasDraft = _contentCtrl.text.trim().isNotEmpty;

    return NutribotContext(
      source: NutribotSource.community,
      contextTitle: 'Community Helper',
      sourceContext: 'Community post composer',
      initialPrompt: hasDraft
          ? 'Improve this food post before I publish it.'
          : 'Help me write a helpful food post for the NutriMind community.',
      userGoal: user?.goal,
      data: NutribotPayloads.communityDraft(
        category: _category,
        content: _contentCtrl.text,
        tags: _selectedTags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Market Finds'),
        actions: [
          NutribotAppBarAction(
            nutribotContext: _buildNutribotContext(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _submitting ? null : _publish,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(90, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Publish Post'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share a Find',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text(
                'Share fresh finds, tips, and local food discoveries with the community.',
                style: TextStyle(
                    color: AppTheme.textMid, fontSize: 13, height: 1.5)),
            const SizedBox(height: 28),

            // Category selector
            const Text('Category',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primaryGreen : AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color: sel ? Colors.white : AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Photo section
            const Text('Photo',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 10),
            _buildImagePicker(),
            const SizedBox(height: 20),

            // Post content
            const Text('Post Content',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Write your post here...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Tags
            const Text('Tags',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final sel = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.softGreen : AppTheme.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? AppTheme.primaryGreen : AppTheme.divider,
                      ),
                    ),
                    child: Text('#$tag',
                        style: TextStyle(
                            color:
                                sel ? AppTheme.primaryGreen : AppTheme.textMid,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _submitting ? null : _publish,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Publish Post'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    if (_imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _imageBytes!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _pickedImage = null;
                _imageBytes = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Change',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.bgGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: AppTheme.primaryGreen, size: 32),
            SizedBox(height: 8),
            Text('Add Photo',
                style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text('Tap to upload (optional)',
                style: TextStyle(color: AppTheme.textMid, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

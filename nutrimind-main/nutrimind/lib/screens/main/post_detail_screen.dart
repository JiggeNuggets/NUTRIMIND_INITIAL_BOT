import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/post_model.dart';
import '../../widgets/post_report_dialog.dart';
import 'user_profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please sign in before commenting.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final comment = CommentModel(
      id: '',
      postId: widget.post.id,
      userId: user.uid,
      userName: user.name,
      userPhotoUrl: user.photoUrl,
      content: text,
      createdAt: DateTime.now(),
    );

    try {
      await context.read<CommunityProvider>().addComment(comment);
      if (!mounted) return;
      _commentCtrl.clear();
      _focusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not add comment. Please try again.'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openAuthorProfile(PostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: post.userId,
          fallbackName: post.userName,
          fallbackPhotoUrl: post.userPhotoUrl,
        ),
      ),
    );
  }

  void _showPostOptions(PostModel post) {
    final currentUser = context.read<AuthProvider>().userModel;
    final isOwner = currentUser?.uid == post.userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            if (isOwner)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await context.read<CommunityProvider>().deletePost(post.id);
                  } catch (_) {
                    return;
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post deleted'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              )
            else
              ListTile(
                leading:
                    const Icon(Icons.flag_outlined, color: AppTheme.errorRed),
                title: const Text(
                  'Report Post',
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showPostReportDialog(context, post: post);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textMid),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = context.watch<CommunityProvider>();
    final currentUser = context.read<AuthProvider>().userModel;
    final uid = currentUser?.uid ?? '';
    final post = community.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );

    if (community.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(community.error!),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
        community.clearError();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(post.category, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Post options',
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showPostOptions(post),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // Post header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openAuthorProfile(post),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.softGreen,
                        backgroundImage: post.userPhotoUrl != null
                            ? NetworkImage(post.userPhotoUrl!)
                            : null,
                        child: post.userPhotoUrl == null
                            ? Text(
                                post.userName.isNotEmpty
                                    ? post.userName[0]
                                    : '?',
                                style: const TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w700))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openAuthorProfile(post),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textDark)),
                          Text(post.timeAgo,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textLight)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppTheme.softGreen,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(post.category,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (post.isUnderReview) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.orangeAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Under review',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.orangeAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Content
                Text(post.content,
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.textDark, height: 1.6)),

                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: post.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppTheme.softGreen,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('#$tag',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],

                if (post.imageUrl != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(post.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              height: 160,
                              color: AppTheme.softGreen,
                              child: const Icon(Icons.image_outlined,
                                  color: AppTheme.accentGreen, size: 40),
                            )),
                  ),
                ],

                const SizedBox(height: 16),

                // Like button
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context
                          .read<CommunityProvider>()
                          .toggleLike(post, currentUser),
                      child: Row(
                        children: [
                          Icon(
                            post.isLikedBy(uid)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: post.isLikedBy(uid)
                                ? Colors.red
                                : AppTheme.textMid,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text('${post.likeCount} likes',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: post.isLikedBy(uid)
                                      ? Colors.red
                                      : AppTheme.textMid)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Row(children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 18, color: AppTheme.textMid),
                      const SizedBox(width: 6),
                      Text('${post.commentCount} comments',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMid)),
                    ]),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(color: AppTheme.divider),
                const SizedBox(height: 4),

                // DISCUSSION header
                const Text('Discussion',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark)),
                const SizedBox(height: 14),

                // Comments stream
                StreamBuilder<List<CommentModel>>(
                  stream:
                      context.read<CommunityProvider>().commentsStream(post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryGreen, strokeWidth: 2),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('Could not load comments.',
                              style: TextStyle(
                                  color: AppTheme.errorRed, fontSize: 13)),
                        ),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('Be the first to comment!',
                              style: TextStyle(
                                  color: AppTheme.textLight, fontSize: 13)),
                        ),
                      );
                    }
                    return Column(
                      children: comments.map((c) => _buildComment(c)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.white,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.softGreen,
                  child: Text(
                    context.read<AuthProvider>().userModel?.name[0] ?? 'U',
                    style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: AppTheme.bgGreen,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitting ? null : _submitComment,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen, shape: BoxShape.circle),
                    child: _submitting
                        ? const Center(
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(CommentModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppTheme.softGreen,
            backgroundImage:
                c.userPhotoUrl != null ? NetworkImage(c.userPhotoUrl!) : null,
            child: c.userPhotoUrl == null
                ? Text(c.userName.isNotEmpty ? c.userName[0] : '?',
                    style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 11))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.bgGreen,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                      const Spacer(),
                      Text(_timeAgo(c.createdAt),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textLight)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.content,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textDark, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/community_config.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/post_model.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/post_report_dialog.dart';
import '../../widgets/safe_image.dart';
import '../../widgets/state_views.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = CommunityConfig.categories;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context
            .read<CommunityProvider>()
            .listenToPosts(_tabs[_tabController.index]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().listenToPosts(_tabs[0]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.bgGreen,
        surfaceTintColor: Colors.transparent,
        title: const Text('Community'),
        actions: const [NotificationBell()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryGreen,
          indicatorWeight: 2.5,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textMid,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) => _PostsFeed(category: tab)).toList(),
          ),
        ),
      ),
    );
  }
}

class _PostsFeed extends StatelessWidget {
  final String category;
  const _PostsFeed({required this.category});

  @override
  Widget build(BuildContext context) {
    final community = context.watch<CommunityProvider>();
    final posts = community.posts;
    final horizontalPadding =
        MediaQuery.sizeOf(context).width < 360 ? 12.0 : 16.0;
    final feedPadding =
        EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 190);

    // Only flash a snackbar for transient errors while there is still content
    // to show. When the feed is empty, we render an on-screen error state
    // with retry below — clearing the error there would hide that view.
    if (community.error != null && posts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(community.error!),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
        community.clearError();
      });
    }

    if (community.loading) {
      return ListView(
        padding: feedPadding,
        children: const [
          _ComposerCard(),
          SizedBox(height: 40),
          LoadingStateView(message: 'Loading community posts...'),
        ],
      );
    }

    if (community.error != null && posts.isEmpty) {
      return ListView(
        padding: feedPadding,
        children: [
          const _ComposerCard(),
          const SizedBox(height: 40),
          ErrorStateView(
            message: community.error,
            onRetry: () => community.listenToPosts(category),
          ),
        ],
      );
    }

    if (posts.isEmpty) {
      return ListView(
        padding: feedPadding,
        children: [
          const _ComposerCard(),
          const SizedBox(height: 40),
          EmptyStateView(
            icon: Icons.people_outline,
            title: 'No posts in $category yet',
            message: 'Be the first to share something!',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: feedPadding,
      itemCount: posts.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        if (i == 0) return const _ComposerCard();
        return _PostCard(post: posts[i - 1]);
      },
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    return Material(
      color: ModernAppTheme.white,
      borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
      elevation: 1,
      shadowColor: ModernAppTheme.primaryGreen.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SafeAvatar(
                radius: 22,
                photoUrl: user?.photoUrl,
                displayName: user?.name ?? 'U',
                textStyle: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's on your mind?",
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Share a healthy meal, market find, or nutrition tip.',
                      style: TextStyle(
                        color: AppTheme.textMid,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ModernAppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<bool>? _likedStream;
  String? _likedStreamPostId;
  String? _likedStreamUid;

  PostModel get post => widget.post;

  Stream<bool> _likeStreamFor(String uid) {
    final postId = post.id;
    if (_likedStream != null &&
        _likedStreamPostId == postId &&
        _likedStreamUid == uid) {
      return _likedStream!;
    }

    _likedStreamPostId = postId;
    _likedStreamUid = uid;
    _likedStream = uid.isEmpty || postId.isEmpty
        ? Stream<bool>.value(false)
        : _firestoreService.isPostLikedByStream(postId, uid);
    return _likedStream!;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().userModel;
    final uid = currentUser?.uid ?? '';
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Material(
      color: ModernAppTheme.white,
      borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
      elevation: 1,
      shadowColor: ModernAppTheme.primaryGreen.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openAuthorProfile(context),
                    child: SafeAvatar(
                      radius: 18,
                      photoUrl: post.userPhotoUrl,
                      displayName: post.userName,
                      textStyle: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openAuthorProfile(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.textDark),
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(post.timeAgo,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textLight)),
                              if (post.location.isNotEmpty) ...[
                                const Icon(Icons.location_on,
                                    size: 11, color: AppTheme.textLight),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: compact ? 120 : 180),
                                  child: Text(post.location,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textLight),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (uid.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showOptions(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_vert,
                            size: 18, color: AppTheme.textLight),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _postBadge(
                    post.category,
                    backgroundColor: AppTheme.softGreen,
                    textColor: AppTheme.primaryGreen,
                  ),
                  if (post.isUnderReview)
                    _postBadge(
                      'Under review',
                      backgroundColor:
                          AppTheme.orangeAccent.withValues(alpha: 0.14),
                      textColor: AppTheme.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Content
              Text(post.content,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textDark, height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),

              // Tags
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: post.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.softGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('#$tag',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ],

              // Image placeholder
              if (post.imageUrl?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                SafeFoodImage(
                  imageUrl: post.imageUrl,
                  height: 180,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(12),
                  placeholderIcon: Icons.image_outlined,
                  placeholderColor: AppTheme.accentGreen,
                ),
              ],

              const SizedBox(height: 12),

              // Action row
              _buildActionRow(context, uid, currentUser, compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postBadge(
    String label, {
    required Color backgroundColor,
    required Color textColor,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    String uid,
    dynamic currentUser,
    bool compact,
  ) {
    final likeAction = StreamBuilder<bool>(
      stream: _likeStreamFor(uid),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return _actionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: '${post.likeCount}',
          color: isLiked ? Colors.red : AppTheme.textMid,
          fontWeight: isLiked ? FontWeight.w700 : FontWeight.w400,
          onTap: uid.isEmpty
              ? null
              : () => context
                  .read<CommunityProvider>()
                  .toggleLike(post, currentUser),
        );
      },
    );
    final commentAction = _actionButton(
      icon: Icons.chat_bubble_outline,
      label: '${post.commentCount}',
      color: AppTheme.textMid,
    );
    final shareAction = _actionButton(
      icon: Icons.share_outlined,
      label: '',
      color: AppTheme.textMid,
    );

    if (compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [likeAction, commentAction, shareAction],
      );
    }

    return Row(
      children: [
        likeAction,
        const SizedBox(width: 12),
        commentAction,
        const Spacer(),
        shareAction,
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openAuthorProfile(BuildContext context) {
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

  void _showOptions(BuildContext context) {
    final currentUser = context.read<AuthProvider>().userModel;
    final isOwner = currentUser?.uid == post.userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            if (isOwner)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                title: const Text('Delete Post',
                    style: TextStyle(
                        color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog<void>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete Post',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      content: const Text(
                          'Are you sure you want to delete this post?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel',
                              style: TextStyle(color: AppTheme.textMid)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            try {
                              await context
                                  .read<CommunityProvider>()
                                  .deletePost(post.id, currentUser?.uid ?? '');
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Could not delete post.'),
                                backgroundColor: AppTheme.errorRed,
                                behavior: SnackBarBehavior.floating,
                              ));
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('Post deleted successfully.'),
                              behavior: SnackBarBehavior.floating,
                            ));
                          },
                          child: const Text('Delete',
                              style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              ListTile(
                leading:
                    const Icon(Icons.flag_outlined, color: AppTheme.errorRed),
                title: const Text('Report Post',
                    style: TextStyle(
                        color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
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
}

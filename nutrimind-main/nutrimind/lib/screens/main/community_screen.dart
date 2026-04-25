import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/community_config.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/post_model.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/post_report_dialog.dart';
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
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _PostsFeed(category: tab)).toList(),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 190),
        children: const [
          _ComposerCard(),
          SizedBox(height: 40),
          LoadingStateView(message: 'Loading community posts...'),
        ],
      );
    }

    if (community.error != null && posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 190),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 190),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 190),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.softGreen,
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      )
                    : null,
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

class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().userModel;
    final uid = currentUser?.uid ?? '';
    final isLiked = post.isLikedBy(uid);

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openAuthorProfile(context),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.softGreen,
                      backgroundImage: post.userPhotoUrl != null
                          ? NetworkImage(post.userPhotoUrl!)
                          : null,
                      child: post.userPhotoUrl == null
                          ? Text(
                              post.userName.isNotEmpty ? post.userName[0] : '?',
                              style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14))
                          : null,
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
                          Row(
                            children: [
                              Text(post.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.textDark)),
                              if (post.location.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.location_on,
                                    size: 11, color: AppTheme.textLight),
                                Flexible(
                                  child: Text(post.location,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textLight),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ],
                          ),
                          Text(post.timeAgo,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textLight)),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppTheme.softGreen,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(post.category,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (post.isUnderReview) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Under review',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.orangeAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (uid.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showOptions(context),
                      child: const Icon(Icons.more_vert,
                          size: 18, color: AppTheme.textLight),
                    ),
                  ],
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
              if (post.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: AppTheme.softGreen,
                      child: const Icon(Icons.image_outlined,
                          color: AppTheme.accentGreen, size: 40),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context
                        .read<CommunityProvider>()
                        .toggleLike(post, currentUser),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isLiked ? Colors.red : AppTheme.textMid,
                        ),
                        const SizedBox(width: 4),
                        Text('${post.likeCount}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isLiked ? Colors.red : AppTheme.textMid,
                                fontWeight: isLiked
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 18, color: AppTheme.textMid),
                      const SizedBox(width: 4),
                      Text('${post.commentCount}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMid)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.share_outlined,
                      size: 18, color: AppTheme.textMid),
                ],
              ),
            ],
          ),
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
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await context.read<CommunityProvider>().deletePost(post.id);
                  } catch (_) {
                    return;
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Post deleted'),
                    behavior: SnackBarBehavior.floating,
                  ));
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

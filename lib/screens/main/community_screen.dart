import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/post_model.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Trending', 'Market Finds', 'Q&A', 'Health Forums'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<CommunityProvider>().listenToPosts(_tabs[_tabController.index]);
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
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('No new notifications'),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryGreen,
          indicatorWeight: 2.5,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textMid,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _PostsFeed(category: tab)).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'community_share_fab',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Share a Find', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
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

    if (community.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: AppTheme.textLight, size: 48),
            const SizedBox(height: 16),
            Text('No posts in $category yet', style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
            const SizedBox(height: 8),
            const Text('Be the first to share something!', style: TextStyle(
                fontSize: 13, color: AppTheme.textLight)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
      itemBuilder: (_, i) => _PostCard(post: posts[i]),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final isLiked = post.isLikedBy(uid);
    final isOwner = post.userId == uid;

    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.softGreen,
                  backgroundImage: post.userPhotoUrl != null
                      ? NetworkImage(post.userPhotoUrl!) : null,
                  child: post.userPhotoUrl == null
                      ? Text(post.userName.isNotEmpty ? post.userName[0] : '?',
                          style: const TextStyle(color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w700, fontSize: 14))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(post.userName, style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark)),
                          if (post.location.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.location_on, size: 11, color: AppTheme.textLight),
                            Flexible(
                              child: Text(post.location, style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textLight),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                      Text(post.timeAgo, style: const TextStyle(
                          fontSize: 11, color: AppTheme.textLight)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen, borderRadius: BorderRadius.circular(6)),
                  child: Text(post.category, style: const TextStyle(
                      fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showOptions(context),
                    child: const Icon(Icons.more_vert, size: 18, color: AppTheme.textLight),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Content
            Text(post.content, style: const TextStyle(
                fontSize: 14, color: AppTheme.textDark, height: 1.5),
                maxLines: 4, overflow: TextOverflow.ellipsis),

            // Tags
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: post.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('#$tag', style: const TextStyle(
                      fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                )).toList(),
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
                  onTap: () => context.read<CommunityProvider>()
                      .toggleLike(post.id, uid),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isLiked ? Colors.red : AppTheme.textMid,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}', style: TextStyle(
                          fontSize: 12, color: isLiked ? Colors.red : AppTheme.textMid,
                          fontWeight: isLiked ? FontWeight.w700 : FontWeight.w400)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 18, color: AppTheme.textMid),
                    const SizedBox(width: 4),
                    Text('${post.commentCount}', style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMid)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.share_outlined, size: 18, color: AppTheme.textMid),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
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
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
              title: const Text('Delete Post', style: TextStyle(
                  color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                context.read<CommunityProvider>().deletePost(post.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Post deleted'),
                  behavior: SnackBarBehavior.floating,
                ));
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

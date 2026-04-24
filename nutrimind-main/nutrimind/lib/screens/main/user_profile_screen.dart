import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import 'post_detail_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;
  final String? fallbackName;
  final String? fallbackPhotoUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
    this.fallbackPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: context.read<CommunityProvider>().getUser(userId),
      builder: (context, snapshot) {
        final loadedUser = snapshot.data;
        final profileUser = loadedUser ??
            UserModel(
              uid: userId,
              name: fallbackName ?? 'NutriMind user',
              email: '',
              photoUrl: fallbackPhotoUrl,
            );

        return Scaffold(
          backgroundColor: ModernAppTheme.backgroundNeutral,
          appBar: AppBar(
            backgroundColor: ModernAppTheme.backgroundNeutral,
            surfaceTintColor: Colors.transparent,
            title: Text(profileUser.name),
          ),
          body: snapshot.connectionState == ConnectionState.waiting &&
                  loadedUser == null
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryGreen),
                )
              : Column(
                  children: [
                    _ProfileHeader(user: profileUser),
                    const SizedBox(height: 10),
                    Expanded(child: _UserPosts(userId: userId)),
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().userModel;
    final community = context.read<CommunityProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        border: Border.all(color: ModernAppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppTheme.softGreen,
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMid,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FollowButton(
                      currentUser: currentUser,
                      targetUser: user,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: community.followersCountStream(user.uid),
                  builder: (context, snapshot) {
                    return _ProfileStat(
                      value: '${snapshot.data ?? 0}',
                      label: 'Followers',
                    );
                  },
                ),
              ),
              _DividerLine(),
              Expanded(
                child: StreamBuilder<int>(
                  stream: community.followingCountStream(user.uid),
                  builder: (context, snapshot) {
                    return _ProfileStat(
                      value: '${snapshot.data ?? 0}',
                      label: 'Following',
                    );
                  },
                ),
              ),
              _DividerLine(),
              Expanded(
                child: StreamBuilder<List<PostModel>>(
                  stream: community.userPostsStream(user.uid),
                  builder: (context, snapshot) {
                    return _ProfileStat(
                      value: '${snapshot.data?.length ?? 0}',
                      label: 'Posts',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  final UserModel? currentUser;
  final UserModel targetUser;

  const _FollowButton({
    required this.currentUser,
    required this.targetUser,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    if (currentUser.uid == widget.targetUser.uid) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.person_outline, size: 18),
        label: const Text('Your profile'),
      );
    }

    return StreamBuilder<bool>(
      stream: context.read<CommunityProvider>().isFollowingStream(
            currentUser.uid,
            widget.targetUser.uid,
          ),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        return SizedBox(
          height: 42,
          child: isFollowing
              ? OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _toggleFollow(context, isFollowing),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(_busy ? 'Saving...' : 'Following'),
                )
              : ElevatedButton.icon(
                  onPressed:
                      _busy ? null : () => _toggleFollow(context, isFollowing),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(_busy ? 'Saving...' : 'Follow'),
                ),
        );
      },
    );
  }

  Future<void> _toggleFollow(BuildContext context, bool isFollowing) async {
    final currentUser = widget.currentUser;
    if (currentUser == null) return;
    setState(() => _busy = true);
    try {
      final community = context.read<CommunityProvider>();
      if (isFollowing) {
        await community.unfollowUser(
          currentUid: currentUser.uid,
          targetUid: widget.targetUser.uid,
        );
      } else {
        await community.followUser(
          currentUser: currentUser,
          targetUser: widget.targetUser,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _UserPosts extends StatelessWidget {
  final String userId;

  const _UserPosts({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: context.read<CommunityProvider>().userPostsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'No posts yet.',
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _MiniPostCard(post: posts[index]),
        );
      },
    );
  }
}

class _MiniPostCard extends StatelessWidget {
  final PostModel post;

  const _MiniPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ModernAppTheme.white,
      borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.category,
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    post.timeAgo,
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.favorite_border,
                      color: AppTheme.textMid, size: 17),
                  const SizedBox(width: 4),
                  Text('${post.likeCount}',
                      style: const TextStyle(color: AppTheme.textMid)),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline,
                      color: AppTheme.textMid, size: 17),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}',
                      style: const TextStyle(color: AppTheme.textMid)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMid,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.divider,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final socialFeedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('social_posts')
      .select('*, profiles(full_name, avatar_url)')
      .eq('status', 'active')
      .order('created_at', ascending: false)
      .limit(30);
  return List<Map<String, dynamic>>.from(data);
});

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(socialFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_outlined, color: Color(0xFFB8943F)),
            onPressed: () {},
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
        data: (posts) => posts.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: const Color(0xFFB8943F),
                onRefresh: () => ref.refresh(socialFeedProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => _PostCard(post: posts[i]),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Color(0xFFB8943F)),
          const SizedBox(height: 16),
          const Text('No stories yet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Be the first to share your Sri Lanka experience!', style: TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.create_outlined),
            label: const Text('Share Story'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB8943F)),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final profile = post['profiles'] as Map<String, dynamic>?;
    final images = (post['images'] as List?)?.cast<String>() ?? [];
    final likeCount = post['likes_count'] ?? 0;
    final createdAt = post['created_at'] != null
        ? DateTime.tryParse(post['created_at'].toString())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFB8943F).withOpacity(0.2),
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile!['avatar_url'].toString())
                      : null,
                  child: profile?['avatar_url'] == null
                      ? Text(
                          (profile?['full_name'] ?? '?').toString().isNotEmpty
                              ? (profile?['full_name'] ?? '?').toString()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (profile?['full_name'] ?? 'Community Member').toString(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (createdAt != null)
                        Text(
                          _timeAgo(createdAt),
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post['caption'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                post['caption'].toString(),
                style: const TextStyle(color: Colors.white87, fontSize: 14, height: 1.5),
              ),
            ),
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    images.first,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2A2A3E),
                      child: const Icon(Icons.image_outlined, color: Colors.white38, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Icon(Icons.favorite_border, size: 18, color: Colors.white38),
                const SizedBox(width: 4),
                Text('$likeCount', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white38),
                const SizedBox(width: 4),
                Text('${post['comments_count'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const Spacer(),
                if (post['vertical'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8943F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (post['vertical'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(color: Color(0xFFB8943F), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
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
    return 'Just now';
  }
}

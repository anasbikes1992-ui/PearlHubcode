import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    _nameCtrl = TextEditingController(text: profile?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await supabase.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      }).eq('id', userId);
    }
    setState(() { _saving = false; _isEditing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final initials = (profile?.fullName ?? 'G').isNotEmpty ? (profile?.fullName ?? 'G')[0].toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () { if (_isEditing) { _save(); } else { setState(() => _isEditing = true); } },
            child: Text(_isEditing ? (_saving ? 'Saving...' : 'Save') : 'Edit', style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + Name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFFB8943F).withOpacity(0.2),
                  child: Text(initials, style: const TextStyle(color: Color(0xFFB8943F), fontSize: 32, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Text(profile?.fullName ?? 'Guest', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(profile?.email ?? '', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 8),
                if (profile?.role != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFB8943F).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text((profile?.role ?? '').toUpperCase(), style: const TextStyle(color: Color(0xFFB8943F), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Edit Form
          if (_isEditing) ...[
            _label('Full Name'),
            _field(_nameCtrl, 'Your full name'),
            const SizedBox(height: 16),
            _label('Phone'),
            _field(_phoneCtrl, '+94 XX XXX XXXX'),
            const SizedBox(height: 24),
          ],

          // Stats row
          Row(
            children: [
              _StatTile('Wallet', 'LKR ${profile?.walletBalance?.toStringAsFixed(0) ?? '0'}', Icons.account_balance_wallet_outlined),
              const SizedBox(width: 12),
              _StatTile('Points', '${profile?.pearlPointsBalance ?? 0}', Icons.stars_outlined),
            ],
          ),
          const SizedBox(height: 24),

          // Navigation tiles
          _NavTile(Icons.book_outlined, 'My Bookings', () => context.push('/bookings')),
          _NavTile(Icons.account_balance_wallet_outlined, 'Wallet & Transactions', () => context.push('/wallet')),
          _NavTile(Icons.stars_outlined, 'Pearl Points', () => context.push('/pearl-points')),
          _NavTile(Icons.people_outline, 'Community Feed', () => context.push('/social')),
          _NavTile(Icons.support_agent_outlined, 'AI Concierge', () => context.push('/concierge')),
          _NavTile(Icons.verified_outlined, 'Verify Account', () {}),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
  );

  Widget _field(TextEditingController ctrl, String hint) => Container(
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
    ),
  );
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFB8943F), size: 20),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavTile(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: const Color(0xFFB8943F).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFFB8943F), size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

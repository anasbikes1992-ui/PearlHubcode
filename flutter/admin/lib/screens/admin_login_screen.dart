import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }
    await ref.read(authProvider.notifier).refreshProfile();
    final auth = ref.read(authProvider);
    if (!mounted) return;
    if (auth.profile?.role != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin access required.')));
      await ref.read(authProvider.notifier).signOut();
      return;
    }
    context.go('/overview');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Signing in...' : 'Sign in'))),
          ],
        ),
      ),
    );
  }
}

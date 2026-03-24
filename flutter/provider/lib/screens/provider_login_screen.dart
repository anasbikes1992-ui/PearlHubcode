import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

class ProviderLoginScreen extends ConsumerStatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  ConsumerState<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends ConsumerState<ProviderLoginScreen> {
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
    final error = await ref.read(authProvider.notifier).signIn(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }
    await ref.read(authProvider.notifier).refreshProfile();
    final auth = ref.read(authProvider);
    if (!mounted) return;
    if (!auth.isProvider && !auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This account does not have provider access.')));
      await ref.read(authProvider.notifier).signOut();
      return;
    }
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider login')),
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

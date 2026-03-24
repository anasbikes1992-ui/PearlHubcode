import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pearlhub_shared/models/user_profile.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      fullName: _nameCtrl.text.trim(),
      role: _role,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Check your email to confirm.')));
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    const roles = [
      UserRole.customer,
      UserRole.owner,
      UserRole.broker,
      UserRole.stayProvider,
      UserRole.vehicleProvider,
      UserRole.eventOrganizer,
      UserRole.sme,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')), 
                const SizedBox(height: 16),
                TextFormField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true, validator: (v) => v == null || v.length < 8 ? 'Minimum 8 characters' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: _role,
                  items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role.label))).toList(),
                  onChanged: (value) => setState(() => _role = value ?? UserRole.customer),
                  decoration: const InputDecoration(labelText: 'Account type'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Creating account...' : 'Create account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

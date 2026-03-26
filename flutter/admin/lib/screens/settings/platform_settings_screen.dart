import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final platformSettingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('platform_config')
      .select('key, value, description, category, is_public')
      .order('category')
      .order('key');
  return List<Map<String, dynamic>>.from(data);
});

class PlatformSettingsScreen extends ConsumerWidget {
  const PlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(platformSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Platform settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          // Group by category
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final item in items) {
            final cat = (item['category'] ?? 'general').toString();
            (grouped[cat] ??= []).add(item);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final cat in grouped.keys) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    cat.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB8943F)),
                  ),
                ),
                for (final item in grouped[cat]!)
                  _ConfigTile(item: item),
                const SizedBox(height: 4),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ConfigTile extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _ConfigTile({required this.item});

  String _displayValue(dynamic val) {
    if (val == null) return 'null';
    final s = val.toString();
    // Unwrap JSON string quotes
    if (s.startsWith('"') && s.endsWith('"')) return s.substring(1, s.length - 1);
    return s;
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final key = item['key'].toString();
    final rawValue = _displayValue(item['value']);
    final ctrl = TextEditingController(text: rawValue);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(key),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((item['description'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(item['description'].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _save(context, ref, key, ctrl.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String key, String rawInput) async {
    dynamic jsonValue;
    // Try to parse as JSON; if it fails, treat as a JSON string
    try {
      jsonValue = jsonDecode(rawInput);
    } catch (_) {
      jsonValue = rawInput; // will be stored as JSON string by Supabase
    }
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.rpc('admin_set_platform_config', params: {
        'p_key':   key,
        'p_value': jsonValue,
      });
      ref.invalidate(platformSettingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setting saved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPublic = item['is_public'] as bool? ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text((item['key'] ?? '').toString(), style: const TextStyle(fontSize: 14))),
            if (isPublic)
              const Tooltip(
                message: 'Publicly readable',
                child: Icon(Icons.public, size: 14, color: Colors.green),
              ),
          ],
        ),
        subtitle: (item['description'] ?? '').toString().isNotEmpty
            ? Text((item['description'] ?? '').toString(), style: const TextStyle(fontSize: 11))
            : null,
        trailing: SizedBox(
          width: 130,
          child: Text(
            _displayValue(item['value']),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFB8943F)),
          ),
        ),
        onTap: () => _showEditDialog(context, ref),
      ),
    );
  }
}

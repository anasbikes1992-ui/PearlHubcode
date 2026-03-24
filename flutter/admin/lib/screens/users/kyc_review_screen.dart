import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final kycReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('kyc_documents')
      .select('id, user_id, doc_type, doc_number, front_url, back_url, selfie_url, status, admin_notes, submitted_at')
      .order('submitted_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(data);
});

class KYCReviewScreen extends ConsumerWidget {
  const KYCReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(kycReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('KYC reviews')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No KYC documents to review'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) => _KYCCard(doc: items[i]),
              ),
      ),
    );
  }
}

class _KYCCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> doc;
  const _KYCCard({required this.doc});

  @override
  ConsumerState<_KYCCard> createState() => _KYCCardState();
}

class _KYCCardState extends ConsumerState<_KYCCard> {
  bool _loading = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = (widget.doc['admin_notes'] ?? '').toString();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _review(String status) async {
    setState(() => _loading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.rpc('admin_review_kyc', params: {
        'p_kyc_id':     widget.doc['id'],
        'p_status':     status,
        'p_admin_note': _notesCtrl.text.trim(),
      });
      ref.invalidate(kycReviewsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document $status'), backgroundColor: status == 'approved' ? Colors.green : Colors.red),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Image unavailable'),
                )),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.doc['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final statusColor = switch (status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.doc['doc_type'] ?? 'document').toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('User: ${(widget.doc['user_id'] ?? '').toString().substring(0, 8)}…',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if ((widget.doc['doc_number'] ?? '').toString().isNotEmpty)
                        Text('# ${widget.doc['doc_number']}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Chip(label: Text(status), backgroundColor: statusColor.withOpacity(0.15),
                    labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // Document images
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in [
                    if ((widget.doc['front_url'] ?? '').toString().isNotEmpty) ('Front', widget.doc['front_url'].toString()),
                    if ((widget.doc['back_url'] ?? '').toString().isNotEmpty) ('Back', widget.doc['back_url'].toString()),
                    if ((widget.doc['selfie_url'] ?? '').toString().isNotEmpty) ('Selfie', widget.doc['selfie_url'].toString()),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => _viewImage(entry.$2),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(entry.$2, width: 100, height: 70, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 100, height: 70,
                                    color: Colors.black12, child: const Icon(Icons.broken_image))),
                            ),
                            const SizedBox(height: 4),
                            Text(entry.$1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Admin notes
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Admin notes',
                hintText: 'Reason for rejection or notes…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Action buttons (only for pending)
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _loading ? null : () => _review('approved'),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: _loading ? null : () => _review('rejected'),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              )
            else
              Text('Reviewed: $status', style: TextStyle(color: statusColor, fontSize: 12)),

            // Submitted date
            const SizedBox(height: 8),
            Text('Submitted: ${(widget.doc['submitted_at'] ?? '').toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

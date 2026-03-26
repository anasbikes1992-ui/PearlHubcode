// customer/lib/screens/parcel/parcel_delivery_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _itemTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(supabaseProvider).from('parcel_item_types').select().eq('active', true);
  return (data as List).cast<Map<String, dynamic>>();
});

const List<Map<String, String>> _statusSteps = [
  {'key': 'pending',    'label': 'Pending'},
  {'key': 'confirmed',  'label': 'Confirmed'},
  {'key': 'picked_up',  'label': 'Picked Up'},
  {'key': 'in_transit', 'label': 'In Transit'},
  {'key': 'delivered',  'label': 'Delivered'},
];

// ── Main screen with Send / Track tabs ──────────────────────────────────────
class ParcelDeliveryScreen extends ConsumerStatefulWidget {
  const ParcelDeliveryScreen({super.key});

  @override
  ConsumerState<ParcelDeliveryScreen> createState() => _ParcelDeliveryScreenState();
}

class _ParcelDeliveryScreenState extends ConsumerState<ParcelDeliveryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Parcel Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.send, size: 18), text: 'Send Parcel'),
            Tab(icon: Icon(Icons.search, size: 18), text: 'Track Parcel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SendParcelTab(),
          const _TrackParcelTab(),
        ],
      ),
    );
  }
}

// ── SEND TAB ─────────────────────────────────────────────────────────────────
class _SendParcelTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SendParcelTab> createState() => _SendParcelTabState();
}

class _SendParcelTabState extends ConsumerState<_SendParcelTab> {
  static const _orange = Color(0xFFE65100);
  static const _gold = Color(0xFFB8943F);

  final _senderNameCtrl   = TextEditingController();
  final _senderPhoneCtrl  = TextEditingController();
  final _recipientNameCtrl  = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _pickupCtrl   = TextEditingController();
  final _dropoffCtrl  = TextEditingController();
  final _notesCtrl    = TextEditingController();

  String? _itemTypeId;
  bool _fragile = false;
  bool _insured = false;
  bool _pickupMode = true; // true = setting pickup pin on map
  LatLng? _pickup;
  LatLng? _dropoff;
  bool _sending = false;
  Map<String, dynamic>? _sent; // result

  @override
  void dispose() {
    for (final c in [_senderNameCtrl, _senderPhoneCtrl, _recipientNameCtrl,
                     _recipientPhoneCtrl, _pickupCtrl, _dropoffCtrl, _notesCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_senderPhoneCtrl.text.isEmpty || _recipientPhoneCtrl.text.isEmpty ||
        _pickupCtrl.text.isEmpty || _dropoffCtrl.text.isEmpty) {
      _toast('Please fill in all required fields.');
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) { _toast('Please sign in to send a parcel.'); return; }

    final itemTypes = ref.read(_itemTypesProvider).value ?? [];
    final selectedType = itemTypes.firstWhere(
      (t) => t['id'] == _itemTypeId,
      orElse: () => <String, dynamic>{},
    );
    final baseFare = ((selectedType['base_price'] ?? 350) as num).toDouble();
    final insuranceFee = _insured ? 150.0 : 0.0;

    setState(() => _sending = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final res = await supabase.from('parcel_deliveries').insert({
        'sender_user_id': auth.user!.id,
        'item_type_id': _itemTypeId,
        'sender_name': _senderNameCtrl.text.isNotEmpty ? _senderNameCtrl.text : null,
        'sender_phone': _senderPhoneCtrl.text,
        'recipient_name': _recipientNameCtrl.text.isNotEmpty ? _recipientNameCtrl.text : null,
        'recipient_phone': _recipientPhoneCtrl.text,
        'pickup_address': _pickupCtrl.text,
        'dropoff_address': _dropoffCtrl.text,
        'pickup_lat': _pickup?.latitude,
        'pickup_lng': _pickup?.longitude,
        'dropoff_lat': _dropoff?.latitude,
        'dropoff_lng': _dropoff?.longitude,
        'fragile': _fragile,
        'insured': _insured,
        'notes': _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        'fare': baseFare + insuranceFee,
        'insurance_fee': insuranceFee,
        'status': 'pending',
      }).select().single();
      if (mounted) setState(() => _sent = res);
    } catch (e) {
      _toast('❌ Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_sent != null) return _SuccessView(parcelId: _sent!['id'] as String, onReset: () => setState(() => _sent = null));

    final itemTypesAsync = ref.watch(_itemTypesProvider);

    return CustomScrollView(
      slivers: [
        // Map
        SliverToBoxAdapter(
          child: Column(children: [
            Container(
              color: _pickupMode ? const Color(0xFFB8943F).withOpacity(0.1) : _orange.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(_pickupMode ? Icons.location_on : Icons.flag, color: _pickupMode ? _gold : _orange, size: 18),
                const SizedBox(width: 8),
                Text(
                  _pickupMode ? 'Tap map to set PICKUP location 📦' : 'Tap map to set DROP-OFF location 🏠',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                      color: _pickupMode ? _gold : _orange),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _pickupMode = !_pickupMode),
                  child: Text(_pickupMode ? 'Switch to Drop-off' : 'Switch to Pickup',
                      style: TextStyle(color: _pickupMode ? _orange : _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _pickup ?? const LatLng(6.9271, 79.8612),
                  initialZoom: 12,
                  onTap: (_, point) {
                    setState(() {
                      if (_pickupMode) { _pickup = point; }
                      else { _dropoff = point; }
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pearlhub.customer',
                  ),
                  MarkerLayer(markers: [
                    if (_pickup != null) Marker(
                      point: _pickup!,
                      width: 36, height: 36,
                      child: Container(
                        decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                        child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
                      ),
                    ),
                    if (_dropoff != null) Marker(
                      point: _dropoff!,
                      width: 36, height: 36,
                      child: Container(
                        decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                        child: const Icon(Icons.flag, color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Item type
              _section('Item Type'),
              itemTypesAsync.when(
                data: (types) => DropdownButtonFormField<String>(
                  value: _itemTypeId,
                  hint: const Text('Select item type'),
                  decoration: _inputDecoration(null),
                  items: types.map((t) => DropdownMenuItem<String>(
                      value: t['id'] as String,
                      child: Text('${t['icon'] ?? '📦'} ${t['name']}  —  Rs. ${((t['base_price'] ?? 0) as num).toStringAsFixed(0)}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _itemTypeId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // Sender
              _section('Sender'),
              _field(_senderNameCtrl, 'Sender Name', Icons.person_outline),
              const SizedBox(height: 8),
              _field(_senderPhoneCtrl, 'Sender Phone *', Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 12),

              // Recipient
              _section('Recipient'),
              _field(_recipientNameCtrl, 'Recipient Name', Icons.person_pin_outlined),
              const SizedBox(height: 8),
              _field(_recipientPhoneCtrl, 'Recipient Phone *', Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 12),

              // Addresses
              _section('Pickup & Drop-off'),
              _mapField(_pickupCtrl, 'Pickup Address *', Icons.location_on_outlined, _gold, () => setState(() => _pickupMode = true)),
              const SizedBox(height: 8),
              _mapField(_dropoffCtrl, 'Drop-off Address *', Icons.flag_outlined, _orange, () => setState(() => _pickupMode = false)),
              const SizedBox(height: 12),

              // Options
              Row(children: [
                Expanded(child: CheckboxListTile(
                  value: _fragile,
                  onChanged: (v) => setState(() => _fragile = v ?? false),
                  title: const Text('Fragile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: _gold,
                )),
                Expanded(child: CheckboxListTile(
                  value: _insured,
                  onChanged: (v) => setState(() => _insured = v ?? false),
                  title: const Text('Insured +Rs. 150', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: _gold,
                )),
              ]),

              // Notes
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: _inputDecoration('Notes for driver (optional)'),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('🚀 Send Parcel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType? type}) => TextField(
    controller: c, keyboardType: type,
    decoration: _inputDecoration(hint, icon: icon),
  );

  Widget _mapField(TextEditingController c, String hint, IconData icon, Color accent, VoidCallback onPin) {
    return Row(children: [
      Expanded(child: TextField(controller: c, decoration: _inputDecoration(hint, icon: icon))),
      const SizedBox(width: 8),
      InkWell(
        onTap: onPin,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: accent.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
            color: accent.withOpacity(0.06),
          ),
          child: Icon(Icons.pin_drop_outlined, color: accent, size: 22),
        ),
      ),
    ]);
  }

  InputDecoration _inputDecoration(String? hint, {IconData? icon}) => InputDecoration(
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  );
}

// ── TRACK TAB ─────────────────────────────────────────────────────────────────
class _TrackParcelTab extends ConsumerStatefulWidget {
  const _TrackParcelTab();

  @override
  ConsumerState<_TrackParcelTab> createState() => _TrackParcelTabState();
}

class _TrackParcelTabState extends ConsumerState<_TrackParcelTab> {
  static const _orange = Color(0xFFE65100);
  final _idCtrl = TextEditingController();
  Map<String, dynamic>? _parcel;
  bool _tracking = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (_idCtrl.text.trim().isEmpty) return;
    setState(() { _tracking = true; _error = null; _parcel = null; });
    try {
      final data = await ref.read(supabaseProvider)
          .from('parcel_deliveries')
          .select('*, parcel_item_types(name, icon)')
          .eq('id', _idCtrl.text.trim())
          .maybeSingle();
      if (mounted) setState(() { _parcel = data; _error = data == null ? 'No parcel found with that ID.' : null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _tracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Track Your Parcel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _idCtrl,
              onSubmitted: (_) => _track(),
              decoration: InputDecoration(
                hintText: 'Paste your parcel tracking ID…',
                hintStyle: const TextStyle(fontFamily: 'monospace'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _tracking ? null : _track,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            ),
            child: _tracking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search),
          ),
        ]),
        const SizedBox(height: 16),

        if (_error != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),

        if (_parcel != null) _ParcelResult(parcel: _parcel!),
      ],
    );
  }
}

class _ParcelResult extends StatelessWidget {
  final Map<String, dynamic> parcel;
  const _ParcelResult({required this.parcel});

  static const _orange = Color(0xFFE65100);

  String get _status => (parcel['status'] ?? 'pending') as String;

  int get _stepIndex {
    const steps = ['pending', 'confirmed', 'picked_up', 'in_transit', 'delivered'];
    return steps.indexOf(_status).clamp(0, steps.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Status header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_orange.withOpacity(0.08), _orange.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withOpacity(0.2)),
        ),
        child: Row(children: [
          Text(_statusEmoji(_status), style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_statusLabel(_status), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text((parcel['created_at'] ?? '').toString().split('T')[0],
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ])),
        ]),
      ),
      const SizedBox(height: 16),

      // Progress stepper
      Row(children: List.generate(_statusSteps.length, (i) {
        final done = i <= _stepIndex;
        return Expanded(child: Column(children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: done ? _orange : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(_statusSteps[i]['label']!, style: TextStyle(fontSize: 9, color: done ? _orange : Colors.grey, fontWeight: FontWeight.bold)),
        ]));
      })),

      const SizedBox(height: 16),

      // Details card
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _row('From', parcel['pickup_address'] ?? '—'),
            _divider(),
            _row('To', parcel['dropoff_address'] ?? '—'),
            _divider(),
            _row('Recipient', parcel['recipient_phone'] ?? '—'),
            if (parcel['parcel_item_types'] != null) ...[
              _divider(),
              _row('Item Type', '${parcel['parcel_item_types']['icon'] ?? '📦'} ${parcel['parcel_item_types']['name']}'),
            ],
            _divider(),
            _row('Fare', 'Rs. ${((parcel['fare'] ?? 0) as num).toStringAsFixed(0)}', bold: true),
            if (parcel['insured'] == true) ...[
              _divider(),
              _row('Insurance', '✅ Covered'),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _row(String k, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 90, child: Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
      Expanded(child: Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13))),
    ]),
  );

  Widget _divider() => Divider(color: Colors.grey.shade100, height: 1);

  String _statusEmoji(String s) {
    switch (s) {
      case 'confirmed': return '✅';
      case 'picked_up': return '📦';
      case 'in_transit': return '🚚';
      case 'delivered': return '🏠';
      case 'cancelled': return '❌';
      default: return '🕐';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed': return 'Confirmed';
      case 'picked_up': return 'Picked Up';
      case 'in_transit': return 'In Transit';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return 'Pending';
    }
  }
}

// ── Success view after send ───────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String parcelId;
  final VoidCallback onReset;
  const _SuccessView({required this.parcelId, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 72),
            const SizedBox(height: 20),
            const Text('Parcel Submitted!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 8),
            const Text('Save your tracking ID:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withOpacity(0.06),
                border: Border.all(color: const Color(0xFFE65100).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(parcelId,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.add),
              label: const Text('Send Another Parcel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

// Fetches just the pricing fields for a listing by type
final _listingPricingProvider = FutureProvider.family<Map<String, dynamic>?, (String, String)>((ref, args) async {
  final supabase = ref.read(supabaseProvider);
  final (listingId, listingType) = args;
  String table;
  String priceCol;
  switch (listingType) {
    case 'stay':
      table = 'stays_listings'; priceCol = 'price_per_night';       break;
    case 'vehicle':
      table = 'vehicles_listings'; priceCol = 'daily_rate';         break;
    case 'event':
      table = 'events_listings'; priceCol = 'ticket_price';         break;
    default:
      return null;
  }
  final row = await supabase
      .from(table)
      .select('id, title, $priceCol, images')
      .eq('id', listingId)
      .maybeSingle();
  if (row == null) return null;
  final price = (row[priceCol] as num?)?.toDouble() ?? 0;
  return {'title': row['title'] ?? '', 'price': price, 'images': row['images'] ?? []};
});

// ── Service charge & tax lookup from platform_config ──────────
const double _kDefaultServicePct = 0.05;  // 5%
const double _kDefaultTaxPct     = 0.10;  // 10%

class CheckoutScreen extends ConsumerStatefulWidget {
  final String listingId;
  final String listingType;

  const CheckoutScreen({super.key, required this.listingId, required this.listingType});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  bool _submitting = false;

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays.clamp(1, 365);
  }

  double _baseTotal(double unitPrice) => unitPrice * _nights;
  double _serviceCharge(double base) => base * _kDefaultServicePct;
  double _tax(double base) => base * _kDefaultTaxPct;
  double _grandTotal(double unitPrice) {
    final base = _baseTotal(unitPrice);
    return base + _serviceCharge(base) + _tax(base);
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickCheckIn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _checkIn = picked;
      if (_checkOut != null && !_checkOut!.isAfter(_checkIn!)) {
        _checkOut = _checkIn!.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final first = (_checkIn ?? DateTime.now()).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut ?? first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 364)),
    );
    if (picked != null) setState(() => _checkOut = picked);
  }

  Future<void> _confirmBooking(double unitPrice) async {
    if (_checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select check-in and check-out dates')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;
      final total = _grandTotal(unitPrice);
      await supabase.from('bookings').insert({
        'user_id':        userId,
        'listing_id':     widget.listingId,
        'listing_type':   widget.listingType,
        'booking_date':   _fmt(DateTime.now()),
        'check_in_date':  _fmt(_checkIn!),
        'check_out_date': _fmt(_checkOut!),
        'total_amount':   total.roundToDouble(),
        'currency':       'LKR',
        'status':         'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking created — proceed to payment to confirm.')),
      );
      context.go('/bookings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(_listingPricingProvider((widget.listingId, widget.listingType)));
    final unitLabel = widget.listingType == 'event' ? 'ticket' : (widget.listingType == 'vehicle' ? 'day' : 'night');
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading listing: $e')),
        data: (listing) {
          final unitPrice = (listing?['price'] as double?) ?? 0;
          final title = (listing?['title'] ?? widget.listingType).toString();
          final images = listing?['images'] as List? ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image
                if (images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(images.first.toString(), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12)),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text('LKR ${unitPrice.toStringAsFixed(0)} / $unitLabel',
                    style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                const Divider(),

                // Date selectors
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Check-in'),
                  trailing: Text(_checkIn != null ? _fmt(_checkIn!) : 'Select date',
                      style: TextStyle(color: _checkIn != null ? null : Colors.grey)),
                  onTap: _pickCheckIn,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Check-out'),
                  trailing: Text(_checkOut != null ? _fmt(_checkOut!) : 'Select date',
                      style: TextStyle(color: _checkOut != null ? null : Colors.grey)),
                  onTap: _pickCheckOut,
                ),

                if (_nights > 0 && unitPrice > 0) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  _PriceLine(label: '$_nights ${_nights == 1 ? unitLabel : '${unitLabel}s'} × LKR ${unitPrice.toStringAsFixed(0)}',
                      amount: _baseTotal(unitPrice)),
                  _PriceLine(label: 'Service charge (5%)', amount: _serviceCharge(_baseTotal(unitPrice))),
                  _PriceLine(label: 'Local tax (10%)', amount: _tax(_baseTotal(unitPrice))),
                  const Divider(),
                  _PriceLine(label: 'Total', amount: _grandTotal(unitPrice), bold: true),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : () => _confirmBooking(unitPrice),
                    child: Text(_submitting ? 'Creating booking…' : 'Confirm booking'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'After confirming, complete payment via PayHere or Pearl Wallet to lock your dates.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _PriceLine({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            Text('LKR ${amount.toStringAsFixed(0)}',
                style: bold
                    ? const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB8943F))
                    : null),
          ],
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/listings_service.dart';

class VehiclesListScreen extends ConsumerStatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  ConsumerState<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends ConsumerState<VehiclesListScreen> {
  String _type = 'all';
  bool _withDriver = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(vehiclesProvider(null));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Vehicles',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'car', 'van', 'bus', 'tuk_tuk', 'motorbike']
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _type = t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _type == t
                                          ? const Color(0xFFB8943F)
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                        t == 'tuk_tuk'
                                            ? 'Tuk Tuk'
                                            : t == 'all'
                                                ? 'All'
                                                : t[0].toUpperCase() +
                                                    t.substring(1),
                                        style: TextStyle(
                                            color: _type == t
                                                ? Colors.white
                                                : Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text('Driver',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Switch(
                        value: _withDriver,
                        onChanged: (v) => setState(() => _withDriver = v),
                        activeColor: const Color(0xFFB8943F)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white54))),
              data: (vehicles) {
                final filtered = vehicles.where((v) {
                  if (_type != 'all' && v.vehicleType != _type) return false;
                  if (_withDriver && v.withDriver != true) return false;
                  return true;
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No vehicles found',
                          style: TextStyle(color: Colors.white38)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final v = filtered[i];
                    return GestureDetector(
                      onTap: () => context.push('/vehicles/${v.id}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06))),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: v.images.isNotEmpty
                                  ? Image.network(v.images.first,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder())
                                  : _placeholder(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v.title,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(v.location ?? '',
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'LKR ${v.pricePerDay.toStringAsFixed(0)}/day',
                                      style: const TextStyle(
                                          color: Color(0xFFB8943F),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            if (v.withDriver == true)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFB8943F)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('+ Driver',
                                      style: TextStyle(
                                          color: Color(0xFFB8943F),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
      width: 72,
      height: 72,
      color: Colors.white.withOpacity(0.05),
      child:
          const Icon(Icons.directions_car_outlined, color: Colors.white24));
}

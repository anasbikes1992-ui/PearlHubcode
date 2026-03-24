import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pearlhub_shared/models/user_profile.dart';
import 'package:pearlhub_shared/services/auth_service.dart';
import 'package:pearlhub_shared/services/listings_service.dart';

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).profile?.role;
    final staysAsync = ref.watch(providerStaysProvider);
    final vehiclesAsync = ref.watch(providerVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My listings'),
        actions: [IconButton(onPressed: () => context.push('/listings/create'), icon: const Icon(Icons.add))],
      ),
      body: role == UserRole.vehicleProvider
          ? vehiclesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (vehicles) => _ListingList(items: vehicles.map((e) => _ListingItem(e.title, e.status.name, 'LKR ${e.pricePerDay.toStringAsFixed(0)}/day')).toList()),
            )
          : staysAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (stays) => _ListingList(items: stays.map((e) => _ListingItem(e.name, e.status.name, 'LKR ${e.pricePerNight.toStringAsFixed(0)}/night')).toList()),
            ),
    );
  }
}

class _ListingItem {
  final String title;
  final String status;
  final String price;
  _ListingItem(this.title, this.status, this.price);
}

class _ListingList extends StatelessWidget {
  final List<_ListingItem> items;
  const _ListingList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No listings created yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => Card(
        child: ListTile(
          leading: const Icon(Icons.list_alt_outlined),
          title: Text(items[i].title),
          subtitle: Text(items[i].status),
          trailing: Text(items[i].price),
        ),
      ),
    );
  }
}

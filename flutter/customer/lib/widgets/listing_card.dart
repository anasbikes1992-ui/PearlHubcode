import 'package:flutter/material.dart';
import 'package:pearlhub_shared/models/listings.dart';

class StayCard extends StatelessWidget {
  final Stay stay;
  final VoidCallback onTap;

  const StayCard({super.key, required this.stay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: stay.images.isNotEmpty
                      ? Image.network(stay.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 40))
                      : const Icon(Icons.hotel_outlined, size: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stay.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(stay.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('LKR ${stay.pricePerNight.toStringAsFixed(0)} / night', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final PearlEvent event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: event.image.isNotEmpty
                      ? Image.network(event.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.event_outlined, size: 40))
                      : const Icon(Icons.event_outlined, size: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${event.date} • ${event.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

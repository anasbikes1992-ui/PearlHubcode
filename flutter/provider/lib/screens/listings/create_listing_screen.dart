// provider/lib/screens/listings/create_listing_screen.dart
// Role-aware listing form — shows the right form based on provider role

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import 'dart:io';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _isSubmitting = false;
  List<File> _selectedImages = [];
  String _listingSubtype = 'standard'; // vehicle providers only

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String get _table {
    final role = ref.read(authProvider).profile?.role;
    return switch (role) {
      UserRole.stayProvider => 'stays',
      UserRole.vehicleProvider => 'vehicles',
      UserRole.eventOrganizer => 'events',
      UserRole.owner || UserRole.broker => 'properties',
      UserRole.sme => 'sme_businesses',
      _ => 'stays',
    };
  }

  String get _priceLabel {
    final role = ref.read(authProvider).profile?.role;
    return switch (role) {
      UserRole.stayProvider => 'Price per night (LKR)',
      UserRole.vehicleProvider => 'Price per day (LKR)',
      UserRole.eventOrganizer => 'Ticket price (LKR)',
      _ => 'Price (LKR)',
    };
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85, limit: 8);
    setState(() => _selectedImages = images.map((x) => File(x.path)).toList());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;

      // Upload images to Supabase Storage
      final imageUrls = <String>[];
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final ext = file.path.split('.').last.toLowerCase();
        // Validate MIME type (mirrors ImageUpload component's validation)
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          throw Exception('Invalid image type: $ext');
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw Exception('Image ${i + 1} exceeds 5MB limit');
        }

        final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await supabase.storage.from('listings').uploadBinary(path, bytes);
        final url = supabase.storage.from('listings').getPublicUrl(path);
        imageUrls.add(url);
      }

      // Build insert payload based on role
      final role = ref.read(authProvider).profile?.role;
      final payload = _buildPayload(role, userId, imageUrls);

      await supabase.from(_table).insert(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing submitted for review'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Map<String, dynamic> _buildPayload(UserRole? role, String userId, List<String> imageUrls) {
    final base = {
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'images': imageUrls,
      'status': 'pending',
      'currency': 'LKR',
    };

    return switch (role) {
      UserRole.stayProvider => {
        ...base,
        'provider_id': userId,
        'name': _titleCtrl.text.trim(),
        'price_per_night': double.parse(_priceCtrl.text),
        'approved': false,
        'stay_type': 'guesthouse',
        'bedrooms': 1,
        'bathrooms': 1,
        'max_guests': 2,
        'stars': 3,
        'rating': 0.0,
        'review_count': 0,
      },
      UserRole.vehicleProvider => {
        ...base,
        'provider_id': userId,
        'title': _titleCtrl.text.trim(),
        'price_per_day': double.parse(_priceCtrl.text),
        'vehicle_type': 'car',
        'listing_subtype': _listingSubtype,
        'make': '',
        'model': '',
        'year': DateTime.now().year,
        'seats': 4,
        'with_driver': false,
        'insurance_included': false,
        'fuel': 'petrol',
        'rating': 0.0,
        'trips': 0,
        'is_fleet': false,
        'lat': 6.9271,
        'lng': 79.8612,
      },
      UserRole.sme => {
        ...base,
        'owner_id': userId,
        'business_name': _titleCtrl.text.trim(),
        'category': 'General',
        'phone': '',
        'email': ref.read(authProvider).profile?.email ?? '',
        'verified': false,
      },
      _ => {
        ...base,
        'owner_id': userId,
        'title': _titleCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'property_type': 'house',
        'listing_type': 'sale',
        'address': _locationCtrl.text.trim(),
        'area_sqft': 0,
        'bedrooms': 0,
        'bathrooms': 0,
        'lat': 6.9271,
        'lng': 79.8612,
        'views': 0,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).profile?.role;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('New ${_listingTypeName(role)} Listing', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image picker ───────────────────────────────────────────
              Text('Photos', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImages,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 120,
                  decoration: BoxDecoration(
                    color: _selectedImages.isEmpty ? Colors.grey.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedImages.isEmpty ? Colors.grey.shade300 : const Color(0xFFB8943F),
                      style: _selectedImages.isEmpty ? BorderStyle.solid : BorderStyle.solid,
                    ),
                  ),
                  child: _selectedImages.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to add photos', style: TextStyle(color: Colors.grey)),
                            Text('Max 8 images, 5MB each', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: _selectedImages.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _selectedImages.length) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 100, margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.grey),
                                ),
                              );
                            }
                            return Container(
                              width: 100, margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(image: FileImage(_selectedImages[i]), fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Form fields ────────────────────────────────────────────
              Text('Details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _listingTypeName(role) == 'SME' ? 'Business name' : 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 20) return 'At least 20 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _locationCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              if (role == UserRole.vehicleProvider) ...[  
                DropdownButtonFormField<String>(
                  value: _listingSubtype,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Use Type',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'standard', child: Text('🚗 Standard Rental')),
                    DropdownMenuItem(value: 'airport_transfer', child: Text('✈️ Airport Transfer')),
                    DropdownMenuItem(value: 'coach', child: Text('🚌 Office / Coach Transport')),
                  ],
                  onChanged: (v) => setState(() => _listingSubtype = v ?? 'standard'),
                ),
                const SizedBox(height: 14),
              ],

              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: _priceLabel,
                  prefixText: 'LKR ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ── Submit ────────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit for Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your listing will be reviewed by our moderation team before going live.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _listingTypeName(UserRole? role) => switch (role) {
    UserRole.stayProvider => 'Stay',
    UserRole.vehicleProvider => 'Vehicle',
    UserRole.eventProvider => 'Event',
    UserRole.owner || UserRole.broker => 'Property',
    UserRole.sme => 'SME',
    _ => 'Listing',
  };
}

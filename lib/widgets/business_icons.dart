import 'package:flutter/material.dart';
import '../business_types.dart';

IconData businessTypeIcon(BusinessType type) => switch (type) {
  BusinessType.retail => Icons.storefront_outlined,
  BusinessType.food => Icons.restaurant_outlined,
  BusinessType.laundry => Icons.local_laundry_service_outlined,
  BusinessType.shoeCleaning => Icons.cleaning_services_outlined,
  BusinessType.beauty => Icons.content_cut_outlined,
  BusinessType.repair => Icons.build_outlined,
  BusinessType.services => Icons.handyman_outlined,
  BusinessType.production => Icons.factory_outlined,
  BusinessType.other => Icons.work_outline,
};

IconData businessGoalIcon(String goal) {
  final text = goal.toLowerCase();
  if (text.contains('stok')) return Icons.inventory_2_outlined;
  if (text.contains('untung')) return Icons.trending_up;
  if (text.contains('terbuang')) return Icons.recycling_outlined;
  if (text.contains('waktu')) return Icons.event_available_outlined;
  if (text.contains('bayar')) return Icons.payments_outlined;
  return Icons.fact_check_outlined;
}

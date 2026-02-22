import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'table_management_service.dart';

class TableBookingService {
  static final _client = Supabase.instance.client;

  static Future<Map<String, dynamic>?> createBooking({
    required String zoneId,
    required String tableId,
    required String customerName,
    required String phone,
    int partySize = 2,
    String? note,
    int expiresInMinutes = 15,
  }) async {
    try {
      final expiresAt = DateTime.now().add(Duration(minutes: expiresInMinutes)).toUtc();
      final booking = await _client
          .from('restaurant_bookings')
          .insert({
            'zone_id': zoneId,
            'table_id': tableId,
            'customer_name': customerName,
            'phone': phone,
            'party_size': partySize,
            'note': note,
            'status': 'pending',
            'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .single();

      // Mark table unavailable
      await TableManagementService.setTableStatus(tableId, 'unavailable');
      return booking;
    } catch (e) {
      debugPrint('Error createBooking: $e');
      return null;
    }
  }

  static Future<bool> expireBooking(String bookingId) async {
    try {
      // fetch table id
      final booking = await _client
          .from('restaurant_bookings')
          .select('table_id, status')
          .eq('id', bookingId)
          .maybeSingle();
      if (booking == null) return true;

      if (booking['status'] == 'pending') {
        await _client
            .from('restaurant_bookings')
            .update({'status': 'expired'})
            .eq('id', bookingId);
        await TableManagementService.setTableStatus(booking['table_id'] as String, 'available');
      }
      return true;
    } catch (e) {
      debugPrint('Error expireBooking: $e');
      return false;
    }
  }

  static Future<bool> cancelBooking(String bookingId) async {
    try {
      final booking = await _client
          .from('restaurant_bookings')
          .select('table_id, status')
          .eq('id', bookingId)
          .maybeSingle();
      if (booking == null) return true;
      if (booking['status'] == 'pending') {
        await _client
            .from('restaurant_bookings')
            .update({'status': 'canceled'})
            .eq('id', bookingId);
        await TableManagementService.setTableStatus(booking['table_id'] as String, 'available');
      }
      return true;
    } catch (e) {
      debugPrint('Error cancelBooking: $e');
      return false;
    }
  }

  static Future<bool> confirmBooking(String bookingId, {String? orderId}) async {
    try {
      await _client
          .from('restaurant_bookings')
          .update({'status': 'confirmed', if (orderId != null) 'order_id': orderId})
          .eq('id', bookingId);
      return true;
    } catch (e) {
      debugPrint('Error confirmBooking: $e');
      return false;
    }
  }
}

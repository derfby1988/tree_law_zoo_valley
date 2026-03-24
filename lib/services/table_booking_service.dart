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
    bool isPrepaid = false,
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
            'status': isPrepaid ? 'confirmed' : 'pending',
            'payment_status': isPrepaid ? 'paid' : 'unpaid',
            'paid_at': isPrepaid ? DateTime.now().toUtc().toIso8601String() : null,
            'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .single();

      final locked = await TableManagementService.lockTableForBooking(
        tableId: tableId,
        bookingId: booking['id'].toString(),
      );
      if (!locked) {
        await _client
            .from('restaurant_bookings')
            .update({
              'status': 'canceled',
              'payment_status': isPrepaid ? 'refunded' : 'unpaid',
            })
            .eq('id', booking['id']);
        return null;
      }

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
        await TableManagementService.releaseTableFromBooking(
          tableId: booking['table_id'] as String,
          bookingId: bookingId,
        );
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
          .select('table_id, status, payment_status')
          .eq('id', bookingId)
          .maybeSingle();
      if (booking == null) return true;

      if (booking['status'] == 'canceled' || booking['status'] == 'expired') {
        await TableManagementService.releaseTableFromBooking(
          tableId: booking['table_id'] as String,
          bookingId: bookingId,
        );
        return true;
      }

      await _client
          .from('restaurant_bookings')
          .update({
            'status': 'canceled',
            'payment_status': booking['payment_status'] == 'paid' ? 'refunded' : 'unpaid',
          })
          .eq('id', bookingId);

      await TableManagementService.releaseTableFromBooking(
        tableId: booking['table_id'] as String,
        bookingId: bookingId,
      );
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
          .update({
            'status': 'confirmed',
            'payment_status': 'paid',
            'paid_at': DateTime.now().toUtc().toIso8601String(),
            if (orderId != null) 'order_id': orderId,
          })
          .eq('id', bookingId);
      return true;
    } catch (e) {
      debugPrint('Error confirmBooking: $e');
      return false;
    }
  }
}

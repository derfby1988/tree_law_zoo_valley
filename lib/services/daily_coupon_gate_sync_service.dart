import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/daily_coupon_share_token_model.dart';
import '../models/pos_discount_model.dart';
import 'daily_coupon_entry_service.dart';
import 'daily_coupon_share_token_service.dart';
import 'pos_coupon_qr_service.dart';
import 'pos_discount_service.dart';

class GateScanSyncResult {
  final bool isValid;
  final bool queued;
  final bool synced;
  final String? errorMessage;
  final String? statusMessage;
  final DailyCouponShareToken? token;

  const GateScanSyncResult({
    required this.isValid,
    required this.queued,
    required this.synced,
    this.errorMessage,
    this.statusMessage,
    this.token,
  });

  bool get succeeded => isValid && (queued || synced);
}

class DailyCouponGateSyncService {
  static const Duration _idempotencyWindow = Duration(seconds: 45);
  static const String _queueFileName = 'tlz_daily_coupon_gate_queue.json';

  static Future<File> _queueFile() async {
    final dir = Directory.systemTemp;
    return File('${dir.path}/$_queueFileName');
  }

  static Future<List<Map<String, dynamic>>> _readQueue() async {
    try {
      final file = await _queueFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error _readQueue: $e');
      return [];
    }
  }

  static Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    final file = await _queueFile();
    await file.writeAsString(jsonEncode(queue));
  }

  static String _eventKey(Map<String, dynamic> event) {
    final idempotencyKey = event['idempotency_key']?.toString();
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      return idempotencyKey;
    }

    return [
      event['discount_id'],
      event['share_token'],
      event['member_identifier'],
      event['direction'],
      event['status'],
      event['nonce'],
    ].map((e) => e?.toString() ?? '').join('|');
  }

  static String _previewShareToken(String shareToken) {
    if (shareToken.length <= 10) return shareToken;
    return '${shareToken.substring(0, 6)}...${shareToken.substring(shareToken.length - 4)}';
  }

  static String _buildIdempotencyKey({
    required String discountId,
    required String shareToken,
    required String memberIdentifier,
    required String entryArea,
    required String gateId,
    required String direction,
    required String nonce,
  }) {
    return [
      discountId,
      shareToken,
      memberIdentifier,
      entryArea,
      gateId,
      direction,
      nonce,
    ].join('|');
  }

  static Map<String, dynamic> _buildQueuedEvent({
    required PosDiscount discount,
    required Map<String, dynamic> qrResult,
    required String shareToken,
    required String memberIdentifier,
    required String entryArea,
    required String gateId,
    required String direction,
    required String? scannedBy,
    required Map<String, dynamic>? deviceInfo,
    required bool shareTokenConsumed,
    required String queuedReason,
  }) {
    final nonce = qrResult['nonce']?.toString() ?? '';
    final idempotencyKey = _buildIdempotencyKey(
      discountId: discount.id,
      shareToken: shareToken,
      memberIdentifier: memberIdentifier,
      entryArea: entryArea,
      gateId: gateId,
      direction: direction,
      nonce: nonce,
    );

    return {
      'discount_id': discount.id,
      'coupon_code': discount.couponCode,
      'coupon_audience': discount.targetingRule['coupon_audience']?.toString(),
      'share_token': shareToken,
      'share_token_consumed': shareTokenConsumed,
      'member_identifier': memberIdentifier,
      'entry_area': entryArea,
      'gate_id': gateId,
      'direction': direction,
      'status': 'valid',
      'reason_code': null,
      'scanned_by': scannedBy,
      'device_info': deviceInfo,
      'nonce': nonce,
      'key_version': qrResult['key_version']?.toString(),
      'issued_at': qrResult['issued_at']?.toString(),
      'idempotency_key': idempotencyKey,
      'queued_reason': queuedReason,
      'scanned_at': DateTime.now().toIso8601String(),
    };
  }

  static bool _isExpiredWindow(Map<String, dynamic> event) {
    final scannedAt = DateTime.tryParse(event['scanned_at']?.toString() ?? '');
    if (scannedAt == null) return true;
    return DateTime.now().difference(scannedAt).abs() > _idempotencyWindow;
  }

  static Future<bool> enqueueGateEvent(Map<String, dynamic> event) async {
    try {
      final sanitized = Map<String, dynamic>.from(event)
        ..putIfAbsent('share_token_consumed', () => false)
        ..putIfAbsent('queued_at', () => DateTime.now().toIso8601String())
        ..putIfAbsent('idempotency_key', () => _eventKey(event));

      final queue = await _readQueue();
      final key = _eventKey(sanitized);
      final exists = queue.any((item) => _eventKey(item) == key);
      if (!exists) {
        queue.add(sanitized);
        await _writeQueue(queue);
      }
      return true;
    } catch (e) {
      debugPrint('Error enqueueGateEvent: $e');
      return false;
    }
  }

  static Future<void> pruneExpiredQueue() async {
    final queue = await _readQueue();
    final pruned = queue.where((event) => !_isExpiredWindow(event)).toList();
    if (pruned.length != queue.length) {
      await _writeQueue(pruned);
    }
  }

  static Future<bool> _hasQueuedEvent(String idempotencyKey) async {
    if (idempotencyKey.trim().isEmpty) return false;
    final queue = await _readQueue();
    return queue.any((event) => event['idempotency_key']?.toString() == idempotencyKey);
  }

  static Future<int> getQueuedEventCount() async {
    final queue = await _readQueue();
    return queue.length;
  }

  static Future<bool> syncQueuedEvents() async {
    try {
      final queue = await _readQueue();
      if (queue.isEmpty) return true;

      final remaining = <Map<String, dynamic>>[];
      for (final event in queue) {
        try {
          final couponId = event['discount_id']?.toString();
          final shareToken = event['share_token']?.toString();
          final memberIdentifier = event['member_identifier']?.toString();
          final entryArea = event['entry_area']?.toString() ?? 'Unknown area';
          final direction = event['direction']?.toString() ?? 'enter';
          final status = event['status']?.toString() ?? 'pending';
          final reasonCode = event['reason_code']?.toString();
          final scannedBy = event['scanned_by']?.toString();
          final shareTokenConsumed = event['share_token_consumed'] == true;

          if (couponId == null || couponId.isEmpty || shareToken == null || shareToken.isEmpty) {
            continue;
          }

          DailyCouponShareToken? token;
          var consumedOnReplay = shareTokenConsumed;

          if (!shareTokenConsumed) {
            token = await DailyCouponShareTokenService.consumeShareToken(
              shareToken: shareToken,
              memberIdentifier: memberIdentifier,
              channel: 'gate',
              scannedBy: scannedBy,
              metadata: {
                'queued_sync': true,
                'queued_at': event['queued_at'],
                'idempotency_key': event['idempotency_key'],
              },
            );
            if (token == null) {
              remaining.add(event);
              continue;
            }
            consumedOnReplay = true;
          }

          final success = await DailyCouponEntryService.logEntry(
            discountId: couponId,
            couponCode: event['coupon_code']?.toString(),
            couponAudience: event['coupon_audience']?.toString(),
            memberIdentifier: memberIdentifier,
            entryArea: entryArea,
            gateId: event['gate_id']?.toString(),
            direction: direction,
            status: status,
            reasonCode: reasonCode,
            scannedBy: scannedBy,
            deviceInfo: event['device_info'] is Map
                ? Map<String, dynamic>.from(event['device_info'] as Map)
                : null,
            metadata: {
              'queued_sync': true,
              'queued_at': event['queued_at'],
              'idempotency_window_seconds': _idempotencyWindow.inSeconds,
              'share_token_preview': _previewShareToken(shareToken),
              'idempotency_key': event['idempotency_key'],
            },
            idempotencyKey: event['idempotency_key']?.toString(),
          );

          if (!success) {
            remaining.add({
              ...event,
              'share_token_consumed': consumedOnReplay,
            });
          }
        } catch (e) {
          debugPrint('Error syncing queued gate event: $e');
          remaining.add(event);
        }
      }

      await _writeQueue(remaining);
      return remaining.isEmpty;
    } catch (e) {
      debugPrint('Error syncQueuedEvents: $e');
      return false;
    }
  }

  static Future<GateScanSyncResult> processGateScan({
    required String qrData,
    required String memberIdentifier,
    required String entryArea,
    String? scannedBy,
    String gateId = 'admin_gate',
    String direction = 'enter',
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final qrResult = await PosCouponQRService.validateQRCode(qrData, scannedBy: scannedBy);
      if (!qrResult.isValid || qrResult.couponId == null || qrResult.couponCode == null) {
        return GateScanSyncResult(
          isValid: false,
          queued: false,
          synced: false,
          errorMessage: qrResult.errorMessage ?? 'QR ไม่ถูกต้อง',
        );
      }

      final discount = await PosDiscountService.getDiscountById(qrResult.couponId!);
      if (discount == null) {
        return const GateScanSyncResult(
          isValid: false,
          queued: false,
          synced: false,
          errorMessage: 'ไม่พบคูปองในระบบ',
        );
      }

      final rule = discount.targetingRule;
      if (rule['daily_unified_enabled'] != true) {
        return const GateScanSyncResult(
          isValid: false,
          queued: false,
          synced: false,
          errorMessage: 'ไม่ใช่คูปองรายวัน',
        );
      }

      final shareToken = await DailyCouponShareTokenService.getActiveShareToken(discount.id);
      if (shareToken == null || !shareToken.isActive || shareToken.remainingUses <= 0) {
        return const GateScanSyncResult(
          isValid: false,
          queued: false,
          synced: false,
          errorMessage: 'Share token หมดอายุหรือใช้ครบแล้ว',
        );
      }

      final idempotencyKey = _buildIdempotencyKey(
        discountId: discount.id,
        shareToken: shareToken.shareToken,
        memberIdentifier: memberIdentifier,
        entryArea: entryArea,
        gateId: gateId,
        direction: direction,
        nonce: qrResult.nonce ?? '',
      );

      if (await DailyCouponEntryService.hasLoggedEntry(idempotencyKey) || await _hasQueuedEvent(idempotencyKey)) {
        return GateScanSyncResult(
          isValid: true,
          queued: false,
          synced: true,
          token: shareToken,
          statusMessage: 'รายการนี้ถูกบันทึกแล้ว',
        );
      }

      final qrPayload = {
        'nonce': qrResult.nonce,
        'key_version': qrResult.keyVersion,
        'issued_at': qrResult.issuedAt,
      };

      var shareTokenConsumed = false;
      DailyCouponShareToken? consumedToken;

      try {
        consumedToken = await DailyCouponShareTokenService.consumeShareToken(
          shareToken: shareToken.shareToken,
          memberIdentifier: memberIdentifier,
          channel: 'gate',
          scannedBy: scannedBy,
          metadata: {
            'gate_id': gateId,
            'direction': direction,
            'idempotency_key': idempotencyKey,
          },
        );
        if (consumedToken == null) {
          throw Exception('ไม่สามารถบันทึกการใช้ share token ได้');
        }
        shareTokenConsumed = true;

        final success = await DailyCouponEntryService.logEntry(
          discountId: discount.id,
          couponCode: discount.couponCode,
          couponAudience: rule['coupon_audience']?.toString(),
          memberIdentifier: memberIdentifier,
          entryArea: entryArea,
          gateId: gateId,
          direction: direction,
          status: 'valid',
          scannedBy: scannedBy,
          deviceInfo: deviceInfo,
          metadata: {
            'kv': qrResult.keyVersion,
            'nonce': qrResult.nonce,
            'issued_at': qrResult.issuedAt,
            'share_token': shareToken.shareToken,
            'share_token_preview': consumedToken.shareTokenPreview,
            'idempotency_key': idempotencyKey,
          },
          idempotencyKey: idempotencyKey,
        );

        if (success) {
          return GateScanSyncResult(
            isValid: true,
            queued: false,
            synced: true,
            token: consumedToken,
            statusMessage: 'บันทึกการสแกนสำเร็จ',
          );
        }
      } catch (e) {
        debugPrint('Error processGateScan sync path: $e');
      }

      await enqueueGateEvent(
        _buildQueuedEvent(
          discount: discount,
          qrResult: qrPayload,
          shareToken: shareToken.shareToken,
          memberIdentifier: memberIdentifier,
          entryArea: entryArea,
          gateId: gateId,
          direction: direction,
          scannedBy: scannedBy,
          deviceInfo: deviceInfo,
          shareTokenConsumed: shareTokenConsumed,
          queuedReason: shareTokenConsumed ? 'log_failed' : 'consume_or_log_failed',
        ),
      );

      return GateScanSyncResult(
        isValid: true,
        queued: true,
        synced: false,
        token: consumedToken ?? shareToken,
        statusMessage: 'บันทึกไว้ในคิวออฟไลน์แล้ว',
      );
    } catch (e) {
      debugPrint('Error processGateScan: $e');
      return GateScanSyncResult(
        isValid: false,
        queued: false,
        synced: false,
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }

  static Future<DailyCouponShareToken?> validateAndConsumeGateScan({
    required String qrData,
    required String memberIdentifier,
    required String entryArea,
    String? scannedBy,
    String gateId = 'admin_gate',
    String direction = 'enter',
    Map<String, dynamic>? deviceInfo,
  }) async {
    final result = await processGateScan(
      qrData: qrData,
      memberIdentifier: memberIdentifier,
      entryArea: entryArea,
      scannedBy: scannedBy,
      gateId: gateId,
      direction: direction,
      deviceInfo: deviceInfo,
    );

    return result.token;
  }
}

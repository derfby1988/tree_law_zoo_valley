import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/pos_discount_model.dart';
import '../models/pos_promotion_model.dart';

/// Service สำหรับจัดการ QR Code ของคูปองและโปรโมชัน
/// รองรับการสร้าง QR, validation และบันทึกประวัติการ scan
class PosCouponQRService {
  static final SupabaseClient _client = Supabase.instance.client;
  
  /// Secret key สำหรับ HMAC signature - คูปอง (ควรเก็บใน environment variable)
  static const String _secretKey = 'tlz_coupon_secret_2026';
  
  /// Secret key สำหรับ HMAC signature - โปรโมชัน
  static const String _promotionSecretKey = 'tlz_promotion_secret_2026';
  
  /// Version ของ QR Code format
  static const int _qrVersion = 1;

  // ============================================================================
  // QR Code Generation
  // ============================================================================

  /// สร้าง QR Code content จากคูปอง
  static Map<String, dynamic> generateQRContent(PosDiscount coupon) {
    final signature = _generateSignature(
      coupon.id,
      coupon.couponCode ?? '',
      coupon.endAt,
    );

    return {
      'v': _qrVersion,
      'type': 'tlz_coupon',
      'code': coupon.couponCode ?? '',
      'discount_id': coupon.id,
      'exp': coupon.endAt?.toIso8601String().split('T')[0],
      'sig': signature,
    };
  }

  /// สร้าง HMAC signature สำหรับ QR validation
  static String _generateSignature(String couponId, String couponCode, DateTime? expiryDate) {
    final payload = '$couponId|$couponCode|${expiryDate?.toIso8601String().split('T')[0] ?? ''}';
    
    // Simple hash-based signature (ไม่ใช่ HMAC แต่ใช้ได้สำหรับ version นี้)
    // ใน production ควรใช้ crypto library ที่รองรับ HMAC
    final bytes = utf8.encode(payload + _secretKey);
    return base64Encode(bytes);
  }

  /// สร้าง QR Code widget พร้อมโลโก้ TLZ ตรงกลาง
  static Widget buildQRCode({
    required String data,
    double size = 200,
    Color backgroundColor = Colors.white,
    Color foregroundColor = Colors.black,
    bool showLogo = true,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // QR Code
            QrImageView(
              data: data,
              version: QrVersions.auto,
              size: size - 24, // ลดขนาดให้เหลือพื้นที่ขอบ
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              errorCorrectionLevel: QrErrorCorrectLevel.H, // High error correction เพื่อให้ใส่โลโก้ได้
              gapless: true,
            ),
            
            // Logo ตรงกลาง (ถ้าเปิดใช้งาน)
            if (showLogo)
              Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: backgroundColor,
                    width: 4,
                  ),
                ),
                child: Center(
                  child: _buildTLZLogo(size: size * 0.18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// สร้างโลโก้ TLZ (Tree Law Zoo)
  static Widget _buildTLZLogo({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2AD49B), // TLZ brand color (green)
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          'TLZ',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  /// สร้าง QR Code widget สำหรับแสดงใน Coupon Card
  static Widget buildCouponQRCode({
    required PosDiscount coupon,
    double size = 180,
    bool showCode = true,
    VoidCallback? onTap,
  }) {
    final qrContent = generateQRContent(coupon);
    final qrData = jsonEncode(qrContent);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR Code
            buildQRCode(
              data: qrData,
              size: size,
              showLogo: true,
            ),
            
            const SizedBox(height: 12),
            
            // รหัสคูปอง
            if (showCode && coupon.couponCode?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2AD49B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'รหัสคูปอง',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coupon.couponCode!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2AD49B),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // QR Code Validation
  // ============================================================================

  /// ตรวจสอบ QR Code ที่ scan ได้
  static Future<QRValidationResult> validateQRCode(
    String qrData, {
    String? scannedBy,
    String? orderId,
  }) async {
    try {
      // Parse QR data
      final Map<String, dynamic> qrContent;
      try {
        qrContent = jsonDecode(qrData);
      } catch (e) {
        return QRValidationResult(
          isValid: false,
          status: 'invalid_format',
          errorMessage: 'QR Code ไม่ถูกต้อง (ไม่สามารถอ่านข้อมูลได้)',
        );
      }

      // ตรวจสอบ version
      if (qrContent['v'] != _qrVersion) {
        return QRValidationResult(
          isValid: false,
          status: 'invalid_version',
          errorMessage: 'Version QR Code ไม่รองรับ',
        );
      }

      // ตรวจสอบ type
      if (qrContent['type'] != 'tlz_coupon') {
        return QRValidationResult(
          isValid: false,
          status: 'invalid_type',
          errorMessage: 'QR Code ไม่ใช่คูปอง',
        );
      }

      final couponId = qrContent['discount_id'] as String?;
      final couponCode = qrContent['code'] as String?;
      final signature = qrContent['sig'] as String?;
      final expiry = qrContent['exp'] as String?;

      if (couponId == null || couponCode == null || signature == null) {
        return QRValidationResult(
          isValid: false,
          status: 'invalid_data',
          errorMessage: 'ข้อมูล QR Code ไม่ครบถ้วน',
        );
      }

      // เรียก RPC function สำหรับ validation แบบครบวงจร
      final response = await _client.rpc(
        'validate_coupon_by_qr',
        params: {
          'p_qr_json': qrContent,
          'p_scanned_by': scannedBy,
          'p_order_id': orderId,
        },
      );

      if (response == null) {
        return QRValidationResult(
          isValid: false,
          status: 'rpc_error',
          errorMessage: 'ไม่สามารถตรวจสอบคูปองได้',
        );
      }

      final result = response as Map<String, dynamic>;

      return QRValidationResult(
        isValid: result['valid'] == true,
        couponId: result['coupon_id']?.toString(),
        couponCode: result['code']?.toString(),
        couponName: result['name']?.toString(),
        discountType: result['discount_type']?.toString(),
        value: result['value'] != null 
            ? (result['value'] is num ? (result['value'] as num).toDouble() : null)
            : null,
        status: result['status']?.toString() ?? 'unknown',
        errorMessage: result['error']?.toString(),
      );

    } catch (e) {
      debugPrint('❌ QR validation error: $e');
      return QRValidationResult(
        isValid: false,
        status: 'error',
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }

  /// ตรวจสอบ signature ของ QR Code (local validation)
  static bool verifySignature(
    String couponId,
    String couponCode,
    String? expiryDate,
    String signature,
  ) {
    final expectedSignature = _generateSignature(
      couponId,
      couponCode,
      expiryDate != null ? DateTime.tryParse(expiryDate) : null,
    );
    return signature == expectedSignature;
  }

  // ============================================================================
  // QR Scan Logging
  // ============================================================================

  /// บันทึกประวัติการ scan QR Code (ใช้กรณีที่ RPC ไม่ทำงาน)
  static Future<void> logQRScan({
    required String couponId,
    String? orderId,
    String? scannedBy,
    required String status,
    required Map<String, dynamic> qrContent,
    Map<String, dynamic>? validationResult,
    String? errorMessage,
    String? deviceInfo,
  }) async {
    try {
      await _client.from('pos_coupon_qr_scan_logs').insert({
        'coupon_id': couponId,
        'order_id': orderId,
        'scanned_by': scannedBy,
        'scan_status': status,
        'qr_content': qrContent,
        'validation_result': validationResult,
        'error_message': errorMessage,
        'scan_device_info': deviceInfo,
      });
    } catch (e) {
      debugPrint('❌ Error logging QR scan: $e');
    }
  }

  /// ดึงประวัติการ scan ของคูปอง
  static Future<List<Map<String, dynamic>>> getQRScanHistory(
    String couponId, {
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('pos_coupon_qr_scan_logs')
          .select('*')
          .eq('coupon_id', couponId)
          .order('scanned_at', ascending: false)
          .limit(limit);

      return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ Error getting QR scan history: $e');
      return [];
    }
  }

  /// ดึง analytics ของ QR scan
  static Future<Map<String, dynamic>?> getQRScanAnalytics(String couponId) async {
    try {
      final response = await _client
          .from('coupon_qr_scan_analytics')
          .select('*')
          .eq('coupon_id', couponId)
          .maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      debugPrint('❌ Error getting QR scan analytics: $e');
      return null;
    }
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// ตรวจสอบว่า QR Code มีรูปแบบถูกต้องหรือไม่
  static bool isValidQRFormat(String qrData) {
    try {
      final content = jsonDecode(qrData);
      return content['type'] == 'tlz_coupon' &&
             content['v'] == _qrVersion &&
             content['code'] != null &&
             content['discount_id'] != null;
    } catch (e) {
      return false;
    }
  }

  /// ดึงรหัสคูปองจาก QR data
  static String? extractCouponCode(String qrData) {
    try {
      final content = jsonDecode(qrData);
      return content['code'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// ดึง coupon ID จาก QR data
  static String? extractCouponId(String qrData) {
    try {
      final content = jsonDecode(qrData);
      return content['discount_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // Promotion QR Code Methods
  // ============================================================================

  /// สร้าง QR Code content จากโปรโมชัน
  static Map<String, dynamic> generatePromotionQRContent(PosPromotion promotion) {
    final promotionCode = promotion.code ?? 'PROMO_${promotion.id.substring(0, 8).toUpperCase()}';
    final signature = _generatePromotionSignature(
      promotion.id,
      promotionCode,
      promotion.endAt,
    );

    return {
      'v': _qrVersion,
      'type': 'tlz_promotion',
      'code': promotionCode,
      'promotion_id': promotion.id,
      'promotion_type': promotion.promotionType,
      'exp': promotion.endAt?.toIso8601String().split('T')[0],
      'sig': signature,
    };
  }

  /// สร้าง HMAC signature สำหรับ Promotion QR
  static String _generatePromotionSignature(String promotionId, String promotionCode, DateTime? expiryDate) {
    final payload = '$promotionId|$promotionCode|${expiryDate?.toIso8601String().split('T')[0] ?? ''}';
    final bytes = utf8.encode(payload + _promotionSecretKey);
    return base64Encode(bytes);
  }

  /// สร้าง QR Code widget สำหรับแสดงใน Promotion Card
  static Widget buildPromotionQRCode({
    required PosPromotion promotion,
    double size = 160,
    bool showCode = true,
  }) {
    final qrContent = generatePromotionQRContent(promotion);
    final qrData = jsonEncode(qrContent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR Code
          buildQRCode(
            data: qrData,
            size: size,
            showLogo: true,
          ),
          
          const SizedBox(height: 12),
          
          // รหัสโปรโมชัน
          if (showCode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'รหัสโปรโมชัน',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    qrContent['code'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9800),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ตรวจสอบ QR Code โปรโมชันที่ scan ได้
  static Future<PromotionQRValidationResult> validatePromotionQRCode(
    String qrData, {
    String? scannedBy,
    String? orderId,
  }) async {
    try {
      // Parse QR data
      final Map<String, dynamic> qrContent;
      try {
        qrContent = jsonDecode(qrData);
      } catch (e) {
        return PromotionQRValidationResult(
          isValid: false,
          status: 'invalid_format',
          errorMessage: 'QR Code ไม่ถูกต้อง (ไม่สามารถอ่านข้อมูลได้)',
        );
      }

      // ตรวจสอบ type
      if (qrContent['type'] != 'tlz_promotion') {
        return PromotionQRValidationResult(
          isValid: false,
          status: 'invalid_type',
          errorMessage: 'QR Code ไม่ใช่โปรโมชัน',
        );
      }

      // เรียก RPC function สำหรับ validation แบบครบวงจร
      final response = await _client.rpc(
        'validate_promotion_by_qr',
        params: {
          'p_qr_json': qrContent,
          'p_scanned_by': scannedBy,
          'p_order_id': orderId,
        },
      );

      if (response == null) {
        return PromotionQRValidationResult(
          isValid: false,
          status: 'rpc_error',
          errorMessage: 'ไม่สามารถตรวจสอบโปรโมชันได้',
        );
      }

      final result = response as Map<String, dynamic>;

      return PromotionQRValidationResult(
        isValid: result['valid'] == true,
        promotionId: result['promotion_id']?.toString(),
        promotionCode: result['code']?.toString(),
        promotionName: result['name']?.toString(),
        promotionType: result['promotion_type']?.toString(),
        status: result['status']?.toString() ?? 'unknown',
        errorMessage: result['error']?.toString(),
      );

    } catch (e) {
      debugPrint('❌ Promotion QR validation error: $e');
      return PromotionQRValidationResult(
        isValid: false,
        status: 'error',
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }

  /// ดึงรหัสโปรโมชันจาก QR data
  static String? extractPromotionCode(String qrData) {
    try {
      final content = jsonDecode(qrData);
      return content['code'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// ดึง promotion ID จาก QR data
  static String? extractPromotionId(String qrData) {
    try {
      final content = jsonDecode(qrData);
      return content['promotion_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// ตรวจสอบว่า QR Code เป็นโปรโมชันหรือไม่
  static bool isPromotionQR(String qrData) {
    try {
      final content = jsonDecode(qrData);
      return content['type'] == 'tlz_promotion';
    } catch (e) {
      return false;
    }
  }
}

/// ผลลัพธ์การตรวจสอบ QR Code
class QRValidationResult {
  final bool isValid;
  final String? couponId;
  final String? couponCode;
  final String? couponName;
  final String? discountType;
  final double? value;
  final String status;
  final String? errorMessage;

  QRValidationResult({
    required this.isValid,
    this.couponId,
    this.couponCode,
    this.couponName,
    this.discountType,
    this.value,
    required this.status,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'QRValidationResult(isValid: $isValid, status: $status, code: $couponCode)';
  }
}

/// ผลลัพธ์การตรวจสอบ Promotion QR Code
class PromotionQRValidationResult {
  final bool isValid;
  final String? promotionId;
  final String? promotionCode;
  final String? promotionName;
  final String? promotionType;
  final String status;
  final String? errorMessage;

  PromotionQRValidationResult({
    required this.isValid,
    this.promotionId,
    this.promotionCode,
    this.promotionName,
    this.promotionType,
    required this.status,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'PromotionQRValidationResult(isValid: $isValid, status: $status, code: $promotionCode)';
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_receipt_model.dart';

class PosReceiptService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Receipt Template Management
  // =============================================

  static Future<List<PosReceiptTemplate>> getActiveReceiptTemplates() async {
    try {
      final response = await _client
          .from('pos_receipt_templates')
          .select()
          .eq('is_active', true);

      return (response as List)
          .map((item) => PosReceiptTemplate.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getActiveReceiptTemplates: $e');
      return [];
    }
  }

  static Future<PosReceiptTemplate?> getReceiptTemplateById(String id) async {
    try {
      final response = await _client
          .from('pos_receipt_templates')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return PosReceiptTemplate.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getReceiptTemplateById: $e');
      return null;
    }
  }

  static Future<PosReceiptTemplate?> getDefaultReceiptTemplate() async {
    try {
      final response = await _client
          .from('pos_receipt_templates')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return PosReceiptTemplate.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getDefaultReceiptTemplate: $e');
      return null;
    }
  }

  static Future<PosReceiptTemplate?> addReceiptTemplate({
    required String name,
    required String templateType,
    String? headerText,
    String? footerText,
    bool showLogo = true,
    bool showOrderNumber = true,
    bool showCashier = true,
    bool showTable = false,
    bool showCustomer = false,
    bool showLoyalty = false,
  }) async {
    try {
      final payload = {
        'name': name,
        'template_type': templateType,
        'header_text': headerText,
        'footer_text': footerText,
        'show_logo': showLogo,
        'show_order_number': showOrderNumber,
        'show_cashier': showCashier,
        'show_table': showTable,
        'show_customer': showCustomer,
        'show_loyalty': showLoyalty,
        'is_active': true,
      };

      final response = await _client
          .from('pos_receipt_templates')
          .insert(payload)
          .select()
          .single();

      return PosReceiptTemplate.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error addReceiptTemplate: $e');
      return null;
    }
  }

  static Future<PosReceiptTemplate?> updateReceiptTemplate({
    required String id,
    String? name,
    String? templateType,
    String? headerText,
    String? footerText,
    bool? showLogo,
    bool? showOrderNumber,
    bool? showCashier,
    bool? showTable,
    bool? showCustomer,
    bool? showLoyalty,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (templateType != null) payload['template_type'] = templateType;
      if (headerText != null) payload['header_text'] = headerText;
      if (footerText != null) payload['footer_text'] = footerText;
      if (showLogo != null) payload['show_logo'] = showLogo;
      if (showOrderNumber != null) payload['show_order_number'] = showOrderNumber;
      if (showCashier != null) payload['show_cashier'] = showCashier;
      if (showTable != null) payload['show_table'] = showTable;
      if (showCustomer != null) payload['show_customer'] = showCustomer;
      if (showLoyalty != null) payload['show_loyalty'] = showLoyalty;
      if (isActive != null) payload['is_active'] = isActive;

      final response = await _client
          .from('pos_receipt_templates')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return PosReceiptTemplate.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error updateReceiptTemplate: $e');
      return null;
    }
  }

  // =============================================
  // Printer Profile Management
  // =============================================

  static Future<List<PosPrinterProfile>> getActivePrinterProfiles() async {
    try {
      final response = await _client
          .from('pos_printer_profiles')
          .select()
          .eq('is_active', true);

      return (response as List)
          .map((item) => PosPrinterProfile.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getActivePrinterProfiles: $e');
      return [];
    }
  }

  static Future<PosPrinterProfile?> getPrinterProfileById(String id) async {
    try {
      final response = await _client
          .from('pos_printer_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return PosPrinterProfile.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getPrinterProfileById: $e');
      return null;
    }
  }

  static Future<PosPrinterProfile?> getDefaultPrinterProfile() async {
    try {
      final response = await _client
          .from('pos_printer_profiles')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return PosPrinterProfile.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getDefaultPrinterProfile: $e');
      return null;
    }
  }

  static Future<PosPrinterProfile?> addPrinterProfile({
    required String name,
    required String printerType,
    String? deviceName,
    String? ipAddress,
    int? port,
    int paperWidth = 80,
  }) async {
    try {
      final payload = {
        'name': name,
        'printer_type': printerType,
        'device_name': deviceName,
        'ip_address': ipAddress,
        'port': port,
        'paper_width': paperWidth,
        'is_active': true,
      };

      final response = await _client
          .from('pos_printer_profiles')
          .insert(payload)
          .select()
          .single();

      return PosPrinterProfile.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error addPrinterProfile: $e');
      return null;
    }
  }

  static Future<PosPrinterProfile?> updatePrinterProfile({
    required String id,
    String? name,
    String? printerType,
    String? deviceName,
    String? ipAddress,
    int? port,
    int? paperWidth,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (printerType != null) payload['printer_type'] = printerType;
      if (deviceName != null) payload['device_name'] = deviceName;
      if (ipAddress != null) payload['ip_address'] = ipAddress;
      if (port != null) payload['port'] = port;
      if (paperWidth != null) payload['paper_width'] = paperWidth;
      if (isActive != null) payload['is_active'] = isActive;

      final response = await _client
          .from('pos_printer_profiles')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return PosPrinterProfile.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error updatePrinterProfile: $e');
      return null;
    }
  }

  // =============================================
  // Receipt History
  // =============================================

  static Future<PosReceiptHistory?> getReceiptHistory(String orderId) async {
    try {
      final response = await _client
          .from('pos_receipt_history')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return PosReceiptHistory.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getReceiptHistory: $e');
      return null;
    }
  }

  static Future<List<PosReceiptHistory>> getReceiptHistoryList(String orderId) async {
    try {
      final response = await _client
          .from('pos_receipt_history')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PosReceiptHistory.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getReceiptHistoryList: $e');
      return [];
    }
  }

  static Future<PosReceiptHistory?> createReceiptHistory({
    required String orderId,
    String? templateId,
    String? printerId,
    String? receiptContent,
  }) async {
    try {
      final payload = {
        'order_id': orderId,
        'template_id': templateId,
        'printer_id': printerId,
        'receipt_content': receiptContent,
        'print_status': 'pending',
        'print_count': 0,
      };

      final response = await _client
          .from('pos_receipt_history')
          .insert(payload)
          .select()
          .single();

      return PosReceiptHistory.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error createReceiptHistory: $e');
      return null;
    }
  }

  static Future<bool> updateReceiptPrintStatus({
    required String receiptHistoryId,
    required String printStatus,
    int? printCount,
  }) async {
    try {
      final payload = <String, dynamic>{
        'print_status': printStatus,
      };

      if (printStatus == 'printed') {
        payload['printed_at'] = DateTime.now().toIso8601String();
      }

      if (printCount != null) {
        payload['print_count'] = printCount;
      }

      await _client
          .from('pos_receipt_history')
          .update(payload)
          .eq('id', receiptHistoryId);

      return true;
    } catch (e) {
      debugPrint('Error updateReceiptPrintStatus: $e');
      return false;
    }
  }

  static Future<bool> incrementPrintCount(String receiptHistoryId) async {
    try {
      final receipt = await _client
          .from('pos_receipt_history')
          .select()
          .eq('id', receiptHistoryId)
          .single();

      final currentCount = (receipt['print_count'] ?? 0) as int;

      await _client
          .from('pos_receipt_history')
          .update({
            'print_count': currentCount + 1,
            'print_status': 'printed',
            'printed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', receiptHistoryId);

      return true;
    } catch (e) {
      debugPrint('Error incrementPrintCount: $e');
      return false;
    }
  }
}

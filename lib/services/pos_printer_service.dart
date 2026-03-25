import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pos_receipt_model.dart';
import '../config/business_settings.dart';

class PosPrinterService {
  static final _client = Supabase.instance.client;

  // Cached state
  static PosPrinterProfile? activePrinter;
  static PosReceiptTemplate? activeTemplate;
  static String? detectedIp;
  static String? detectedSubnet;
  static bool autoPrintEnabled = true;
  static List<String> discoveredPrinters = [];
  static bool isScanning = false;

  // =============================================
  // Init — called when POS page opens
  // =============================================
  static Future<void> initOnPosOpen() async {
    detectedIp = await getLocalIpAddress();
    detectedSubnet = detectedIp != null ? _subnetFromIp(detectedIp!) : null;

    // Load saved printer/template from DB
    activePrinter = await _loadDefaultPrinter();
    activeTemplate = await _loadDefaultTemplate();

    // If printer IP is on a different subnet, clear it
    if (activePrinter != null && activePrinter!.ipAddress != null && detectedSubnet != null) {
      final printerSubnet = _subnetFromIp(activePrinter!.ipAddress!);
      if (printerSubnet != detectedSubnet) {
        debugPrint('Printer IP subnet changed, resetting printer');
        activePrinter = null;
      }
    }
  }

  // =============================================
  // IP Detection
  // =============================================
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  static String? _subnetFromIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  // =============================================
  // Network Scanner — find printers on port 9100
  // =============================================
  static Future<List<String>> scanNetworkPrinters({
    String? subnet,
    int port = 9100,
    Duration timeout = const Duration(milliseconds: 500),
    void Function(int scanned, int total)? onProgress,
  }) async {
    final sub = subnet ?? detectedSubnet;
    if (sub == null) return [];

    isScanning = true;
    discoveredPrinters.clear();
    final found = <String>[];
    const total = 254;

    // Scan in batches of 20 to avoid overwhelming the network
    for (int batch = 0; batch < total; batch += 20) {
      final futures = <Future>[];
      final end = (batch + 20).clamp(0, total);

      for (int i = batch + 1; i <= end; i++) {
        final ip = '$sub.$i';
        futures.add(
          Socket.connect(ip, port, timeout: timeout).then((socket) {
            found.add(ip);
            socket.destroy();
          }).catchError((_) {}),
        );
      }

      await Future.wait(futures);
      onProgress?.call(end, total);
    }

    discoveredPrinters = List.from(found);
    isScanning = false;
    return found;
  }

  // =============================================
  // Network Printing — send raw bytes
  // =============================================
  static Future<bool> printToNetwork(String ip, int port, List<int> data) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.add(data);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Error printing to $ip:$port — $e');
      return false;
    }
  }

  static Future<bool> testPrint(String ip, int port, {int paperWidth = 80}) async {
    final bytes = generateTestReceiptBytes(paperWidth: paperWidth);
    return printToNetwork(ip, port, bytes);
  }

  // =============================================
  // ESC/POS Receipt Generator
  // =============================================
  static List<int> generateTestReceiptBytes({int paperWidth = 80}) {
    final cw = paperWidth == 58 ? 32 : 48;
    final sep = '=' * cw;
    final b = <int>[];

    b.addAll([0x1B, 0x40]); // Initialize
    b.addAll([0x1B, 0x61, 0x01]); // Center
    b.addAll([0x1B, 0x45, 0x01]); // Bold
    b.addAll(utf8.encode('TEST PRINT\n'));
    b.addAll([0x1B, 0x45, 0x00]); // Bold off
    b.addAll(utf8.encode('$sep\n'));
    b.addAll([0x1B, 0x61, 0x00]); // Left
    b.addAll(utf8.encode('Network printer OK\n'));
    b.addAll(utf8.encode('Paper: ${paperWidth}mm\n'));
    b.addAll(utf8.encode('$sep\n'));
    b.addAll(utf8.encode('${DateTime.now()}\n'));
    b.addAll([0x0A, 0x0A, 0x0A]);
    b.addAll([0x1D, 0x56, 0x00]); // Full cut
    return b;
  }

  static List<int> generateReceiptBytes({
    required String storeName,
    String? storeAddress,
    required String orderNumber,
    String? orderType,
    String? tableNumber,
    String? customerName,
    String? cashierName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double serviceAmount,
    required double netTotal,
    required String paymentMethod,
    required DateTime createdAt,
    int paperWidth = 80,
    String? headerText,
    String? footerText,
  }) {
    final cw = paperWidth == 58 ? 32 : 48;
    final sep = '=' * cw;
    final dash = '-' * cw;
    final b = <int>[];

    // Init
    b.addAll([0x1B, 0x40]);

    // ---- Header ----
    b.addAll([0x1B, 0x61, 0x01]); // Center
    b.addAll([0x1B, 0x45, 0x01]); // Bold
    b.addAll(utf8.encode('$storeName\n'));
    b.addAll([0x1B, 0x45, 0x00]);
    if (headerText != null && headerText.isNotEmpty) {
      b.addAll(utf8.encode('$headerText\n'));
    }
    b.addAll(utf8.encode('$sep\n'));

    // ---- Order info ----
    b.addAll([0x1B, 0x61, 0x00]); // Left
    b.addAll(utf8.encode('Bill: $orderNumber\n'));
    if (tableNumber != null) b.addAll(utf8.encode('Table: $tableNumber\n'));
    if (orderType != null) b.addAll(utf8.encode('Type: ${_orderTypeLabel(orderType)}\n'));
    if (customerName != null) b.addAll(utf8.encode('Customer: $customerName\n'));
    if (cashierName != null) b.addAll(utf8.encode('Cashier: $cashierName\n'));
    b.addAll(utf8.encode('Date: ${_fmtDt(createdAt)}\n'));
    b.addAll(utf8.encode('$sep\n'));

    // ---- Items ----
    for (final item in items) {
      final name = (item['product_name'] ?? item['name'] ?? '-').toString();
      final qty = (item['quantity'] ?? item['qty'] ?? 1);
      final price = (item['unit_price'] ?? item['price'] ?? 0).toDouble();
      final total = qty * price;

      b.addAll(utf8.encode('$name\n'));
      _addRow(b, '  $qty x ${price.toStringAsFixed(2)}', total.toStringAsFixed(2), cw);
    }
    b.addAll(utf8.encode('$dash\n'));

    // ---- Summary ----
    _addRow(b, 'Subtotal', subtotal.toStringAsFixed(2), cw);
    if (discountAmount > 0) {
      _addRow(b, 'Discount', '-${discountAmount.toStringAsFixed(2)}', cw);
    }
    if (taxAmount > 0) _addRow(b, 'Tax 7%', taxAmount.toStringAsFixed(2), cw);
    if (serviceAmount > 0) _addRow(b, 'Service', serviceAmount.toStringAsFixed(2), cw);
    b.addAll(utf8.encode('$sep\n'));

    b.addAll([0x1B, 0x45, 0x01]); // Bold
    _addRow(b, 'TOTAL', netTotal.toStringAsFixed(2), cw);
    b.addAll([0x1B, 0x45, 0x00]);
    b.addAll(utf8.encode('$sep\n'));

    _addRow(b, 'Payment', _paymentLabel(paymentMethod), cw);
    b.addAll(utf8.encode('$sep\n'));

    // ---- Footer ----
    b.addAll([0x1B, 0x61, 0x01]); // Center
    b.addAll(utf8.encode('${footerText ?? "Thank you!"}\n'));

    // Feed + cut
    b.addAll([0x0A, 0x0A, 0x0A, 0x0A]);
    b.addAll([0x1D, 0x56, 0x00]);
    return b;
  }

  static void _addRow(List<int> b, String left, String right, int cw) {
    final gap = cw - left.length - right.length;
    b.addAll(utf8.encode('$left${' ' * (gap > 0 ? gap : 1)}$right\n'));
  }

  // =============================================
  // PDF Receipt Generator
  // =============================================
  static Future<Uint8List> generateReceiptPdf({
    required String storeName,
    required String orderNumber,
    String? orderType,
    String? tableNumber,
    String? customerName,
    String? cashierName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double serviceAmount,
    required double netTotal,
    required String paymentMethod,
    required DateTime createdAt,
    String? headerText,
    String? footerText,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(storeName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (headerText != null) pw.Text(headerText, style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill: $orderNumber', style: const pw.TextStyle(fontSize: 10)),
                    if (tableNumber != null) pw.Text('Table: $tableNumber', style: const pw.TextStyle(fontSize: 10)),
                    if (orderType != null) pw.Text('Type: ${_orderTypeLabel(orderType)}', style: const pw.TextStyle(fontSize: 10)),
                    if (customerName != null) pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 10)),
                    if (cashierName != null) pw.Text('Cashier: $cashierName', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Date: ${_fmtDt(createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Divider(),
              // Items
              ...items.map((item) {
                final name = (item['product_name'] ?? item['name'] ?? '-').toString();
                final qty = (item['quantity'] ?? item['qty'] ?? 1);
                final price = (item['unit_price'] ?? item['price'] ?? 0).toDouble();
                final total = qty * price;
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('  $qty x ${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Text(total.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                  ],
                );
              }),
              pw.Divider(),
              _pdfRow('Subtotal', subtotal.toStringAsFixed(2)),
              if (discountAmount > 0) _pdfRow('Discount', '-${discountAmount.toStringAsFixed(2)}'),
              if (taxAmount > 0) _pdfRow('Tax 7%', taxAmount.toStringAsFixed(2)),
              if (serviceAmount > 0) _pdfRow('Service', serviceAmount.toStringAsFixed(2)),
              pw.Divider(),
              _pdfRow('TOTAL', netTotal.toStringAsFixed(2), bold: true),
              pw.Divider(),
              _pdfRow('Payment', _paymentLabel(paymentMethod)),
              pw.SizedBox(height: 8),
              pw.Text(footerText ?? 'Thank you!', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }

  // =============================================
  // Auto-print after payment
  // =============================================
  static Future<bool> autoPrintReceipt({
    required String orderId,
    required String orderNumber,
    String? orderType,
    String? tableNumber,
    String? customerName,
    String? cashierName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double serviceAmount,
    required double netTotal,
    required String paymentMethod,
    required DateTime createdAt,
  }) async {
    if (!autoPrintEnabled) return false;

    final printer = activePrinter;
    if (printer == null || printer.ipAddress == null) return false;

    final template = activeTemplate;

    final bytes = generateReceiptBytes(
      storeName: AppBusinessSettings.restaurantName,
      orderNumber: orderNumber,
      orderType: orderType,
      tableNumber: tableNumber,
      customerName: customerName,
      cashierName: cashierName,
      items: items,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      serviceAmount: serviceAmount,
      netTotal: netTotal,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      paperWidth: printer.paperWidth,
      headerText: template?.headerText,
      footerText: template?.footerText,
    );

    final success = await printToNetwork(printer.ipAddress!, printer.port ?? 9100, bytes);

    // Log
    await logPrint(
      orderId: orderId,
      printerId: printer.id,
      templateId: template?.id,
      success: success,
      receiptContent: 'ESC/POS ${bytes.length} bytes',
    );

    return success;
  }

  // =============================================
  // Reprint existing order
  // =============================================
  static Future<bool> reprintReceipt({
    required String orderId,
    required String orderNumber,
    String? orderType,
    String? tableNumber,
    String? customerName,
    String? cashierName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double serviceAmount,
    required double netTotal,
    required String paymentMethod,
    required DateTime createdAt,
  }) async {
    final printer = activePrinter;
    if (printer == null || printer.ipAddress == null) return false;

    final template = activeTemplate;

    final bytes = generateReceiptBytes(
      storeName: AppBusinessSettings.restaurantName,
      orderNumber: orderNumber,
      orderType: orderType,
      tableNumber: tableNumber,
      customerName: customerName,
      cashierName: cashierName,
      items: items,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      serviceAmount: serviceAmount,
      netTotal: netTotal,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      paperWidth: printer.paperWidth,
      headerText: template?.headerText,
      footerText: template?.footerText ?? 'REPRINT',
    );

    final success = await printToNetwork(printer.ipAddress!, printer.port ?? 9100, bytes);

    await logPrint(
      orderId: orderId,
      printerId: printer.id,
      templateId: template?.id,
      success: success,
      receiptContent: 'REPRINT ESC/POS ${bytes.length} bytes',
    );

    return success;
  }

  // =============================================
  // Print Log
  // =============================================
  static Future<void> logPrint({
    required String orderId,
    String? printerId,
    String? templateId,
    required bool success,
    String? receiptContent,
  }) async {
    try {
      await _client.from('pos_receipt_history').insert({
        'order_id': orderId,
        'printer_id': printerId,
        'template_id': templateId,
        'receipt_content': receiptContent,
        'print_status': success ? 'printed' : 'failed',
        'print_count': success ? 1 : 0,
        'printed_at': success ? DateTime.now().toIso8601String() : null,
      });
    } catch (e) {
      debugPrint('Error logging print: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentPrintLogs({int limit = 50}) async {
    try {
      final response = await _client
          .from('pos_receipt_history')
          .select('*, pos_orders!inner(order_number, net_total, created_at)')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting print logs: $e');
      // Fallback: query without join
      try {
        final response = await _client
            .from('pos_receipt_history')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(response);
      } catch (_) {
        return [];
      }
    }
  }

  // =============================================
  // DB helpers
  // =============================================
  static Future<PosPrinterProfile?> _loadDefaultPrinter() async {
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
      debugPrint('Error loading default printer: $e');
      return null;
    }
  }

  static Future<PosReceiptTemplate?> _loadDefaultTemplate() async {
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
      debugPrint('Error loading default template: $e');
      return null;
    }
  }

  static Future<PosPrinterProfile?> savePrinterProfile({
    String? existingId,
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
        'port': port ?? 9100,
        'paper_width': paperWidth,
        'is_active': true,
      };

      Map<String, dynamic> response;
      if (existingId != null) {
        response = await _client
            .from('pos_printer_profiles')
            .update(payload)
            .eq('id', existingId)
            .select()
            .single();
      } else {
        response = await _client
            .from('pos_printer_profiles')
            .insert(payload)
            .select()
            .single();
      }

      final profile = PosPrinterProfile.fromMap(Map<String, dynamic>.from(response));
      activePrinter = profile;
      return profile;
    } catch (e) {
      debugPrint('Error saving printer profile: $e');
      return null;
    }
  }

  static Future<PosReceiptTemplate?> saveReceiptTemplate({
    String? existingId,
    required String name,
    String templateType = 'thermal_80mm',
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

      Map<String, dynamic> response;
      if (existingId != null) {
        response = await _client
            .from('pos_receipt_templates')
            .update(payload)
            .eq('id', existingId)
            .select()
            .single();
      } else {
        response = await _client
            .from('pos_receipt_templates')
            .insert(payload)
            .select()
            .single();
      }

      final template = PosReceiptTemplate.fromMap(Map<String, dynamic>.from(response));
      activeTemplate = template;
      return template;
    } catch (e) {
      debugPrint('Error saving receipt template: $e');
      return null;
    }
  }

  // =============================================
  // Labels
  // =============================================
  static String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine_in': return 'Dine-in';
      case 'takeaway': return 'Takeaway';
      case 'delivery': return 'Delivery';
      default: return 'Walk-in';
    }
  }

  static String _paymentLabel(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'card': return 'Card';
      case 'transfer': return 'Transfer';
      case 'qr': return 'QR Code';
      default: return method;
    }
  }

  static String _fmtDt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

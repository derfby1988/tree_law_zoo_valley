class PosReceiptTemplate {
  final String id;
  final String name;
  final String templateType; // 'thermal_80mm', 'thermal_58mm', 'a4'
  final String? headerText;
  final String? footerText;
  final bool showLogo;
  final bool showOrderNumber;
  final bool showCashier;
  final bool showTable;
  final bool showCustomer;
  final bool showLoyalty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PosReceiptTemplate({
    required this.id,
    required this.name,
    required this.templateType,
    this.headerText,
    this.footerText,
    this.showLogo = true,
    this.showOrderNumber = true,
    this.showCashier = true,
    this.showTable = false,
    this.showCustomer = false,
    this.showLoyalty = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PosReceiptTemplate.fromMap(Map<String, dynamic> map) {
    return PosReceiptTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      templateType: map['template_type'] ?? 'thermal_80mm',
      headerText: map['header_text'],
      footerText: map['footer_text'],
      showLogo: map['show_logo'] ?? true,
      showOrderNumber: map['show_order_number'] ?? true,
      showCashier: map['show_cashier'] ?? true,
      showTable: map['show_table'] ?? false,
      showCustomer: map['show_customer'] ?? false,
      showLoyalty: map['show_loyalty'] ?? false,
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PosPrinterProfile {
  final String id;
  final String name;
  final String printerType; // 'thermal', 'inkjet', 'network'
  final String? deviceName;
  final String? ipAddress;
  final int? port;
  final int paperWidth; // มม.
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PosPrinterProfile({
    required this.id,
    required this.name,
    required this.printerType,
    this.deviceName,
    this.ipAddress,
    this.port,
    this.paperWidth = 80,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PosPrinterProfile.fromMap(Map<String, dynamic> map) {
    return PosPrinterProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      printerType: map['printer_type'] ?? 'thermal',
      deviceName: map['device_name'],
      ipAddress: map['ip_address'],
      port: map['port'],
      paperWidth: map['paper_width'] ?? 80,
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'printer_type': printerType,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'port': port,
      'paper_width': paperWidth,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PosReceiptHistory {
  final String id;
  final String orderId;
  final String? templateId;
  final String? printerId;
  final String? receiptContent;
  final String printStatus; // 'pending', 'printed', 'failed'
  final DateTime? printedAt;
  final int printCount;
  final DateTime createdAt;

  PosReceiptHistory({
    required this.id,
    required this.orderId,
    this.templateId,
    this.printerId,
    this.receiptContent,
    this.printStatus = 'pending',
    this.printedAt,
    this.printCount = 0,
    required this.createdAt,
  });

  factory PosReceiptHistory.fromMap(Map<String, dynamic> map) {
    return PosReceiptHistory(
      id: map['id'] ?? '',
      orderId: map['order_id'] ?? '',
      templateId: map['template_id'],
      printerId: map['printer_id'],
      receiptContent: map['receipt_content'],
      printStatus: map['print_status'] ?? 'pending',
      printedAt: map['printed_at'] != null ? DateTime.parse(map['printed_at']) : null,
      printCount: map['print_count'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'template_id': templateId,
      'printer_id': printerId,
      'receipt_content': receiptContent,
      'print_status': printStatus,
      'printed_at': printedAt?.toIso8601String(),
      'print_count': printCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

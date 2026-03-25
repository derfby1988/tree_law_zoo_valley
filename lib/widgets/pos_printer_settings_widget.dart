import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';
import '../services/pos_printer_service.dart';

class PosPrinterSettingsWidget extends StatefulWidget {
  const PosPrinterSettingsWidget({super.key});

  @override
  State<PosPrinterSettingsWidget> createState() => _PosPrinterSettingsWidgetState();
}

class _PosPrinterSettingsWidgetState extends State<PosPrinterSettingsWidget> with SingleTickerProviderStateMixin {
  // Design tokens
  static const _bg = AppDesignSystem.background;
  static const _card = AppDesignSystem.surface;
  static const _accent = AppDesignSystem.primary;
  static const _textPrimary = AppDesignSystem.textPrimary;
  static const _textSecondary = AppDesignSystem.textSecondary;
  static const _border = AppDesignSystem.border;

  late TabController _tabController;

  // Printer settings
  String _printerType = 'network'; // 'network' or 'bluetooth'
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _printerNameController = TextEditingController(text: 'POS Printer');
  int _paperWidth = 80;
  bool _autoPrint = true;

  // Receipt template
  final _headerController = TextEditingController();
  final _footerController = TextEditingController(text: 'Thank you!');
  bool _showTable = true;
  bool _showCustomer = true;
  bool _showCashier = true;
  bool _showLoyalty = false;

  // State
  String? _detectedIp;
  String? _detectedSubnet;
  List<String> _foundPrinters = [];
  bool _isScanning = false;
  int _scanProgress = 0;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;
  List<Map<String, dynamic>> _printLogs = [];
  bool _loadingLogs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _printerNameController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // IP detection
    final ip = await PosPrinterService.getLocalIpAddress();
    _detectedIp = ip;
    _detectedSubnet = ip != null ? ip.substring(0, ip.lastIndexOf('.')) : null;

    // Load existing printer
    final printer = PosPrinterService.activePrinter;
    if (printer != null) {
      _printerNameController.text = printer.name;
      _printerType = printer.printerType == 'bluetooth' ? 'bluetooth' : 'network';
      if (printer.ipAddress != null) _ipController.text = printer.ipAddress!;
      _portController.text = (printer.port ?? 9100).toString();
      _paperWidth = printer.paperWidth;
    }

    // Load existing template
    final template = PosPrinterService.activeTemplate;
    if (template != null) {
      _headerController.text = template.headerText ?? '';
      _footerController.text = template.footerText ?? 'Thank you!';
      _showTable = template.showTable;
      _showCustomer = template.showCustomer;
      _showCashier = template.showCashier;
      _showLoyalty = template.showLoyalty;
    }

    _autoPrint = PosPrinterService.autoPrintEnabled;
    _foundPrinters = List.from(PosPrinterService.discoveredPrinters);

    if (mounted) setState(() {});
  }

  Future<void> _scanNetwork() async {
    if (_detectedSubnet == null) return;
    setState(() {
      _isScanning = true;
      _scanProgress = 0;
      _foundPrinters.clear();
      _testResult = null;
    });

    final found = await PosPrinterService.scanNetworkPrinters(
      subnet: _detectedSubnet,
      onProgress: (scanned, total) {
        if (mounted) setState(() => _scanProgress = ((scanned / total) * 100).round());
      },
    );

    if (mounted) {
      setState(() {
        _foundPrinters = found;
        _isScanning = false;
        if (found.isNotEmpty && _ipController.text.isEmpty) {
          _ipController.text = found.first;
        }
      });
    }
  }

  Future<void> _testPrint() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    if (ip.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final success = await PosPrinterService.testPrint(ip, port, paperWidth: _paperWidth);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = success ? 'success' : 'failed';
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final existingPrinterId = PosPrinterService.activePrinter?.id;
    final existingTemplateId = PosPrinterService.activeTemplate?.id;

    await PosPrinterService.savePrinterProfile(
      existingId: existingPrinterId,
      name: _printerNameController.text.trim().isEmpty ? 'POS Printer' : _printerNameController.text.trim(),
      printerType: _printerType,
      ipAddress: _ipController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 9100,
      paperWidth: _paperWidth,
    );

    await PosPrinterService.saveReceiptTemplate(
      existingId: existingTemplateId,
      name: 'Default',
      templateType: _paperWidth == 58 ? 'thermal_58mm' : 'thermal_80mm',
      headerText: _headerController.text.trim().isEmpty ? null : _headerController.text.trim(),
      footerText: _footerController.text.trim().isEmpty ? 'Thank you!' : _footerController.text.trim(),
      showTable: _showTable,
      showCustomer: _showCustomer,
      showCashier: _showCashier,
      showLoyalty: _showLoyalty,
    );

    PosPrinterService.autoPrintEnabled = _autoPrint;

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('บันทึกค่าเครื่องพิมพ์สำเร็จ'), backgroundColor: _accent),
      );
    }
  }

  Future<void> _loadPrintLogs() async {
    setState(() => _loadingLogs = true);
    final logs = await PosPrinterService.getRecentPrintLogs(limit: 50);
    if (mounted) setState(() { _printLogs = logs; _loadingLogs = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.print, color: _accent, size: 22),
                const SizedBox(width: 8),
                const Text('ตั้งค่าเครื่องพิมพ์', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                const Spacer(),
                if (_detectedIp != null) ...[
                  Icon(Icons.wifi, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text('IP: $_detectedIp', style: TextStyle(fontSize: 11, color: _textSecondary)),
                  const SizedBox(width: 16),
                ],
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16),
                  label: const Text('บันทึก'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: _card,
            child: TabBar(
              controller: _tabController,
              labelColor: _accent,
              unselectedLabelColor: _textSecondary,
              indicatorColor: _accent,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.settings, size: 18), text: 'เชื่อมต่อ'),
                Tab(icon: Icon(Icons.receipt, size: 18), text: 'ใบเสร็จ'),
                Tab(icon: Icon(Icons.history, size: 18), text: 'ประวัติพิมพ์'),
              ],
              onTap: (index) {
                if (index == 2 && _printLogs.isEmpty) _loadPrintLogs();
              },
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnectionTab(),
                _buildReceiptTab(),
                _buildLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // Tab 1: Connection Settings
  // =============================================
  Widget _buildConnectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Printer Type
          _sectionCard(
            title: 'ประเภทเครื่องพิมพ์',
            icon: Icons.print,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _choiceChip('Network (LAN/WiFi)', Icons.wifi, _printerType == 'network', () {
                        setState(() => _printerType = 'network');
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _choiceChip('Bluetooth', Icons.bluetooth, _printerType == 'bluetooth', () {
                        setState(() => _printerType = 'bluetooth');
                      }),
                    ),
                  ],
                ),
                if (_printerType == 'bluetooth')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bluetooth ต้องจับคู่อุปกรณ์จากการตั้งค่าระบบก่อน แนะนำใช้ Network สำหรับร้านอาหาร',
                              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Network Settings
          if (_printerType == 'network') ...[
            _sectionCard(
              title: 'เชื่อมต่อ Network',
              icon: Icons.lan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scan button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          decoration: InputDecoration(
                            labelText: 'IP Address เครื่องพิมพ์',
                            hintText: 'เช่น 192.168.1.100',
                            prefixIcon: const Icon(Icons.router, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _portController,
                          decoration: InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Scan + Test buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isScanning ? null : _scanNetwork,
                        icon: _isScanning
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                            : const Icon(Icons.search, size: 16),
                        label: Text(_isScanning ? 'กำลังสแกน $_scanProgress%' : 'สแกนเครือข่าย'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isTesting || _ipController.text.isEmpty ? null : _testPrint,
                        icon: _isTesting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print, size: 16),
                        label: const Text('ทดสอบพิมพ์'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_testResult != null)
                        Chip(
                          avatar: Icon(
                            _testResult == 'success' ? Icons.check_circle : Icons.error,
                            color: _testResult == 'success' ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          label: Text(
                            _testResult == 'success' ? 'สำเร็จ' : 'ล้มเหลว',
                            style: TextStyle(fontSize: 11, color: _testResult == 'success' ? Colors.green : Colors.red),
                          ),
                          backgroundColor: _testResult == 'success' ? Colors.green.shade50 : Colors.red.shade50,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  // Found printers
                  if (_foundPrinters.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('พบเครื่องพิมพ์ ${_foundPrinters.length} เครื่อง:', style: TextStyle(fontSize: 11, color: _textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _foundPrinters.map((ip) {
                        final isSelected = _ipController.text == ip;
                        return ActionChip(
                          avatar: Icon(Icons.print, size: 14, color: isSelected ? _accent : _textSecondary),
                          label: Text(ip, style: TextStyle(fontSize: 11, color: isSelected ? _accent : _textPrimary)),
                          backgroundColor: isSelected ? _accent.withValues(alpha: 0.1) : _bg,
                          side: BorderSide(color: isSelected ? _accent : _border),
                          onPressed: () => setState(() => _ipController.text = ip),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Paper + Auto-print
          _sectionCard(
            title: 'ตั้งค่าทั่วไป',
            icon: Icons.tune,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _printerNameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อเครื่องพิมพ์',
                    prefixIcon: const Icon(Icons.label_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text('ขนาดกระดาษ', style: TextStyle(fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _choiceChip('80mm (มาตรฐาน)', Icons.straighten, _paperWidth == 80, () {
                        setState(() => _paperWidth = 80);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _choiceChip('58mm (ขนาดเล็ก)', Icons.straighten, _paperWidth == 58, () {
                        setState(() => _paperWidth = 58);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _autoPrint,
                  onChanged: (v) => setState(() => _autoPrint = v),
                  title: const Text('Auto-print หลังชำระเงิน', style: TextStyle(fontSize: 13)),
                  subtitle: Text('พิมพ์ใบเสร็จอัตโนมัติทุกครั้งที่ชำระสำเร็จ', style: TextStyle(fontSize: 11, color: _textSecondary)),
                  activeColor: _accent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // Tab 2: Receipt Template
  // =============================================
  Widget _buildReceiptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings panel
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _sectionCard(
                  title: 'ข้อความใบเสร็จ',
                  icon: Icons.text_fields,
                  child: Column(
                    children: [
                      TextField(
                        controller: _headerController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ข้อความส่วนหัว (Header)',
                          hintText: 'เช่น ที่อยู่ร้าน, เบอร์โทร',
                          prefixIcon: const Icon(Icons.vertical_align_top, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _footerController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ข้อความท้ายใบเสร็จ (Footer)',
                          hintText: 'เช่น ขอบคุณที่ใช้บริการ',
                          prefixIcon: const Icon(Icons.vertical_align_bottom, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'แสดงข้อมูลในใบเสร็จ',
                  icon: Icons.visibility,
                  child: Column(
                    children: [
                      _switchRow('แสดงเลขโต๊ะ', _showTable, (v) => setState(() => _showTable = v)),
                      _switchRow('แสดงชื่อลูกค้า', _showCustomer, (v) => setState(() => _showCustomer = v)),
                      _switchRow('แสดงชื่อแคชเชียร์', _showCashier, (v) => setState(() => _showCashier = v)),
                      _switchRow('แสดงข้อมูล Loyalty', _showLoyalty, (v) => setState(() => _showLoyalty = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Preview
          Expanded(
            flex: 4,
            child: _sectionCard(
              title: 'ตัวอย่างใบเสร็จ',
              icon: Icons.preview,
              child: _buildReceiptPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview() {
    final cw = _paperWidth == 58 ? 32 : 48;
    final sep = '=' * cw;
    final dash = '-' * cw;

    final lines = <String>[];
    lines.add(sep);
    lines.add('   Tree Law Zoo Valley');
    if (_headerController.text.isNotEmpty) lines.add('   ${_headerController.text}');
    lines.add(sep);
    lines.add('Bill: POS-2569-001234');
    if (_showTable) lines.add('Table: A01');
    lines.add('Type: Dine-in');
    if (_showCustomer) lines.add('Customer: John Doe');
    if (_showCashier) lines.add('Cashier: Admin');
    lines.add('Date: 25/03/2569 19:45');
    lines.add(sep);
    lines.add('Pad Thai              x2  300.00');
    lines.add('Mango Sticky Rice     x1  150.00');
    lines.add('Thai Iced Tea         x3   90.00');
    lines.add(dash);
    lines.add('Subtotal                   540.00');
    lines.add('Discount                   -50.00');
    lines.add('Tax 7%                      34.30');
    lines.add('Service 10%                 49.00');
    lines.add(sep);
    lines.add('TOTAL                      573.30');
    lines.add(sep);
    lines.add('Payment: Cash');
    lines.add(sep);
    lines.add('   ${_footerController.text.isEmpty ? "Thank you!" : _footerController.text}');
    lines.add('');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(
        lines.join('\n'),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: _paperWidth == 58 ? 8 : 9.5,
          color: _textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  // =============================================
  // Tab 3: Print Log
  // =============================================
  Widget _buildLogTab() {
    if (_loadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Refresh bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('ประวัติการพิมพ์ล่าสุด', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadPrintLogs,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('รีเฟรช', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _printLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: _textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('ยังไม่มีประวัติพิมพ์', style: TextStyle(color: _textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _printLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final log = _printLogs[index];
                    final status = (log['print_status'] ?? 'pending').toString();
                    final printCount = (log['print_count'] ?? 0) as int;
                    final createdAt = log['created_at'] != null ? DateTime.tryParse(log['created_at'].toString()) : null;

                    // Try to get order info from join
                    final orderData = log['pos_orders'];
                    final orderNumber = orderData is Map ? (orderData['order_number'] ?? '-') : (log['order_id'] ?? '-');
                    final netTotal = orderData is Map ? (orderData['net_total'] ?? 0).toDouble() : 0.0;

                    final isSuccess = status == 'printed';

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isSuccess ? Icons.check_circle : Icons.error_outline,
                              color: isSuccess ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderNumber.toString(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
                                ),
                                if (netTotal > 0)
                                  Text(
                                    '฿${netTotal.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 11, color: _textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isSuccess ? 'พิมพ์แล้ว ($printCount)' : 'ล้มเหลว',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSuccess ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (createdAt != null)
                                Text(
                                  '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 10, color: _textSecondary),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =============================================
  // Shared UI helpers
  // =============================================
  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _choiceChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.08) : _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _accent : _border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? _accent : _textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: selected ? _accent : _textPrimary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      activeColor: _accent,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

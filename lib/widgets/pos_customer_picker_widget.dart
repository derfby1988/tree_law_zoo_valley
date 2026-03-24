import 'package:flutter/material.dart';
import '../services/pos_customer_service.dart';
import '../theme/app_design_system.dart';

class PosCustomerPickerWidget extends StatefulWidget {
  final Function(Map<String, dynamic>?) onCustomerSelected;
  final Map<String, dynamic>? initialCustomer;

  const PosCustomerPickerWidget({
    super.key,
    required this.onCustomerSelected,
    this.initialCustomer,
  });

  @override
  State<PosCustomerPickerWidget> createState() => _PosCustomerPickerWidgetState();
}

class _PosCustomerPickerWidgetState extends State<PosCustomerPickerWidget> {
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  bool _isLoading = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await PosCustomerService.getAllCustomers();
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  Future<void> _searchCustomers(String query) async {
    if (query.isEmpty) {
      _loadCustomers();
      return;
    }

    setState(() => _isLoading = true);
    final customers = await PosCustomerService.searchCustomers(query);
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() => _selectedCustomer = customer);
    widget.onCustomerSelected(customer);
    Navigator.pop(context);
  }

  void _showCustomerPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'เลือกลูกค้า',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchCustomers,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อ หรือ เบอร์โทร',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              // Customer List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _customers.isEmpty
                        ? Center(
                            child: Text(
                              'ไม่พบลูกค้า',
                              style: TextStyle(color: AppDesignSystem.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _customers.length,
                            itemBuilder: (context, index) {
                              final customer = _customers[index];
                              return ListTile(
                                title: Text(customer['display_name'] ?? ''),
                                subtitle: customer['phone'] != null
                                    ? Text(customer['phone'])
                                    : null,
                                onTap: () => _selectCustomer(customer),
                              );
                            },
                          ),
              ),
              // Add New Customer Button
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มลูกค้าใหม่'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddCustomerDialog();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เพิ่มลูกค้าใหม่',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อลูกค้า',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'เบอร์โทร',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณากรอกชื่อลูกค้า')),
                        );
                        return;
                      }

                      final newCustomer = await PosCustomerService.addCustomer(
                        displayName: nameController.text,
                        phone: phoneController.text.isEmpty ? null : phoneController.text,
                        email: emailController.text.isEmpty ? null : emailController.text,
                      );

                      if (newCustomer != null && mounted) {
                        _selectCustomer(newCustomer);
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text('บันทึก'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showCustomerPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppDesignSystem.border),
          borderRadius: BorderRadius.circular(8),
          color: AppDesignSystem.surface,
        ),
        child: Row(
          children: [
            Text(
              'ลูกค้า:',
              style: TextStyle(fontSize: 11, color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _selectedCustomer?['display_name'] ?? 'เลือกลูกค้า',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.person, color: AppDesignSystem.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

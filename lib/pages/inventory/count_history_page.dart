import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../theme/app_design_system.dart';

class CountHistoryPage extends StatefulWidget {
  const CountHistoryPage({super.key});

  @override
  State<CountHistoryPage> createState() => _CountHistoryPageState();
}

class _CountHistoryPageState extends State<CountHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _stockHistory = [];
  List<Map<String, dynamic>> _ingredientHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      InventoryService.getStockCountHistory(limit: 200),
      InventoryService.getIngredientCountHistory(limit: 200),
    ]);
    if (!mounted) return;
    setState(() {
      _stockHistory = results[0];
      _ingredientHistory = results[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการตรวจนับ'),
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.inventory_2), text: 'ตรวจนับสต็อก (${_stockHistory.length})'),
            Tab(icon: Icon(Icons.checklist), text: 'ตรวจนับวัตถุดิบ (${_ingredientHistory.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStockList(),
                _buildIngredientList(),
              ],
            ),
    );
  }

  Widget _buildStockList() {
    if (_stockHistory.isEmpty) {
      return const Center(child: Text('ยังไม่มีประวัติตรวจนับสต็อก'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _stockHistory.length,
        itemBuilder: (context, index) {
          final rec = _stockHistory[index];
          final name = rec['inventory_products']?['name'] ?? '-';
          final before = (rec['quantity_before'] as num?)?.toDouble() ?? 0;
          final after = (rec['quantity_after'] as num?)?.toDouble() ?? 0;
          final change = (rec['quantity_change'] as num?)?.toDouble() ?? (after - before);
          final createdAt = rec['created_at']?.toString() ?? '';
          final note = rec['note']?.toString() ?? '';
          final isIncrease = change >= 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: const Icon(Icons.inventory_2, color: Colors.orange),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$before → $after'),
                  Text(_formatDate(createdAt), style: const TextStyle(fontSize: 12)),
                  if (note.isNotEmpty) Text('📝 $note', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
              trailing: Text(
                '${isIncrease ? '+' : ''}${change.toStringAsFixed(change == change.roundToDouble() ? 0 : 2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncrease ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIngredientList() {
    if (_ingredientHistory.isEmpty) {
      return const Center(child: Text('ยังไม่มีประวัติตรวจนับวัตถุดิบ'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _ingredientHistory.length,
        itemBuilder: (context, index) {
          final rec = _ingredientHistory[index];
          final name = rec['inventory_ingredients']?['name'] ?? '-';
          final before = (rec['quantity_before'] as num?)?.toDouble() ?? 0;
          final counted = (rec['quantity_counted'] as num?)?.toDouble() ?? 0;
          final diff = counted - before;
          final countedAt = rec['counted_at']?.toString() ?? '';
          final notes = rec['notes']?.toString() ?? '';
          final isIncrease = diff >= 0;
          final diffColor = diff == 0 ? Colors.grey : (isIncrease ? Colors.green : Colors.red);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.withOpacity(0.2),
                child: const Icon(Icons.checklist, color: Colors.purple),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ระบบ: $before → นับได้: $counted'),
                  Text(_formatDate(countedAt), style: const TextStyle(fontSize: 12)),
                  if (notes.isNotEmpty) Text('📝 $notes', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
              trailing: Text(
                diff == 0 ? '✓' : '${isIncrease ? '+' : ''}${diff.toStringAsFixed(diff == diff.roundToDouble() ? 0 : 2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: diffColor,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final buddhistYear = date.year + 543;
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');
      return '${date.day}/${date.month}/$buddhistYear $hh:$mm';
    } catch (_) {
      return isoString;
    }
  }
}

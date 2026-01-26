import 'package:flutter/material.dart';
import '../services/postgresql_service.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  bool _isLoading = false;
  bool _isConnected = false;
  String _statusMessage = 'Ready to test database connection';
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _bookings = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Test'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.error,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Database Status: ${_isConnected ? "Connected" : "Disconnected"}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const LinearProgressIndicator()
                    else
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _testConnection,
                            child: const Text('Test Connection'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Load Data'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Database Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Database Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('📍 Database: tree_law_zoo_valley'),
                    const Text('💾 External SSD: /Volumes/PostgreSQL/postgresql-data-valley'),
                    const Text('🔗 Connection: localhost:5432'),
                    const Text('👤 User: dave_macmini'),
                    const SizedBox(height: 8),
                    Text('📊 Tables: ${_tables.length}'),
                    Text('🍽️ Menu Items: ${_menuItems.length}'),
                    Text('📅 Bookings: ${_bookings.length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Data Preview
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Tables'),
                        Tab(text: 'Menu Items'),
                        Tab(text: 'Bookings'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTablesList(),
                          _buildMenuItemsList(),
                          _buildBookingsList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablesList() {
    if (_tables.isEmpty) {
      return const Center(child: Text('No tables loaded'));
    }
    
    return ListView.builder(
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
        return Card(
          child: ListTile(
            title: Text('Table ${table['table_number']}'),
            subtitle: Text('Status: ${table['status']} | Capacity: ${table['capacity']}'),
            trailing: Chip(
              label: Text(table['status']),
              backgroundColor: _getStatusColor(table['status']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItemsList() {
    if (_menuItems.isEmpty) {
      return const Center(child: Text('No menu items loaded'));
    }
    
    return ListView.builder(
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return Card(
          child: ListTile(
            title: Text(item['name_th']),
            subtitle: Text('฿${item['price']} | ${item['category_name']}'),
            trailing: item['is_available'] 
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.cancel, color: Colors.red),
          ),
        );
      },
    );
  }

  Widget _buildBookingsList() {
    if (_bookings.isEmpty) {
      return const Center(child: Text('No bookings loaded'));
    }
    
    return ListView.builder(
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final booking = _bookings[index];
        return Card(
          child: ListTile(
            title: Text(booking['customer_name']),
            subtitle: Text(
              '${booking['booking_date']} ${booking['booking_time']} | '
              '${booking['number_of_people']} people | '
              'Table ${booking['table_number'] ?? 'N/A'}'
            ),
            trailing: Chip(
              label: Text(booking['status']),
              backgroundColor: _getStatusColor(booking['status']),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
      case 'confirmed':
      case 'paid':
        return Colors.green;
      case 'occupied':
      case 'pending':
        return Colors.orange;
      case 'reserved':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing connection...';
    });

    try {
      final success = await PostgreSQLService.testConnection();
      setState(() {
        _isConnected = success;
        _statusMessage = success 
          ? '✅ Connection successful!' 
          : '❌ Connection failed!';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading data...';
    });

    try {
      // Load all data in parallel
      final results = await Future.wait([
        PostgreSQLService.getTables(),
        PostgreSQLService.getMenuItems(),
        PostgreSQLService.getBookings(),
      ]);

      setState(() {
        _tables = results[0];
        _menuItems = results[1];
        _bookings = results[2];
        _statusMessage = '✅ Data loaded successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error loading data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

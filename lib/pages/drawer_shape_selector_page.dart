import 'package:flutter/material.dart';
import '../widgets/drawer_clippers.dart';

class DrawerShapeSelectorPage extends StatelessWidget {
  const DrawerShapeSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกรูปทรง Drawer'),
        backgroundColor: Colors.green[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildShapeCard(context, '🌊 Wave', WaveClipper(), Colors.green),
            _buildShapeCard(context, '📐 Diagonal', DiagonalClipper(), Colors.blue),
            _buildShapeCard(context, '⭕ Diamond', DiamondClipper(), Colors.purple),
            _buildShapeCard(context, '🔺 Circle', CircleClipper(), Colors.orange),
            _buildShapeCard(context, '📏 Trapezoid', TrapezoidClipper(), Colors.red),
            _buildShapeCard(context, '🎯 Rounded', RoundedCornerClipper(), Colors.teal),
            _buildShapeCard(context, '🏔️ Triangle', TriangleClipper(), Colors.indigo),
            _buildShapeCard(context, '🌙 Crescent', CrescentClipper(), Colors.pink),
            _buildShapeCard(context, '💫 Star', StarClipper(), Colors.amber),
            _buildShapeCard(context, '🔷 Hexagon', HexagonClipper(), Colors.brown),
          ],
        ),
      ),
    );
  }

  Widget _buildShapeCard(BuildContext context, String name, CustomClipper<Path> clipper, Color color) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          _showShapePreview(context, name, clipper, color);
        },
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                ),
                child: ClipPath(
                  clipper: clipper,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShapePreview(BuildContext context, String name, CustomClipper<Path> clipper, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 300,
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: ClipPath(
                  clipper: clipper,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'นี่คือตัวอย่างรูปทรง $name สำหรับ Drawer',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ปิด'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Reportes y Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF232D37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen de Ventas Diarias', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF232D37))),
            const SizedBox(height: 20),
            
            Row(
              children: [
                _buildStatCard('Total Ingresos', '\$0.00', Icons.attach_money, Colors.green),
                const SizedBox(width: 15),
                _buildStatCard('Transacciones', '0 ventas', Icons.shopping_basket, Colors.blue),
                const SizedBox(width: 15),
                _buildStatCard('Artículos Vendidos', '0 u.', Icons.analytics, Colors.orange),
              ],
            ),
            
            const SizedBox(height: 30),
            const Text('Historial Reciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF232D37))),
            const SizedBox(height: 10),
            
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Center(
                  child: Text('Las ventas procesadas en la caja se verán reflejadas aquí.', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF232D37))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
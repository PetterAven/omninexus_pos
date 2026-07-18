import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/sales_terminal_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniNexus POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      initialRoute: '/login', 
      routes: {
        '/login': (context) => const LoginScreen(),
        '/sales': (context) => const SalesTerminalScreen(userRole: 'Administrador'),
        '/inventory': (context) => const InventoryScreen(),
        '/reports': (context) => const ReportsScreen(),
      },
    );
  }
}
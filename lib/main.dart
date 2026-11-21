import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const DeutschLesenApp());

class DeutschLesenApp extends StatelessWidget {
  const DeutschLesenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6F4F);
    return MaterialApp(
      title: 'Deutsch Lesen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

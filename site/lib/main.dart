// lib/main.dart
import 'package:flutter/material.dart';
import 'accueil_page.dart';
import 'theme_tiger.dart';

/// Contrôle global du mode clair/sombre
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const M2sTigres());
}

class M2sTigres extends StatelessWidget {
  const M2sTigres({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "TIGRES Deploy",
          theme: Tiger.light, // Thème clair
          darkTheme: Tiger.dark, // Thème sombre
          themeMode: mode, // Changement dynamique
          home: const AccueilPage(),
        );
      },
    );
  }
}

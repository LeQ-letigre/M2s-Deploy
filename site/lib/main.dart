import 'package:flutter/material.dart';
import 'accueil_page.dart';
import 'theme_tiger.dart';

void main() {
  runApp(const M2sTigres());
}

class M2sTigres extends StatelessWidget {
  const M2sTigres({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "TIGRES Deploy",
      theme: Tiger.theme,
      home: const AccueilPage(),
    );
  }
}

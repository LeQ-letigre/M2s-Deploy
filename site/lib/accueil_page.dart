import 'package:flutter/material.dart';
import 'choix_page.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  bool _showPopup = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _showWelcomePopup);
  }

  void _showWelcomePopup() {
    if (_showPopup) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Bienvenue"),
          content: const Text(
            "Ceci est un message d’accueil.\nVoulez-vous continuer à voir ce message ?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _showPopup = false);
                Navigator.of(context).pop();
              },
              child: const Text("Ne plus afficher"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _goToChoixPage(bool teransible) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChoixPage(teransible: teransible)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Voulez-vous utiliser Terransible ?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _goToChoixPage(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Oui"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _goToChoixPage(false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Non"),
            ),
          ],
        ),
      ),
    );
  }
}

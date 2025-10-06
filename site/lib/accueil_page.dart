// lib/accueil_page.dart
import 'package:flutter/material.dart';
import 'choix_page.dart';
import 'theme_tiger.dart';

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

  void _goToChoixPage(BuildContext context, bool teransible) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChoixPage(teransible: teransible)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TigerAnimatedBG(
        rightToLeft: true,
        speed: 0.25,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E0E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Titre principal ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Flexible(
                        flex: 0,
                        child: Icon(
                          Icons.auto_fix_high_rounded,
                          color: Colors.orangeAccent,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        flex: 1,
                        child: Text(
                          "Terransible Setup",
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.orangeAccent, thickness: 1),
                  const SizedBox(height: 24),

                  // --- Description ---
                  const Text(
                    "Votre mission : déployer vos machines comme un vrai tigre.\nAvez-vous déjà Terransible d’installé ?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Boutons de choix ---
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _goToChoixPage(context, true),
                          style: Tiger.tigerButton(
                            background: Colors.orangeAccent,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text("Oui, rugissons"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _goToChoixPage(context, false),
                          style: Tiger.tigerButton(
                            background: Colors.redAccent,
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text("Non, en solo"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // --- Astuce ---
                  const Text(
                    "🔥 Créé par des TIGRES, pour des TIGRES.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

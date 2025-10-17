// lib/confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme_tiger.dart';
import 'main.dart'; // pour accéder à themeNotifier global

/// 🐅 Page de confirmation après la génération et l’envoi du fichier
/// Ici on affiche l’URL, la commande cURL à exécuter, et un bouton retour.
/// Tout est copiable facilement.
class ConfirmationPage extends StatelessWidget {
  final String fileUrl; // lien du .auto.tfvars généré
  final String curl; // commande cURL prête à exécuter
  final Map<String, dynamic> querry; // les données envoyées à PB
  final bool teransible; // mode teransible actif ou non

  const ConfirmationPage({
    super.key,
    required this.fileUrl,
    required this.curl,
    required this.querry,
    required this.teransible,
  });

  /// 🔄 Permet de changer le thème global
  void _toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Je garde le fond dynamique TIGRES ici aussi
    return Container(
      decoration: Tiger.tigerBackground(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,

        // --- Barre d’app principale ---
        appBar: AppBar(
          backgroundColor: isDark
              ? Colors.black.withOpacity(0.7)
              : Colors.orange.withOpacity(0.2),
          title: const Text("TIGRES • Confirmation"),
          actions: [
            IconButton(
              tooltip: "Changer le mode d'affichage",
              onPressed: _toggleTheme,
              icon: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: isDark ? Colors.orangeAccent : Colors.deepOrange,
              ),
            ),
          ],
        ),

        // --- Corps principal ---
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141414).withOpacity(0.95)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.black.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),

              // --- Contenu de la carte ---
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "🐅 Déploiement prêt",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // URL du fichier généré
                  _copyRow(
                    context,
                    title: "URL du .auto.tfvars",
                    value: fileUrl,
                    accent: true,
                  ),
                  const SizedBox(height: 16),

                  // Commande cURL (copiable)
                  _copyRow(
                    context,
                    title: "Commande cURL",
                    value: curl,
                    smallMono: true,
                  ),

                  const SizedBox(height: 24),

                  // Bouton retour vers la page précédente
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("Retour"),
                    style: Tiger.tigerButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🧩 Ligne avec un texte + bouton copier
  /// utilisée pour afficher l’URL et la commande cURL
  Widget _copyRow(
    BuildContext context, {
    required String title,
    required String value,
    bool accent = false,
    bool smallMono = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Bloc texte à gauche
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.75)
                      : Colors.black.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 6),

              // Zone sélectionnable (copiable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: SelectableText(
                  value,
                  style: TextStyle(
                    color: accent
                        ? Colors.orangeAccent
                        : (isDark ? Colors.white : Colors.black),
                    fontFamily: "monospace",
                    fontSize: smallMono ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Bouton "copier"
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Copié dans le presse-papiers"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text("Copier"),
          style: Tiger.tigerButton(background: Colors.orangeAccent),
        ),
      ],
    );
  }
}
